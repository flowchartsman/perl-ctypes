#!perl

use Test::More tests => 3;

use Ctypes;
use DynaLoader;

# Adapted from http://github.com/rurban/c-dynalib/blob/master/lib/C/DynaLib.pm, 31/05/2010
my ($lib, $func, $sig, $ret);

$sig = "cdd";
if ($^O eq 'cygwin') {
  $lib = DynaLoader::dl_load_file( "/bin/cygwin1.dll" );
  ok( defined $lib, 'Load cygwin1.dll' );
} elsif ($^O eq 'MSWin32') {
  $lib = DynaLoader::dl_load_file($ENV{SYSTEMROOT}."\\System32\\MSVCRT.DLL" );
  ok( defined $lib,   'Load msvcrt.dll' );
  $sig = "sdd";
} else {
  my $found = DynaLoader::dl_findfile( '-lm' ) or diag("-lm not found");
  $lib = DynaLoader::dl_load_file( $found );
  ok( defined $lib, 'Load libm' ) or diag( DynaLoader::dl_error() );
}

$func = DynaLoader::dl_find_symbol( $lib, 'sqrt' );
diag( sprintf("sqrt addr: 0x%x", $func ));
ok( defined $func, 'Load sqrt() function' );

$ret = Ctypes::call( $func, $sig, 16 )
    or croak( "Call to Ctypes::call failed: $@" );
is( $ret, 4, "Gave 16 to sqrt(), got $ret" );
