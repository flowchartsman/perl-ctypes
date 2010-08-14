package Flower;
our @ISA = 'Ctypes::Type::Struct';

sub new {
  my $class = ref($_[0]) || $_[0];   shift;
  
   my $progeny = undef;
  my $caller = (caller(1))[3];
  print "    caller is ", $caller, "\n" if $caller and $Debug == 1;
  if( defined $caller and $caller =~ m/::/ ) {  # need check for eval()s
    $caller =~ s/::(.*)$//;
    if( $caller->isa('Ctypes::Type::Struct') ) {
      $progeny = $caller;
    }
  }

  # What kind of input?
  my( $in_valsA, $in_valsH, $in_fields ) = [];
  if( ref($_[0]) eq 'HASH' ) {
    my $hashref = shift;
    # We only know about fields=> and values=>
    for my $key (keys(%{$hashref})) {
    croak(($progeny ? $progeny : 'Struct'), " error: unknown arg $key") 
      unless $key eq 'fields' or $key eq 'values';
    }
    $in_valsH   = $hashref->{values} if exists $hashref->{values};
    $in_fields = $hashref->{fields} if exists $hashref->{fields};
    if( !$in_valsH and @_ ) {  # So can specify fields in hashref
      $in_valsA = [ @_ ];      # and still list values lazily afterwards,
    }                         # without having to name them all :)
  } else {
    $in_valsA = [ @_ ];
  }

  
  my $self = $class->SUPER::new({ fields => $_fields_, values => [ @_ ] });
  return bless $self => $class if $self;
}

1;
