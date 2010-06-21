#!perl
use Test::More tests => 3;

use Ctypes;
my $lib;

if ($^O =~ /(MSWin32|cygwin)/) {
   $lib = CDLL->msvcrt;
   ok( defined $lib, 'declare msvcrt' ) 
     or diag( DynaLoader::dl_error() );
} else {
   $lib = CDLL->c;
   ok( defined $lib, 'declare libc' ) 
     or diag( DynaLoader::dl_error() );
}

my $func = $lib->toupper;
ok( defined $func, 'define toupper()' );
my $ret = $lib->toupper(ord("y"));
is( chr($ret), 'Y', "toupper('y') => " . chr($ret) );
