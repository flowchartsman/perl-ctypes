#!perl
# Function prototypes under Windows
use Ctypes qw(c_int POINTER WINFUNCTYPE WinDLL WinError);
use Ctypes::WinTypes qw(BOOL HWND RECT LPCSTR UINT);

my $prototype = WINFUNCTYPE(BOOL, HWND, POINTER(RECT));
my $paramflags = [[1, "hwnd"], [2, "lprect"]];
my $GetWindowRect = $prototype->(("GetWindowRect", WinDLL->user32), $paramflags);

sub errcheck {
    my ($result, $func, $args) = @_; 
    WinError() unless $result;
    my $rc = $args[1];
    return [ rc->left, rc->top, rc->bottom, rc->right ];
}

GetWindowRect->errcheck = \&errcheck;

$prototype = WINFUNCTYPE(c_int, HWND, LPCSTR, LPCSTR, UINT);
$paramflags = [[1, "hwnd", 0], [1, "text", "Hi"], 
	       [1, "caption", undef], [1, "flags", 0]];
my $MessageBox = $prototype->(["MessageBoxA", WinDLL->user32], $paramflags);

$MessageBox->();
$MessageBox->({text => "Spam, spam, spam"});
$MessageBox->({flags => 2, text => "foo bar"});
