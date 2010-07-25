#!perl

use Test::More tests => 8;
use Ctypes::Function;
use Ctypes::Type qw(c_int);
use Data::Dumper;
use Devel::Peek;

my $number_seven = c_int(7);
ok( defined $number_seven, 'c_int returned object');
# don't know if c_int will default to different type on 
# this system so do inspecific check:
like( ref($number_seven), qr/Ctypes::Type/, 'c_int created Type object' );

is( $number_seven, 7, "Obj numeric representation: $number_seven" );
is( $number_seven->{val}, 7, "\$obj->{val}: " . $number_seven->{val} );

$number_twelve = $number_seven;

is_deeply( $number_twelve, $number_seven, "Assignment copies object by value" );

$number_seven->(12);

subtest 'Set new value' => sub {
  plan tests => 2;
  is( $number_seven, 12, "Numeric: $number_seven" );
  is( $number_seven->{val}, 12, "\$obj->{val}: " . $number_seven->{val} );
};

$number_seven += 3;
is( $number_seven, 15, "Binary increment" );
$number_seven--;
is( $number_seven, 14, "Unary decrement" );

my $no_value = c_int;
ok( defined $no_value, 'Created object without initializer' );
is( $no_value, 0, 'Default initialization to 0' );

my $letter_y = c_int('y');
is( $letter_y, 121, 'Initialised c_int with letter' );

# XXX: Exceeding range on signed variables undefined?
my $overflower = c_int(2147483648);
isnt( $overflower, 2147483648, 'Cannot exceed INT_MAX' );
$overflower->(-2147483649);
isnt( $overflower,-2147483649, 'Cannot go below INT_MIN' );

my $to_upper = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'toupper',
      argtypes => c_int,
      restype  => c_int } );
ok( defined $to_upper, '$to_upper created with hashref' );
is( $to_upper->argtypes->[0], 'i',
    'Function argtype specified with Type object' );
is( $to_upper->restype, 'i',
    'Function restype specified with Type object' );

my $ret = $to_upper->( $letter_y );
is( $ret, ord("Y"), 'Function returns type obj');
my $ret_as_char = c_char($ret);
is( $ret_as_char->value, 'Y', 'c_char converts from number types' );
