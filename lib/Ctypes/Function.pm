package Ctypes::Function;

use strict;
use warnings;
use DynaLoader;
use Data::Dumper;
use Devel::Peek;
use overload '&{}' => \&_call_overload;

=head1 NAME

Ctypes::Function - Object-oriented access to C function calls

=head1 VERSION

Version 0.001

=cut

=head1 SYNOPSIS

    use Ctypes::Function;

    my $func = Ctypes::Function->new( $library_name,
                                      $function_name,
                                      $signature );

    my $return_type = $func->rtype; #  'i' - integer
    
    my $result = $func->('16');

=head1 DESCRIPTION

Ctypes::Function abstracts the raw Ctypes::call() API allowing TODO

=head1 SUBROUTINES/METHODS

Ctypes will offer both a procedural and OO interface (to accommodate
both types of authors described above). At the moment only the
procedural interface is working.

=over

=item new (sig, addr, args)

The main procedural interface to libffi's functionality.
Calls a external function.

=cut

# To steal:
# 1. Accessor generation from Simon Cozens
# 3. namespace install from P5NCI

sub _get_args (\@\@;$) {
  my $args = shift;
  my $want = shift;
  my $ret = {};

  if (ref($args->[0]) eq 'HASH') {
    # Using named parameters.
    for(@{$want}) {
      $ret->{$_} = $args->[0]->{$_} }
  } else {
    # Using positional parameters.
    for(my $i=0; $i <= $#{$args}; $i++ ) {
      $ret->{$want->[$i]} = $args->[$i] }
  }
  return $ret;
}

sub _disambiguate {
  my( $first, $second ) = @_;
  if( defined $first && defined $second ) {
    die( "First and second values are different" )
      unless ( $second == $second );
  }
  $first ||= $second;
  return $first;
}

sub _call_overload {
  print "In _call_overload...\n";
  print Dumper( @_ );
  return sub { _call(@_) };
}

sub _call {
#  my $self = shift;
#  my $args = shift;
  print "In _call():\n";
  print Dumper( @_ ) . "\n";
#  print Dumper( $args );
  print "Exiting _call...\n";
return 0;
}

sub new {
  my ($class, @args) = @_;
  # default positional args are library, function name, function signature
  # will never make sense to pass func address or lib address positionally
  my @attrs = qw(lib name sig abi rtype func);
  our $ret  =  _get_args(@args, @attrs);
  # func is a function reference returned by dl_find_symbol
  our($lib, $name, $sig, $abi, $rtype, $func);
  {
    no strict 'refs';
    ($lib, $name, $sig, $abi, $rtype, $func)
      = map { $ret->{$_}; } @attrs;
  }

  if(!$func && !$name) { die( "Need function ref or name" ); }

  if(!$func) {
    if(!$lib) {
      die("Can't find function without a library!");
    } else {
      do {
        my $found = DynaLoader::dl_findfile( '-lm' )
          or die("-lm not found");
        $lib = DynaLoader::dl_load_file( $found );
      } unless ($lib =~ /^[0-9]$/); # looks like dl_load_file libref
    }
    $func = DynaLoader::dl_find_symbol( $lib, $name );
  }

  $ret->{'_setable'} = { name => 1, sig => 1, abi => 1, rtype => 1 };

  # "can bless a coderef, bless a glob, or overload &{}. All good."
#  no strict 'refs';
#  *{"Ctypes::".$func} = \%{$ret};
#  *{"Ctypes::".$func} = sub { Ctypes::Function::_call( \@_ ); };
#  local *glob = \*Ctypes::{$func};
#  bless \*glob, $class;
#  return *glob;

#  or
#  return bless sub { Ctypes::Function::_call(@_) }, $class;
  return bless $ret, $class;
}

sub AUTOLOAD {
  our $AUTOLOAD;
  my $self = shift;
  if( $AUTOLOAD =~  /.*::(.*)/ ) {
    return if $1 eq 'DESTROY';
    my $mem = $1;
    print "\@_: @_\n";
    print "\$1 -> $1\n";
    print "_setable? -> " . $self->{_setable}->{$1} . "\n";
    no strict 'refs';
    *$AUTOLOAD = sub { 
      @_ and $self->{_setable}->{$mem} ? return $self->{$mem} = $_[0]
              : ( warn("$mem not setable") and return $self->{$mem} );
    };
    goto &$AUTOLOAD;
  }
}

1;
