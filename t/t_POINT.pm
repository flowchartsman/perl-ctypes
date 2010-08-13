package t_POINT;
use strict;
use warnings;
use Ctypes;
use Ctypes::Type::Struct;

our @ISA = qw|Ctypes::Type::Struct|;
our $_fields_ = [ ['x',c_int],
                  ['y',c_int], ];

sub new {
  my $class = ref($_[0]) || $_[0];   shift;
  my $self = $class->SUPER::new( _fields_ => $_fields_, values => [ @_ ] );
  return bless $self => $class if $self;
}

1;
__END__
