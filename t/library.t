#!perl
use Test::More tests => 3;

use Ctypes;
my $lib;

#if ($^O =~ /(MSWin32|cygwin)/) {
#   $lib = CDLL->msvcrt;
#   ok( defined $lib, 'declare msvcrt' ) 
#     or diag( DynaLoader::dl_error() );
#} else {

   # cross-platform
   $lib = CDLL->libc;
   ok( defined $lib, 'declare libc' ) 
     or diag( DynaLoader::dl_error() );

#}

my $func = $lib->toupper;
ok( defined $func, 'found toupper in libc' );

my $ret = $lib->toupper({sig => "cii"}, ord("y"));
is( chr($ret), 'Y', "call toupper('y') => " . chr($ret) );
