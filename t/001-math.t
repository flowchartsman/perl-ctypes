#!perl -T

use Test::More tests => 3;

use Ctypes;
use DynaLoader;

# Adapted from http://github.com/rurban/c-dynalib/blob/master/lib/C/DynaLib.pm, 31/05/2010
my ($lib, $func, $sig, $ret);

if ($^O eq 'cygwin') {
  $lib = DynaLoader::dl_load_file( "/bin/cygwin1.dll" );
    ok( defined $lib, 'Load cygwin1.dll' );
  $func = DynaLoader::dl_find_symbol( $lib, 'sqrt' );
    ok( defined $func, 'Load sqrt() function' );
}

if ($^O eq 'MSWin32') {
  $lib = DynaLoader::dl_load_file($ENV{SYSTEMROOT}."\\System32\\MSVCRT.DLL" );
    ok( defined $lib,   'Load msvcrt.dll' );
  $func = DynaLoader::dl_find_symbol( $lib, 'sqrt' );
    ok( defined $func,   'Load sqrt() function' );
}

if ($^O =~ /linux/) {
  my $found = DynaLoader::dl_findfile( '-lm' );
  $lib = DynaLoader::dl_load_file( $found );
    ok( defined $lib, 'Load libm' ) or diag( DynaLoader::dl_error() );
  $func = DynaLoader::dl_find_symbol( $lib, 'sqrt' );
    ok( defined $func, 'Load sqrt() function' ) or diag( DynaLoader::dl_error() );
}

$sig = "sdd";

$ret = Ctypes::call( $func, $sig, 16 ) or croak( "Call to Ctypes::call failed: $@" );
  is( $ret, 4, "Gave 16 to sqrt(), got $ret" );
