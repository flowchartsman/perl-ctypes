#!perl

use Test::More tests => 2;
use Ctypes::Function;
use Ctypes::Callback;

sub cb_func {
my( $ay, $bee ) = @_;
if( ($ay+0) < ($bee+0) ) { return -1; }
if( ($ay+0) == ($bee+0) ) { return 0; }
if( ($ay+0) > ($bee+0) ) { return 1; }
}

my $qsort = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'qsort',
      argtypes => 'piip',
      restype  => '' } );
$qsort->abi('c');

my $cb = Ctypes::Callback->new( \&cb_func, 'iii' );

ok( defined $to_upper, '$to_upper created with hashref' );
my $ret = $to_upper->( ord("y") );
is($ret, ord("Y"));

