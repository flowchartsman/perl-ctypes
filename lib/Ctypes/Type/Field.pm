package Ctypes::Type::Field;
use Ctypes::Type;
use Data::Dumper;
use overload
  '""'     => sub { return $_[0]->FETCH },
  '&{}'    => \&_code_overload,
  fallback => 'TRUE';

our $Debug = 0;

sub _code_overload {
  my $self = shift;
  return sub { STORE( $self, @_ ) };
}

sub _code_overload {
  print "Did we get to code overload?\n";
  print "args: ", Dumper( @_ );
  return &STORE;
}

sub TIESCALAR {
  my $class = ref($_[0]) || $_[0];  shift;
  my $name  = shift;
  my $type = shift;
  my $offset = shift;
  my $owner  = shift;
  my $self  = {
                CONTENTS  => undef,
                _owner    => $owner,
                _name     => $name,
                _typecode => $type->type,
                _typename => $type->name,
                _size     => $type->size,
                _offset   => $offset,
              };
  print "In Field's TIESCALAR\n" if $Debug == 1;
  print "    got offset $offset\n" if $Debug == 1;
  return bless $self => $class;
}

#
# Accessor generation
#
my %access = ( 
  typecode          => ['_typecode'],
  type              => ['_typecode'],
  typename          => ['_typename'],
  alignment         => ['_alignment'],
  name              => ['_name'],
  size              => ['_size'],
  contents          => ['CONTENTS'],
  offset            => ['_offset'],
  owner             => ['_owner'],
             );
for my $func (keys(%access)) {
  no strict 'refs';
  my $key = $access{$func}[0];
  *$func = sub {
    my $self = shift;
    my $arg = shift;
#    print "In $func accessor\n" if $Debug == 1;
    croak("The $key method only takes one argument") if @_;
    if($access{$func}[1] and defined($arg)){
      eval{ $access{$func}[1]->($arg); };
      if( $@ ) {
        croak("Invalid argument for $key method: $@");
      }
    }
    if($access{$func}[2] and defined($arg)) {
      $self->{$key} = $arg;
    }
#    print "    $func returning $key...\n" if $Debug == 1;
    return $self->{$key};
  }
}

sub STORE {
  $DB::single = 1;
  my( $self, $val ) = @_;
  print "In ", $self->{_owner}{_name}, "'s ", $self->{_name}, " field STORE, called from ", join(", ",(caller(1))[0..3]), "\n" if $Debug == 1;
  print "    arg is ", $val, "\n" if $Debug == 1;
  print "    self is ", $self->name, "\n" if $Debug == 1;
  # Check if key exists ### Done in object
  if( !ref($val) ) {
    $val = new Ctypes::Type::Simple( $self->{_typecode}, $val );
    if( not defined $val ) {
      carp("Could not create " . $self->{_owner}{_fields}{$key}[1]->name
           . " type from argument '$val'");
      return undef;
    }
    $val->{_needsfree} = 1;
  }

  if( $val->name ne $self->{_typename} ) {
    carp( "Cannot put " . $val->name . " type object into "
          . $self->{_typename} . " type field" );
    return undef;
  }

  if( $self->{CONTENTS} ) {
    $self->{CONTENTS}->{_owner} = undef;
#    if( $self->{CONTENTS}{_needsfree} == 1 )  # If this were C (or
# if it were someday being translated to C), I think this might be where
# one would make use of the disappearing object's _needsfree attribute.
  }
  print "    Setting field ", $self->{_name}, " to $val\n" if $Debug == 1;
  $self->{CONTENTS} = $val;
  print "    Setting Owner to ", $self->{_owner}{_name}, "\n" if $Debug == 1;
  $self->{CONTENTS}->{_owner} = $self->{_owner};
  $self->{CONTENTS}->{_index} = $self->{_offset};
  print "CONTENTS' INDEX IS NOW ", $self->{_offset}, "\n" if $Debug == 1;

  my $datum = ${$val->_data};
  $self->{_owner}->_update_($datum, $self->{_offset});
  
  return $self->{CONTENTS}; # success
}

sub FETCH : lvalue {
  $DB::single = 1;
  my $self = shift;
  print "In ", $self->owner->name, "'s ", $self->name, " field FETCH,\n\tcalled from ", (caller(1))[0..3], "\n" if $Debug == 1;
  if( defined $self->{_owner}{_owner}
      or $self->{_owner}{_datasafe} == 0 ) {
    print "    Can't trust data, updating...\n" if $Debug == 1;
    $self->{_owner}->_update_;
  }
  croak("Error updating values!") if $self->{_owner}{_datasafe} != 1;

#  if( ref($self->{CONTENTS}) eq 'Ctypes::Type::Simple' ) {
#  print "    ", $self->{_owner}{_name}, "'s ", $self->{_name}, " field FETCH returning ", ${$self->{CONTENTS}} "\n" if $Debug == 1;
#    return ${$self->{HASH}{$key}};
#  } else {
  print "    ", $self->{_owner}{_name}, "'s ", $self->{_name}, " field FETCH returning ", $self->{CONTENTS}, "\n" if $Debug == 1;
    return $self->{CONTENTS};
#  }
}       

1;
