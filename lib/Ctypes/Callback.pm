package Ctypes::Callback;

use strict;
use warnings;
use Ctypes;
use Ctypes::Function;
use Data::Dumper;
use Devel::Peek;

# Public functions defined in POD order
sub new;
sub ptr;

=head1 NAME

Ctypes::Callback - Define a callback to call a Perl function from C

=head1 VERSION

Version 0.002

=head1 SYNOPSIS

    use Ctypes::Callback;

    <TODO: insert qsort example here>

=head1 DESCRIPTION

TODO: Description

=cut


################################
#   PRIVATE FUNCTIONS & DATA   #
################################

################################
#       PUBLIC FUNCTIONS       #
################################

=head1 PUBLIC METHODS

=head2 new ( \&coderef, sig )

or hash-style: new ( { code => \&coderef, sig => 'iii' } )

TODO: new() documentation

=cut

sub new {
  my ($class, @args) = @_;
  # Default positional args are coderef, sig. 
  # Will never make sense to pass restype or argtypes positionally
  my @attrs = qw(coderef restype argtypes);
  our $self  =  Ctypes::Function::_get_args(@args, @attrs);

  # Just so we don't have to continually dereference $self
  my ($coderef, $restype, $argtypes)
      = (map { \$self->{$_}; } @attrs );

  $self->{sig} = $$restype . $$argtypes; # both specified packstyle strings

  # Call out to XS to return two pointers
  # $self->{_executable} will be the 'useful' one returned by $obj->ptr();
  # $self->{_writable} is needed for ffi_closure_free in DESTROY
#  ( $self->{_writable}, $self->{_executable}, $self->{_cb_data} ) = _make_callback( $$coderef, $self->{sig} );
  my @returns = _make_callback( $$coderef, $self->{sig} );
  print Dump( $returns[0] );
  print Dump( $returns[1] );
  print Dump( $returns[2] );

  if(!$self->{_writable}) { die( "Oh no! No callback address!"); }
  if(!$self->{_executable}) { die( "Oh no! No executable address!"); }
  if(!$self->{_cb_data}) { die( "No callback data! Memoryleak-tastic!" ); }

  return bless $self, $class;
}

=head2 ptr()

TODO: ptr documentation

=cut

sub ptr { return shift->_executable };

1;
