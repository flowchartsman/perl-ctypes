#!perl
use Test::More tests => 5;

use Ctypes;
# cross-platform
my $lib = CDLL->c;
ok( defined $lib, 'declare libc' ) 
  or diag( Ctypes::load_error() );

my $symb = $lib->toupper;
ok( defined $symb, 'found toupper in libc' );

my $func = $lib->toupper({sig => "ii"});
ok( defined $func, 'declare toupper via lib' );
my $ret = $func->(ord("y"));
ok( $ret, 'func callable' );

$ret = $lib->toupper({sig => "ii"})->(ord("y"));
is( chr($ret), 'Y', "direct call lib->toupper('y') => " . chr($ret) );
