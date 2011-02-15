#!perl

use Test::More tests => 6;
use Ctypes::Function;
use Ctypes;

# Checking basic behaviour...
my $to_upper = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'toupper',
      argtypes => 'i',
      restype  => 'i' } );
$to_upper->abi('c');
my $y = ord('y');
ok( defined $to_upper, '$to_upper created with hashref' );
my $ret = $to_upper->( $y );
is($ret, ord("Y"), '$to_upper->(ord "y") == ord "Y"');

# Checking behaviour with Type objects...
my $to_upper2 = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'toupper',
      argtypes => c_int,
      restype  => c_int } );
SKIP: {
  skip "fails debugging", 2 if $DB::VERSION;
  is( $to_upper2->argtypes->[0]->name, 'c_int',
      'Function argtype specified with Type object' );
  is( $to_upper2->restype->name, 'c_int',
      'Function restype specified with Type object' );
}
my $letter_y = c_int($y);
diag '$to_upper2->( c_int($y) )';
$ret = $to_upper2->( $letter_y );
is( $ret, ord("Y"), 'Function returns native type instead of Type object');

diag '$to_upper2->( c_int("y") )';
$ret = $to_upper2->( c_int("y") );
is( $ret, ord("Y"), 'implicit c_char => c_int conversion');
