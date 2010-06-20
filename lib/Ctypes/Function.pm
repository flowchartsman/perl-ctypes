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
    # or:
    my $func = Ctypes::Function->( { lib  => '-lm',
                                     name => 'sqrt',
                                     sig  => 'cdd',
                                 } );
    # or simply:
    my $func = Ctypes::Function->( { func => $func_ref,
                                     sig  => 'cdd',
                                 } );

    my $result = $func->('25');  # 5! Zounds!

=head1 DESCRIPTION

Ctypes::Function abstracts the raw Ctypes::call() API allowing TODO

=head1 PUBLIC SUBROUTINES/METHODS

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

# For which members will AUTOLOAD provide mutators?
my $_setable = { name => 1, sig => 1, abi => 1, rtype => 1 };

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
  my $self = shift;
  return sub { _call($self, @_) };
}

=over

=item update(name, sig, abi, args)

or 

=item update({ param => value, [...] })

C<update> provides a quick way of changing many attributes of a function
all at once. Only the function's C<lib> and C<func> references cannot
be updated (because that wouldn't make any sense).

=cut

sub update {
  my $self = shift;
  my @args = @_;
  my @want = qw(name sig abi rtype);
  my $update_self = _get_args(@args, @want);
  for(@want) {
    if(defined $update_self->{$_}) {
      $self->{$_} = $update_self->{$_};
    }
  }
  return $self;
}

sub _call {
  my $self = shift;
  my @args = @_;
  print Dumper( $self ); 
  print Dumper( @args );
return 0;
}

sub new {
  my ($class, @args) = @_;
  # default positional args are library, function name, function signature
  # will never make sense to pass func address or lib address positionally
  my @attrs = qw(lib name sig abi rtype func);
  our $ret  =  _get_args(@args, @attrs);

  # Just so we don't have to continually dereference $ret
  my($lib, $name, $sig, $abi, $rtype, $func)
      = (map { \$ret->{$_}; } @attrs );

  if(!$$func && !$$name) { die( "Need function ref or name" ); }

  if(!$$func) {
    if(!$$lib) {
      die("Can't find function without a library!");
    } else {
      do {
        my $found = DynaLoader::dl_findfile( '-lm' )
          or die("-lm not found");
        $$lib = DynaLoader::dl_load_file( $found );
      } unless ($$lib =~ /^[0-9]$/); # looks like dl_load_file libref
    }
    $$func = DynaLoader::dl_find_symbol( $$lib, $$name );
  }
  return bless $ret, $class;
}

sub AUTOLOAD {
  our $AUTOLOAD;
  my $self = shift;
  if( $AUTOLOAD =~  /.*::(.*)/ ) {
    return if $1 eq 'DESTROY';
    my $mem = $1;
    no strict 'refs';
    *$AUTOLOAD = sub { 
      @_ and $_setable->{$mem} ? return $self->{$mem} = $_[0]
              : ( warn("$mem not setable") and return $self->{$mem} );
    };
    goto &$AUTOLOAD;
  }
}

1;
