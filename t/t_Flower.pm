package Flower;
our @ISA = 'Ctypes::Type::Struct';

sub new {
  my $class = ref($_[0]) || $_[0];   shift;
  my $self = $class->SUPER::new( _fields_ => $_fields_, values => [ @_ ] );
  return bless $self => $class if $self;
}

1;
