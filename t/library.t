#!perl
use Test::More tests => 3;

use Ctypes;
# cross-platform
my $lib = CDLL->libc;
ok( defined $lib, 'declare libc' ) 
  or diag( Ctypes::load_error() );

my $func = $lib->toupper;
ok( defined $func, 'found toupper in libc' );

my $ret = $lib->toupper({sig => "cii"})->(ord("y"));
is( chr($ret), 'Y', "call toupper('y') => " . chr($ret) );
