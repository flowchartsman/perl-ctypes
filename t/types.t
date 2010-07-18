#!perl

use Test::More tests => 8;
use Ctypes::Function;
use Ctypes::Type qw(c_int);
use Data::Dumper;
use Devel::Peek;

my $number_seven = c_int(7);
ok( defined $number_seven, 'c_int returned object');

diag( "[" . __FILE__ . ":" . __LINE__ . "] " . ref($number_seven) );

# don't know if c_int will default to different type on 
# this system so do inspecific check:
like( ref($number_seven), qr/Ctypes::Type/, 'c_int created type object' );

diag( Dump($number_seven->{val}) );
my $num = $number_seven->{val};
diag( Dump($number_seven->{val}) );
is( $num, 7, "Initialised c_int with number: $num" );
diag( Dump($number_seven->{val}) );

diag( "Value: ", $number_seven->{val} );

my $letter_y = c_int('y');
is( $letter_y->{value}, 121, 'Initialised c_int with letter' );

my $to_upper = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'toupper',
      argtypes => 'i',
      restype  => c_int } );  # can only do this if c_int is a sub?
ok( defined $to_upper, '$to_upper created with hashref' );
is( $to_upper->restype, 'c_int',
    'Function obj accepts & returns type objs arguments' );
my $ret = $to_upper->( $letter_y );
like( ref($ret), qr/Ctypes::Type/, 'Function returns type obj');
my $ret_as_char = c_char($ret);
is( $ret_as_char->value, 'Y', 'c_char converts from number types' );
