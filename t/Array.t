#!perl

use Test::More tests => 6;
use Ctypes;
use Ctypes::Function;
use Ctypes::Callback;
use Data::Dumper;
use Devel::Peek;

my $array = Array( 1, 2, 3, 4, 5 );
is( ref($array), 'Ctypes::Type::Array', 'Array created from list');

my $array2 = Array( [6, 7, 8, 9, 10] );
is( ref($array), 'Ctypes::Type::Array', 'Array created from arrayref');

my $double_array = Array( c_double, [11, 12, 13, 14, 15] );
is( $double_array->type, 'c_double', 'Array type specified');

is($#$double_array, 4, '$# for highest index');

is($double_array->_data, pack('d*',11,12,13,14,15), 'packed data looks right');

is($double_array->[2], 13, '$obj[x] dereferencing');

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

my $cb = Ctypes::Callback->new( \&cb_func, 'i', 'ii' );

$array = Array(2, 4, 5, 1, 3);
#diag( "Before call:" );
#diag( Dump($array) );

$qsort->(\$array, $#$array+1, Ctypes::sizeof('i'), $cb->ptr);
#diag( "After call:" );
#diag( Dump($array) );

# my @res = unpack( 'i*', $arg  );
my $arrstring = $array[0];

is($arrstring, "1, 2, 3, 4, 5" , "Array reordered: $arrstring" );
