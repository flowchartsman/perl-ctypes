#!perl

use Test::More tests => 4;
use Ctypes::Function;

my $function_01 = Ctypes::Function->new( 'c', 'toupper', 'cii' );
ok( defined $function_01, '$function_01 created' );
my $ret = $function_01->( ord("y") );
is($ret, ord("Y"));

$function_01 = Ctypes::Function->new( { lib    =>'c',
					name   => 'toupper',
					atypes => 'i',
					rtype  => 'i' } );
ok( defined $function_01, '$function_01 created with hashref' );
$ret = $function_01->( ord("y") );
is($ret, ord("Y"));
