#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Ctypes' ) || print "Bail out!
";
}

diag( "Testing Ctypes $Ctypes::VERSION, Perl $], $^X" );
diag( "Use -DCTYPES_DEBUG for detailed XS output" );
