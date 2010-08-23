package t_POINT;
use strict;
use warnings;
use Ctypes;
use Ctypes::Type::Struct;

our @ISA = qw|Ctypes::Type::Struct|;
our $_fields_ = [ x => c_int,
                  y => c_int, ];

sub new {
  my $class = ref($_[0]) || $_[0];   shift;
  my $self = $class->SUPER::new( $_fields_ );
  if $self {
    for($self->fields) {
      $_ = shift;
    }
    return bless $self => $class;
  } else {
    croak( "Couldn't create t_POINT" );
  }
}

1;
__END__
