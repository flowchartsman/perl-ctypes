#!perl

use Test::More tests => 18;
use Ctypes;
use Ctypes::Callback;
use Data::Dumper;

#
# C rationale
#
# int i = 5;
# int j = 10;
# int ptr = &i;
# debug_warn( "%i", *ptr );   // 5
# // ptr = j;  WRONG
# ptr = &j;    // *ptr = 10;
#

my $ushort = c_ushort(25); # because it makes the Wrong sized deref simpler
is( $ushort->name, 'c_ushort', 'created c_ushort' );

my $ushortp = Pointer( $ushort );
isa_ok( $ushortp, 'Ctypes::Type::Pointer', 'Pointer object' );

like( $$ushortp, qr/SCALAR/, '$$ptr returns original object' );
like( $ushortp->contents, qr/SCALAR/, '$ptr->contents returns' );

is( ${$$ushortp}, 25, 'Get object value with ${$$ptr}');
is( $ushortp->deref, 25, 'Get object value with $ptr->deref' );

#   The only thing one has to remember is different in Perl is that
# ${$$ptr} and $ptr->deref are NOT 'dereferencing the pointer' in
# the C sense: they're dereferencing in the Perl sense the value
# stored in the object the pointer points to.
#   For proper C dereferencing, use e.g. $$ptr[0].
#   For simple types this will generally be a proper value; 
# for Arrays it'll probably be meaningless.

is( ${$ushortp->_as_param_}, pack('S',25), '_as_param_ returns object\'s data' );
is( $ushortp->type, 'S', 'Get type of object with $ptr->type');

is( $$ushortp[0], 25, 'Get value with $$ptr[0]' );
$$ushortp[0] = 30;
is( $$ushort, 30, 'Modify val of original object via $$ptr[x] = y' );

$$ushortp = c_int(65536);  # should warn of incompat types
subtest 'Wrongly sized deref' => sub {
  plan tests => 2;
  is( $$ushortp[0], 0 );   # First {$ushort->size} bytes of int 65536
  $ushortp++;
  is( $$ushortp[0], 1 );   # Second set of bytes
};

is( $ushortp->offset, 1, 'offset getter' );
is( $ushortp->offset(5), 5, 'offset setter, but...' );
is( $$ushortp[0], undef, '...you can\'t read random memory' );

note( "A more complex example" );

my $array = Array( c_ushort, [ 1, 2, 3, 4, 5 ] );
$$ushortp = $array;
like( $ushortp->contents, qr/HASH/, '->contents still works' );
is( ${$ushortp->_as_param_}, pack('S*',1,2,3,4,5),
    '_as_param_ returns all array data');
$$ushortp[2] = 20;
is( $$ushortp[2], 20, '$$ptr[x] assignment again' );
is( $$array[2], 20, '$$array[x] = $$ptr[x]: array manipulated via $ptr' );

