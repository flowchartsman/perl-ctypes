#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Ctypes' ) || print "Bail out!
";
}

diag( "Testing Ctypes $Ctypes::VERSION, Perl $], $^X" );
diag( "Use -DCTYPES_TEST_VERBOSE for detailed XS output" );
