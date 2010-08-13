package Daffodil;
use Ctypes;
our @ISA = 'Flower';
our $_fields_ = [ ['trumpetsize', c_ushort ] ];

sub new {
  my $class = ref($_[0]) || $_[0];   shift;
  my $self = $class->SUPER::new( _fields_ => $_fields_, values => [ @_ ] );
  return bless $self => $class if $self;
}

