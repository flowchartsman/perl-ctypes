#!perl
use Test::More tests => 5;

use Ctypes;
my $libc = CDLL->c;

ok( defined $libc, 'CDLL->c created' );
is( $libc->toupper({sig=>"cii"})->(ord("y")), ord("Y"), 'libc->toupper()' );
ok( defined CDLL->c->toupper, "toupper defined from CDLL->" );

SKIP: {
  skip "Windows tests", 2 unless $^O =~ /(MSWin32|cygwin)/;
  
  ok (defined WinDLL->kernel32->GetModuleHandleA, "GetModuleHandleA defined");
  eval { WinDLL->kernel32->MyOwnFunction };
  ok ( $@ =~ "No function MyOwnFunction", "MyOwnFunction not found in kernel32");
}
