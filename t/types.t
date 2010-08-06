#!perl

use Test::More tests => 21;
use Ctypes;
use Ctypes::Function;
use utf8;

my $number_seven = c_int(7);
ok( defined $number_seven, 'c_int returned object');
# XXX Py ctypes has this behaviour: valuable?
# don't know if c_int will default to different type on 
# this system so do inspecific check:
like( ref($number_seven), qr/Ctypes::Type/, 'c_int created Type object' );

is( $number_seven, 7, "Obj numeric representation: $number_seven" );
is( $number_seven->val, 7, "\$obj->val: " . $number_seven->val );

my $number_twelve = $number_seven;

is_deeply( $number_twelve, $number_seven, "Assignment copies object" );

$number_seven->(12);
is( $number_seven->val, 12, "Assign value with ->(x)" );

$number_seven->val = 15;
is( $number_seven, 15, "Assign value with ->val = x" );

$number_seven += 3;
is( $number_seven->val, 18, '$obj += <num>' );
$number_seven--;
is( $number_seven->val, 17, '$obj -= <num>' );

is( $number_seven->typecode, 'i', "->typecode getter" );
is( $number_seven->typecode('p'), 'p', "->typecode(x) setter" );

# The ->val is there to do necessary type checking and all the
# pack()ing malarky for you, storing the result in _data.
# You should NEVER access a Type's _data directly. But you can.
is( $number_seven->_data, pack('i', 17), "->_data getter" );
is( $number_seven->_data(pack('i', 19)), pack('i', 19), "->_data setter" );

$number_seven = 20;
is(ref($number_seven), '', '$obj = <num> squashes object');

my $no_value = c_int;
ok( ref($no_value) =~ /Ctypes::Type/, 'Created object without initializer' );
is( $no_value, 0, 'Default initialization to 0' );

my $number_y = c_int('y');
is( $number_y, 121, 'c_int casts from non-numeric ASCII character' );

my $number_ryu = c_int('龍');
is( $number_ryu->val, 40845, 'c_int converts from UTF-8 character' );
# TODO: implement this for other numeric types!

# Exceeding range on _signed_ variables is undefined in the standard,
# so these tests can't really be any better.
my $overflower = c_int(2147483648);
isnt( $overflower, 2147483648, 'Cannot exceed INT_MAX' );
$overflower->(-2147483649);
isnt( $overflower,-2147483649, 'Cannot go below INT_MIN' );

my $ret_as_char = c_char(89);
is( $ret_as_char->val, 'Y', 'c_char converts from numbers' );
# TODO: define behaviour for numbers > 255!
