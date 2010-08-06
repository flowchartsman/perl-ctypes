#!perl

use Test::More tests => 5;
use Ctypes::Function;
use Ctypes;

my $ret;

# Checking basic behaviour...
my $to_upper = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'toupper',
      argtypes => 'i',
      restype  => 'i' } );
$to_upper->abi('c');
ok( defined $to_upper, '$to_upper created with hashref' );
$ret = $to_upper->( ord("y") );
is($ret, ord("Y"));

# Checking behaviour with Type objects...
my $to_upper2 = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'toupper',
      argtypes => c_int,
      restype  => c_int } );
is( $to_upper2->argtypes->[0]->name, 'c_int',
    'Function argtype specified with Type object' );
is( $to_upper2->restype->name, 'c_int',
    'Function restype specified with Type object' );
my $letter_y = c_int('y');
$ret = $to_upper2->( $letter_y );
is( $ret, ord("Y"), 'Function returns native type instead of Type object');

