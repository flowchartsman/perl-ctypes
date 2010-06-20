#!perl
use Test::More tests => 4;

use Ctypes;
Ctypes->import('$libc');

ok( defined $libc, '$libc created' );
is( $libc->toupper("cii", ord("y")), ord("Y"), '$libc->toupper()' );

SKIP: {
  skip 1, "windows" unless $^O =~ /(MSWin32|cygwin)/;
  
  ok (defined WinDLL->kernel32->GetModuleHandleA, "GetModuleHandleA defined");
  ok (!defined WinDLL->kernel32->MyOwnFunction, "MyOwnFunction undefined");
}
