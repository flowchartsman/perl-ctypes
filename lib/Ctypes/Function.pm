package Ctypes::Function;

use strict;
use warnings;
use Ctypes;

=head1 NAME

Ctypes::Function - Object-oriented access to C function calls

=head1 VERSION

Version 0.001

=cut

=head1 SYNOPSIS

    use Ctypes::Function;

    $toupper = Ctypes::Function->new( "-lc", "toupper", "cii" );
    $result = $func->(ord("y"));

    # or
    $toupper = Ctypes::Function->new({ lib    => 'c',
                                       name   => 'toupper',
                                       atypes => 'i',
                                       rtype  => 'i' } );
    $result = chr($toupper->(ord("y")));

=head1 DESCRIPTION

Ctypes::Function abstracts the raw Ctypes::call() API

=head1 METHODS

=over

=item new (lib, name, sig)

The main object-orientated interface to libffi's functionality.
Call an external function.

  lib   -llibname or soname/dllname. Default: -lc (the "libc")
  name  external function name
  sig   signature string, consisting of
    abi   c for 'cdecl', s for 'stdcall' or f for 'fastcall',
    rtype  pack-style return type. Default: i for int
    atypes pack-style characters for the argument types

The arguments may be defined as HASHREF with the additional keys:

  abi   'cdecl', 'stdcall' or 'fastcall'. Default: 'cdecl'
  rtype  pack-style return type. Default: i for int
  atypes pack-style characters for the argument types
  func   function address

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

sub _call (\@;) {
  my $self = shift;
  return Ctypes::call($self->{func}, $self->{sig}, @_);
}

sub new {
  my ($class, @args) = @_;
  # default positional args are library, function name, function signature
  # will never make sense to pass func address or lib address positionally
  my @attrs = qw(lib name sig abi rtype atypes func);
  my $ret  =  _get_args(@args, @attrs);
  # func is a function address returned by dl_find_symbol
  our ($lib, $name, $sig, $abi, $rtype, $atypes, $func);
  {
    no strict 'refs';
    ($lib, $name, $sig, $abi, $rtype, $atypes, $func)
      = map { $ret->{$_}; } @attrs;
  }

  if (!$func && !$name) { die( "Need function name or addr" ); }

  $lib = '-lc' unless $lib; #default libc
  $lib = Ctypes::find_library( $lib )
    or die("Library $lib not found");
  $func = Ctypes::find_function( $lib, $name )
    unless $func;
  die("Function $name not found") unless $func;

  if (!$abi and $sig) {
    $abi    = substr($sig,0,1);
    $rtype  = substr($sig,1,1);
    $atypes = substr($sig,2);
  }
  if (!$abi) { # hash-style: depends on the lib, default: 'c'
    $abi = 'c';
    $abi = 's' if $^O eq 'MSWin32' and $lib =~ /(user32|kernel32|gdi)/;
  } else {
    $abi =~ /^(cdecl|stdcall|fastcall|c|s|f)$/
      or die "invalid abi $abi";
    $abi = 'c' if $abi eq 'cdecl';
    $abi = 's' if $abi eq 'stdcall';
    $abi = 'f' if $abi eq 'fastcall';
  }
  $rtype = 'i' unless $rtype;
  $sig = $abi . $rtype . $atypes unless $sig;
  my $props = {};
  {
    no strict 'refs';
    $props->{$_} = $$_ for @attrs;
  }
  # no strict 'refs';
  # %{"Ctypes::".$func} = %{$ret};
  # can bless a coderef, bless a glob, or overload &{}. All good.
  # *{"Ctypes::".$func} = \&{ Ctypes::Function::_call( @_ ); };
  my $self = bless $props, $class;
  return sub { $self->_call(@_) };
}

1;
