#!perl

use Test::More tests => 1;
BEGIN { use_ok( Ctypes ) }

my $b = c_byte;
isa_ok( $b, 'Ctypes::Type::Simple' );
is( $b->typecode, 'b', 'Correct typecode' );
