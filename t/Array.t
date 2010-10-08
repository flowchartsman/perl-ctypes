#!perl

use Test::More tests => 12;
use Ctypes;
use Ctypes::Function;
use Ctypes::Callback;

note( "Initialization" );

my $array = Array( 1, 2, 3, 4, 5 );
is( ref($array), 'Ctypes::Type::Array', 'Array created from list');

my $array2 = Array( [6, 7, 8, 9, 10] );
is( ref($array2), 'Ctypes::Type::Array', 'Array created from arrayref');

my $double_array = Array( c_double, [11, 12, 13, 14, 15] );
is( $double_array->name, 'double_Array', 'Array type specified');

is($#$double_array, 4, '$# for highest index');

is(${$double_array->data}, pack('d*',11,12,13,14,15), 'packed data looks right');

is($double_array->[2], 13, '$obj->[x] dereferencing');
is($$double_array[2], 13, '$$obj[x] dereferencing');

is( scalar @$double_array, 5, 'scalar @$array = $#$array+1' );

note( "Assignment" );
$$array[2] = 1170;
is( $$array[2], 1170, '$$array[x] = y assignent' );
$array->[2] = 500;
is( $$array[2], 500, '$array->[x] = y assignment' );

note( "As function arguments" );

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
my $disarray = Array( 2, 4, 5, 1, 3 );
$qsort->($disarray, $#$disarray+1, Ctypes::sizeof('s'), $cb->ptr);
$disarray->_update_;  # Ctypes has the hooks for doing this
                      # automatically, through paramflags
my $arrstring = join(", ", @$disarray);
is($arrstring, "1, 2, 3, 4, 5" , '_as_param_ and _update_ working' );

# Multidimensional

my $multi = Array( $array, $array2, $double_array );

subtest 'Multidimensional' => sub {
  plan tests => 3;
  is( $$multi[0][0], 1 );
  is( $$multi[1][2], 8 );
  is( $$multi[2][4], 15 );
};
