#!perl

use Test::More tests => 6;

use Ctypes;
use DynaLoader;
use Carp;

# Adapted from C::DynaLib, 31/05/2010
my ($func, $sig, $ret);

my $libc = Ctypes::find_library("c");
ok( defined $libc, 'Load libc' ) or diag( DynaLoader::dl_error() );

# Testing toupper - integer argument & return type
$func = Ctypes::find_function( $libc, 'toupper' );
diag( sprintf("toupper addr: 0x%x", $func ));
ok( defined $func, 'Load toupper() function' );
$ret = Ctypes::call( $func, "cii", ord('y') );
is( chr($ret), 'Y', "Gave 'y' to toupper(), got " . chr($ret) );

my $libm = Ctypes::find_library("m");
ok( defined $libm, 'Load libm' ) or diag( DynaLoader::dl_error() );

# Testing sqrt - double argument & return type
$func = Ctypes::find_function( $libm, 'sqrt' );
diag( sprintf("sqrt addr: 0x%x", $func ));
ok( defined $func, 'Load sqrt() function' );
$ret = Ctypes::call( $func, "cdd", 16 );
is( $ret, 4, "Gave 16 to sqrt(), got $ret" );
