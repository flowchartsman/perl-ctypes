#!perl

use Test::More tests => 2;
use Ctypes::Function;

$to_upper = Ctypes::Function->new( { lib    =>'c',
                                     name   => 'toupper',
                                     atypes => 'i',
                                     rtype  => 'i' } );
ok( defined $to_upper, '$to_upper created with hashref' );
$ret = $to_upper->( ord("y") );
is($ret, ord("Y"));
