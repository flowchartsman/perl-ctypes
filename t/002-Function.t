#!perl

use Test::More tests => 1;

use Ctypes::Function;
use DynaLoader;

my $function_01 = Ctypes::Function->new( '-lm', 'sqrt' );
ok( defined $function_01, '\$function_01 created' );

diag( $function_01->('blork') );

