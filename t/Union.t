#!perl

use Test::More tests => 5;
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

my $ffi_java_raw = Union([
    sint => c_int,
    uint => c_uint,
    flt  => c_float,
    data => Array( c_char, [0..4] ),
    ptr  => Pointer( c_int ) 
]);

subtest 'Simple construction (arrayref)' => sub {
  plan tests => 4;
  isa_ok( $ffi_java_raw, 'Ctypes::Type::Union', 'Union created ok' );
  is( $ffi_java_raw->name, 'Union' );
  is( $ffi_java_raw->{data}->[4], 0 );
  is( $ffi_java_raw->size, 5 );
};

subtest 'Access field info' => sub {
  plan tests => 5;
  is( $ffi_java_raw->fields->[0], '<Field type=c_int, ofs=0, size=4>' );
  is( $ffi_java_raw->fields->[1], '<Field type=c_uint, ofs=0, size=4>' );
  is( $ffi_java_raw->fields->[2], '<Field type=c_float, ofs=0, size=4>' );
  is( $ffi_java_raw->fields->[3], '<Field type=char_Array, ofs=0, size=5>' );
  is( $ffi_java_raw->fields->[4], '<Field type=i_Pointer, ofs=0, size=4>' );
};

subtest 'All members initialised to 0' => sub {
  plan tests => 9;
  is( $$ffi_java_raw->{sint}, 0 );
  is( $$ffi_java_raw->{uint}, 0 );
  is( $$ffi_java_raw->{flt}, 0 );
  is( $$ffi_java_raw->{data}->[0], 0 );
  is( $$ffi_java_raw->{data}->[1], 0 );
  is( $$ffi_java_raw->{data}->[2], 0 );
  is( $$ffi_java_raw->{data}->[3], 0 );
  is( $$ffi_java_raw->{data}->[4], 0 );
  is( $$ffi_java_raw->{ptr}->deref, 0 );
};

subtest 'Attribute access' => sub {
  plan tests => 4;
  is( $ffi_java_raw->size, 5, );
  is( $ffi_java_raw->name, 'Union' );
  is( $ffi_java_raw->typecode, 'p' );
  is( $ffi_java_raw->align, 0 );
};

subtest 'Data access' => sub {
  plan tests => 4;
  $$ffi_java_raw->{sint} = 25;
  is( $$ffi_java_raw->{sint}, 25, 'Values in & out to simple members' );
  $$ffi_java_raw->{data}->[3] = 80;
  is( $$ffi_java_raw->{data}->[3], 80, 'Vals in & out to compound members' );
  $$ffi_java_raw->{data}->[3] = undef;
  $$ffi_java_raw->{data}->[2] = 1;
  is( $$ffi_java_raw->{uint}, 65536, 'Setting one member messes with others' );
  $$ffi_java_raw->{flt} = 1234.56789;
  is( $$ffi_java_raw->{flt}, 1234.56789 );
};
