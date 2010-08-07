#!perl

use Test::More tests => 6;
use Ctypes;
use Ctypes::Function;
use Ctypes::Callback;
use Data::Dumper;

my $array = Array( 1, 2, 3, 4, 5 );
is( ref($array), 'Ctypes::Type::Array', 'Array created from list');

my $array2 = Array( [6, 7, 8, 9, 10] );
is( ref($array), 'Ctypes::Type::Array', 'Array created from arrayref');

my $double_array = Array( c_double, [11, 12, 13, 14, 15] );
is( $double_array->type, 'c_double', 'Array type specified');

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
$qsort->abi('c');
ok( defined $qsort, 'created function $qsort' );

my $cb = Ctypes::Callback->new( \&cb_func, 'i', 'ii' );
ok( defined $cb, 'created callback $cb' );

my @array = (2, 4, 5, 1, 3);
note( "Initial array: ", join(", ", @array) );

my $arg = pack('i*', @array);

$qsort->(\$arg, $#array+1, Ctypes::sizeof('i'), $cb->ptr);

my @res = unpack( 'i*', $arg  );
my $arrstring = join(", ", @res);

is($arrstring, "1, 2, 3, 4, 5" , "Array reordered: $arrstring" );
