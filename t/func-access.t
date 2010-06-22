#!perl
use Test::More tests => 4;

use Ctypes;
my $libc = CDLL->c;

ok( defined $libc, 'CDLL->c created' );
is( $libc->toupper({sig=>"ii"})->(ord("y")), ord("Y"), 'libc->toupper()' );

SKIP: {
  skip 2, "windows" unless $^O =~ /(MSWin32|cygwin)/;
  
  ok (defined WinDLL->kernel32->GetModuleHandleA, "GetModuleHandleA defined");
  ok (!defined WinDLL->kernel32->MyOwnFunction, "MyOwnFunction undefined");
}
