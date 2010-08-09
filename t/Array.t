#!perl

use Test::More tests => 8;
use Ctypes;
use Ctypes::Function;
use Ctypes::Callback;
use Data::Dumper;
use Devel::Peek;

my $array = Array( 1, 2, 3, 4, 5 );
is( ref($array), 'Ctypes::Type::Array', 'Array created from list');

my $array2 = Array( [6, 7, 8, 9, 10] );
is( ref($array2), 'Ctypes::Type::Array', 'Array created from arrayref');

my $double_array = Array( c_double, [11, 12, 13, 14, 15] );
is( $double_array->type->name, 'c_double', 'Array type specified');

is($#$double_array, 4, '$# for highest index');

is(${$double_array->_data}, pack('d*',11,12,13,14,15), 'packed data looks right');

is($double_array->[2], 13, '$obj[x] dereferencing');
is( scalar @$double_array, 5, 'scalar @$array = $#$array+1' );

# As function arguments

sub cb_func {
  my( $ay, $bee ) = @_;
  if( ($ay+0) < ($bee+0) ) { return -1; }
  if( ($ay+0) == ($bee+0) ) { return 0; }
  if( ($ay+0) > ($bee+0) ) { return 1; }
}
my $qsort = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'qsort',
      argtypes => 'piip',
      restype  => 'v' } );
my $cb = Ctypes::Callback->new( \&cb_func, 'i', 'ss' );
$array = Array( 2, 4, 5, 1, 3 );
$qsort->($array, $#$array+1, Ctypes::sizeof('s'), $cb->ptr);
my $arrstring = join(", ", @$array);
is($arrstring, "1, 2, 3, 4, 5" , '_as_param_ working' );

diag( "really, it's working" );
my $ref = \$$array[2];
$$array[2] = c_int(117);
diag( $$ref );

# Multidimensional

my $multiarray = Array( $array, $array, $array );
