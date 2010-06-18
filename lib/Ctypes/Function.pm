package Ctypes::Function;

use strict;
use warnings;

# To steal:
# 1. Accessor generation from Simon Cozens
# 2. hash / list initialization from C::DynaLib
# 3. namespace install from P5NCI

sub _get_args (\@\@;$) {
  my @args = shift;
  my @want = shift;
  my $ret = {};

  if (ref($args[0]) eq 'HASH') {
    # Using named parameters.
    for(@want)
      $ret->{$_} = $args[0]->{$_};
  } else {
    # Using positional parameters.
    for(my $i=0; $i <= $#want; $i++ )
      $ret->{$want[$i]} = $want[$i]
  }
  return $ret;
}


sub new {
  my ($class, @args) = @_;
  #default positional args are library, function name, function signature
  my @attrs = qw(lib c_name sig abi ret_type ptr);
  my $args = _get_args(@args, @attrs);
  
  # sig is specified with '_' between abi / return type and argument types!

  if(!$ptr) {
    if(!$lib) {
      # problemz!
    } else {
      # look for func in lib
   }

   # my $signature = abi + ret_type + sig...

   return sub { Ctypes::call( $args->c_name, $signature, @_ ); }
}

sub AUTOLOAD {
  my $self = shift;
  if( $AUTOLOAD =~  /.*::(.*)/ ) {
    return if $1 = 'DESTROY';
    return $self->{$1};
}
