#!perl

use Test::More tests => 2;
use Ctypes::Function;
use Ctypes::Callback;
use Data::Dumper;
use Devel::Peek;

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
      restype  => 'p' } );
$qsort->abi('c');
ok( defined $qsort, 'created function $qsort' );

my $cb = Ctypes::Callback->new( \&cb_func, 'i', 'ii' );
ok( defined $cb, 'created callback $cb' );

diag( Dumper( $qsort ) );

my @array = (2, 4, 5, 1, 3);
diag( $qsort->sig );
@array = $qsort->(@array, $#array, Ctypes::sizeof('i'), $cb->ptr);

is(@array, (1,2,3,4,5));

