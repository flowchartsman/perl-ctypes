#!perl

use Test::More tests => 1;
use Ctypes;
use Data::Dumper;
my $Debug = 0;

#
#  Self-referential example~~
#
#  typedef union {
#    signed int    sint;
#    unsigned int  uint;
#    float         flt;
#    char          data[FFI_SIZEOF_JAVA_RAW];
#    void*         ptr;
#  } ffi_java_raw;
#

my $ffi_java_raw = Union({ fields => [
  [ sint => c_int ],
  [ uint => c_uint ],
  [ flt  => c_float ],
  [ data => Array( c_char, [0..7] ) ],
  [ ptr  => Pointer( c_void_p ) ], ] });

isa_ok( $ffi_java_raw, 'Ctypes::Type::Union', 'Union created ok' );

is( $ffi_java_raw->size, 8, 'Size is that of largest member' );
is( $ffi_java_raw->name, 'iIfpp_Union', 'Name modified correctly' );

ok( $ffi_java_raw->field_list->[0][0] eq 'sint'
  && $ffi_java_raw->field_list->[1][1]->typecode eq 'I',
  '$st->field_list returns names and type names' );

is( $$ffi_java_raw->data->[6], 0, 'All members initialized to 0' );

$ffi_java_raw->sint->(25);
is( $$ffi_java_raw->sint, 25, 'Values in & out to simple members' );

# this test needs to be in Array.t and maybe Struct.t
$$ffi_java_raw->data->[0] = 80;

is( $$ffi_java_raw->data->[0], 80, 'Vals in & out to compound members' );

# test for setting undef needs moved to types.t
# $ffi_java_raw->sint->(undef);

is( $$ffi_java_raw->sint, 0, 'Setting one member erases others' );


