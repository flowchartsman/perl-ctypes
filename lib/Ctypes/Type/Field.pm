package Ctypes::Type::Field;
use Ctypes;
use Ctypes::Type::Struct;
use Carp;
use Data::Dumper;
use overload
  '""'     => \&_string_overload,
  '&{}'    => \&_code_overload,
  fallback => 'TRUE';

our $Debug = 0;

sub _string_overload {
  my $self = shift;
  return "<Field type=" . $self->typename . ", ofs=" .
    $self->offset . ", size=" . $self->size . ">";
}
sub _code_overload {
  my $self = shift;
  return sub { STORE( $self, @_ ) };
}

sub _code_overload {
  print "Did we get to code overload?\n" if $Debug == 1;
  print "args: ", Dumper( @_ ) if $Debug == 1;
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
  contents          => ['CONTENTS',undef,1],
  offset            => ['_offset'],
  owner             => ['_owner',undef,1],
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
  print "In ", $saelf->{_owner}{_name}, "'s ", $self->{_name}, " field STORE, called from ", join(", ",(caller(1))[0..3]), "\n" if $Debug == 1;
  print "    arg is ", $val, "\n" if $Debug == 1;
  print "    self is ", $self->name, "\n" if $Debug == 1;
  # Check if key exists ### Done in object
  print $self->{CONTENTS}, "\n" if $Debug == 1;
  if( !ref($val) ) {
    print "    val was not a reference\n" if $Debug == 1;
    if( not defined $self->contents ) {
      $val = new Ctypes::Type::Simple( $self->typecode, $val );
      if( not defined $val ) {
        carp("Could not create " . $self->typecode
             . " type from argument '$val'");
        return undef;
      }
      $val->{_needsfree} = 1;
    } else {
      print "    Setting field ", $self->{_name}, " to $val\n" if $Debug == 1;
      ${$self->{CONTENTS}} = $val;
    }
  } else {
    if( $val->name ne $self->{_typename} ) {
      carp( "Cannot put " . $val->name . " type object into "
            . $self->{_typename} . " type field" );
      return undef;
    }
    if( $self->{CONTENTS} ) {
      $self->{CONTENTS}->{_owner} = undef;
    }
    print "    Setting field ", $self->{_name}, " to $val\n" if $Debug == 1;
    $self->{CONTENTS} = $val;
  }

  if( not defined $self->contents ) { $self->contents($val) }
  my $datum = ${$self->contents->_data};
  $self->contents->owner = $self->owner;
  print "    Self->offset is ", $self->offset, "\n" if $Debug == 1;
  $self->contents->_index($self->offset);
  print "CONTENTS' INDEX IS NOW ", $self->contents->_index, "\n" if $Debug == 1;
  print "contents is now ", $self->contents, "\n" if $Debug == 1;
  $self->owner->_update_($datum, $self->offset);
  print "    Setting Owner to ", $self->{_owner}{_name}, "\n" if $Debug == 1;
  
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

sub AUTOLOAD {
  our $AUTOLOAD;
  if ( $AUTOLOAD =~ /.*::(.*)/ ) {
    return if $1 eq 'DESTROY';
    my $wantfield = $1;
    print "Trying to AUTOLOAD for $wantfield in FIELD\n"; # if $Debug == 1;
    my $self = shift;
    return $self->contents->$wantfield;
  }
}

1;
