#!perl

use Test::More tests => 2;

use Ctypes::Function;
use DynaLoader;
use Data::Dumper;
use Devel::Peek;

my $function_01 = Ctypes::Function->new( '-lc', 'toupper' );
ok( defined $function_01, '$function_01 created' );

$function_01->name('tupperware');
$function_01->sig('cii');
is( chr($function_01->('y')), 'Y', "Gave 'y' to \$function_01, got 'Y'");

