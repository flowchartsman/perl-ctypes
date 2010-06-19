#!perl

use Test::More tests => 1;

use Ctypes::Function;
use DynaLoader;
use Data::Dumper;
use Devel::Peek;

# my $function_01 = Ctypes::Function->new( { lib =>'-lm', name => 'sqrt' } );
my $function_01 = Ctypes::Function->new( '-lm', 'sqrt' );
ok( defined $function_01, '$function_01 created' );

diag( Dumper( $function_01 ) );
diag( Dump( $function_01 ) );
$function_01->( 'blork' );
