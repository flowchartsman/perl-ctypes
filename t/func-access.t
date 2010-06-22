#!perl
use Test::More tests => 4;

use Ctypes;
my $libc = CDLL->c;

ok( defined $libc, '$libc created' );
is( $libc->toupper({sig=>"cii"})->(ord("y")), ord("Y"), 'libc->toupper()' );

SKIP: {
  skip "windows", 2 unless $^O =~ /(MSWin32|cygwin)/;
  
  ok (defined WinDLL->kernel32->GetModuleHandleA, "GetModuleHandleA defined");
  ok (!defined WinDLL->kernel32->MyOwnFunction, "MyOwnFunction undefined");
}
