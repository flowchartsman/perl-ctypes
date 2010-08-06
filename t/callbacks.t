#!perl

use Test::More tests => 3;
use Ctypes::Function;
use Ctypes::Callback;

sub cb_func {
  my( $ay, $bee ) = @_;
  print "    \$ay is $ay, \$bee is $bee...";
  if( ($ay+0) < ($bee+0) ) { print " returning -1!\n"; return -1; }
  if( ($ay+0) == ($bee+0) ) { print " returning 0!\n"; return 0; }
  if( ($ay+0) > ($bee+0) ) { print " returning 1!\n"; return 1; }
}

my $qsort = Ctypes::Function->new
  ( { lib    => 'c',
      name   => 'qsort',
      argtypes => 'piip',
      restype  => 'v' } );
$qsort->abi('c');
ok( defined $qsort, 'created function $qsort' );

my $cb = Ctypes::Callback->new( \&cb_func, 'i', 'ii' );
ok( defined $cb, 'created callback $cb' );

my @array = (2, 4, 5, 1, 3);
note( "Initial array: ", join(", ", @array) );

my $arg = pack('i*', @array);

$qsort->(\$arg, $#array+1, Ctypes::sizeof('i'), $cb->ptr);

my @res = unpack( 'i*', $arg  );
my $arrstring = join(", ", @res);

is($arrstring, "1, 2, 3, 4, 5" , "Array reordered: $arrstring" );
