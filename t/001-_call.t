#!perl
# The pure _call XS interface
# XXX Increase test coverage with cover -test, currently 43.5%
use Test::More tests => 15;

use Ctypes;

my ($func, $sig, $ret);
my $libc = Ctypes::load_library("c");
ok( defined $libc, 'Load libc' ) or diag( Ctypes::load_error() );

# Testing toupper - integer argument & return type
$func = Ctypes::find_function( $libc, 'toupper' );
#diag( sprintf("toupper addr: 0x%x", $func ));
ok( defined $func, 'Load toupper() function' );
$ret = Ctypes::call( $func, "cii", ord('y') );
is( chr($ret), 'Y', "toupper('y') => " . chr($ret) );

my $libm = Ctypes::load_library("m");
ok( defined $libm, 'Load libm' ) or diag( Ctypes::load_error() );

# Testing sqrt - double argument & return type
$func = Ctypes::find_function( $libm, 'sqrt' );
#diag( sprintf("sqrt addr: 0x%x", $func ));
ok( defined $func, 'Load sqrt() function' );
$ret = Ctypes::call( $func, "cdd", 16.0 );
is( $ret, 4.0, "sqrt(16.0) => $ret" );

# Correctly find errors in given arguments
eval { $ret = Ctypes::_call( $func ); };
like( $@, qr/Usage/, "not enough args: $@" );
eval { $ret = Ctypes::_call( $func, 16.0 ); };
like( $@, qr/is not a string/, "no sig: $@" );
eval { $ret = Ctypes::_call( $func, "xdd", 16.0 ); };
like( $@, qr/Invalid function/, "wrong sig x: $@" );
eval { $ret = Ctypes::_call( $func, "c", 16.0 ); };
like( $@, qr/Invalid function/, "too short sig: $@" );
eval { $ret = Ctypes::_call( $func, "cyd", 16.0 ); };
like( $@, qr/Invalid return/, "wrong sig cyd: $@" );
eval { $ret = Ctypes::_call( $func, "cdy", 16.0 ); };
like( $@, qr/Invalid argument/, "wrong sig cdy: $@" );
eval { $ret = Ctypes::_call( $func, "cd", 16.0 ); };
like( $@, qr/error/, "wrong sig cd: $@" );
eval { $ret = Ctypes::_call( $func, "cdd" ); };
like( $@, qr/error/, "missing arg: $@" );
eval { $ret = Ctypes::_call( $func, "cdd", 1, 2 ); };
like( $@, qr/error/, "too many args: $@" );
