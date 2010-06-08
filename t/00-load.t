#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Ctypes' ) || print "Bail out!
";
}

diag( "Testing Cdll $Ctypes::VERSION, Perl $], $^X" );
