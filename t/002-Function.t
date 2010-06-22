#!perl

use Test::More tests => 2;
use Ctypes::Function;

my $to_upper = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'toupper',
      sig    => 'i',
      rtype  => 'i' } );
ok( defined $to_upper, '$to_upper created with hashref' );
my $ret = $to_upper->( ord("y") );
is($ret, ord("Y"));
