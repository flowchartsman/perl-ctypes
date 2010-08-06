#!perl
# Function prototypes under Windows
use Test::More;
if ( $^O !~ /(MSWin32|cygwin)/ ) {
  plan skip_all => 'Windows tests';
} else {

  TODO: {
    local $TODO = "Windows-specific Type objects not yet done!";
    
    require Ctypes; import Ctypes qw(c_int POINTER WINFUNCTYPE WinDLL WinError);
    require Ctypes::WinTypes; import Ctypes::WinTypes qw(BOOL HWND RECT LPCSTR UINT);

    my $prototype = WINFUNCTYPE(BOOL, HWND, POINTER(RECT));
    my $paramflags = [[1, "hwnd"], [2, "lprect"]];
    my $GetWindowRect = $prototype->(("GetWindowRect", WinDLL->user32), $paramflags);

    sub errcheck {
        my ($result, $func, $args) = @_; 
        WinError() unless $result;
        my $rc = $args[1];
        return [ $rc->left, $rc->top, $rc->bottom, $rc->right ];
    }

    GetWindowRect->errcheck = \&errcheck;

    $prototype = WINFUNCTYPE(c_int, HWND, LPCSTR, LPCSTR, UINT);
    $paramflags = [[1, "hwnd", 0], [1, "text", "Hi"], 
           [1, "caption", undef], [1, "flags", 0]];
    my $MessageBox = $prototype->(["MessageBoxA", WinDLL->user32], $paramflags);

    $MessageBox->();
    $MessageBox->({text => "Spam, spam, spam"});
    $MessageBox->({flags => 2, text => "foo bar"});
  }
}
