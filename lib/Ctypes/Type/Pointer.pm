package Ctypes::Type::Pointer;
use strict;
use warnings;
use Carp;
use Ctypes;
use Data::Dumper;
use overload
  '+'      => \&_add_overload,
  '-'      => \&_substract_overload,
  '${}'    => \&_scalar_overload,
  '@{}'    => \&_array_overload,
  fallback => 'TRUE';

our @ISA = qw|Ctypes::Type|;
my $Debug = 0;

=head1 NAME

Ctypes::Type::Pointer - What's that over there?

=head1 SYNOPSIS

  (see t/Pointer.t for now)

=cut

############################################
# TYPE::POINTER : PRIVATE FUNCTIONS & DATA #
############################################

sub _add_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{offset} + $y; }
    else { $ret = $y->{offset} + $x; }
  } else {           # += etc.
    $x->{offset} = $x->{offset} + $y;
    $ret = $x;
  }
  return $ret;
}

sub _array_overload {
  print ". . .._wearemany_.. . .\n" if $Debug == 1;
  return shift->{bytes};
}

sub _scalar_overload {
  print "We are One ^_^\n" if $Debug == 1;
  return \shift->{contents}; 
}

sub _subtract_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{offset} - $y; }
    else { $ret = $x - $y->{offset}; }
  } else {           # -= etc.
    $x->{offset} -= $y;
    $ret = $x;
  }
  return $ret;
}

############################################
# TYPE::POINTER : PUBLIC FUNCTIONS & DATA  #
############################################

sub new {
  my $class = ref($_[0]) || $_[0]; shift;
  my( $type, $contents );
#  return undef unless defined($contents);  # No null pointers plz :)

  if( scalar @_ == 1 ) {
    $type = $contents = shift;
  } elsif( scalar @_ > 1 ) {
    $type = shift;
    $contents = shift;
  }

  carp("Useage: Pointer( [type, ] \$object )") if @_;

  return undef unless Ctypes::is_ctypes_compat($contents);

  $type = $type->_typecode_ if ref($type);
  if( not Ctypes::sizeof($type) ) {
    carp("Invalid Array type specified (first position argument)");
    return undef;
  }
  my $self = $class->SUPER::new;
  my $attrs = {
     name        => $type.'_Pointer',
     size        => Ctypes::sizeof('p'),
     offset      => 0,
     contents    => $contents,
     bytes       => undef,
     orig_type   => $type,
     _typecode_  => 'p',
     _datasafe   => 1,
               };
  for(keys(%{$attrs})) { $self->{$_} = $attrs->{$_}; };
  bless $self => $class;

  $self->{_rawcontents} =
    tie $self->{contents}, 'Ctypes::Type::Pointer::contents', $self;
  $self->{_rawbytes} =
    tie @{$self->{bytes}},
          'Ctypes::Type::Pointer::bytes',
          $self;
  $self->{contents} = $contents;
  return $self;
}

sub deref () : method {
  return ${shift->{contents}};
}

sub _as_param_ {
  my $self = shift;
  print "In ", $self->{name}, "'s _As_param_, from ", join(", ",(caller(1))[0..3]), "\n" if $Debug == 1;
  if( defined $self->{_data} 
      and $self->{_datasafe} == 1 ) {
    print "already have _as_param_:\n" if $Debug == 1;
    print "  ", $self->{_data}, "\n" if $Debug == 1;
    print "   ", unpack('b*', $self->{_data}), "\n" if $Debug == 1;
    return \$self->{_data} 
  }
# Can't use $self->{contents} as FETCH will bork at _datasafe
# use $self->{_raw}{DATA} instead
  $self->{_data} =
    ${$self->{_rawcontents}{DATA}->_as_param_};
  print "  ", $self->{name}, "'s _as_param_ returning ok...\n" if $Debug == 1;
  $self->{_datasafe} = 0;  # used by FETCH
  return \$self->{_data};
}

sub _update_ {
  my( $self, $arg ) = @_;
  print "In ", $self->{name}, "'s _UPDATE_, from ", join(", ",(caller(0))[0..3]), "\n" if $Debug == 1;
  print "  self is ", $self, "\n" if $Debug == 1;
  print "  arg is $arg\n" if $Debug == 1;
  print "  which is\n", unpack('b*',$arg), "\n  to you and me\n" if $Debug == 1;
  $arg = $self->{_data} unless $arg;

  my $success = $self->{_rawcontents}{DATA}->_update_($arg);
  if(!$success) {
    croak($self->{name}, ": Error updating contents!");
  }
# 
#  $self->{_data} = $self->_as_param_;
  $self->{_datasafe} = 1;
  return 1;
}

#
# Accessor generation
#
my %access = (
  _typecode_        => ['_typecode_'],
  name              => ['name'],
  size              => ['size'],
  contents          => ['contents'],
  type              => ['orig_type'],
  offset            => ['offset',undef,1],
             );
for my $func (keys(%access)) {
  no strict 'refs';
  my $key = $access{$func}[0];
  *$func = sub {
    my $self = shift;
    my $arg = shift;
    croak("The $key method only takes one argument") if @_;
    if($access{$func}[1] and defined($arg)){
      eval{ $access{$func}[1]->($arg); };
      if( $@ ) {
        croak("Invalid argument for $key method: $@");
      }
    }
    if($access{$func}[2] and defined($arg)) {
      $self->{$key} = $arg if $arg;
    }
    return $self->{$key};
  }
}

package Ctypes::Type::Pointer::contents;
use warnings;
use strict;
use Carp;
use Ctypes;

sub TIESCALAR {
  my $class = shift;
  my $owner = shift;
  my $self = { owner => $owner,
               DATA  => undef,
             };
  return bless $self => $class;
}

sub STORE {
  my( $self, $arg ) = @_;
  print "In ", $self->{owner}{name}, "'s content STORE, from ", (caller(1))[0..3], "\n" if $Debug == 1;
  if( not Ctypes::is_ctypes_compat($arg) ) {                              
    if ( $arg =~ /^\d*$/ ) {                                              
croak("Cannot make Pointer to plain scalar; did you mean to say '\$ptr++'?")
    }                                                                     
  croak("Pointers are to Ctypes compatible objects only")                 
  }          
  $self->{owner}{_data} = undef;
  $self->{owner}{offset} = 0; # makes sense to reset offset
  print "  ", $self->{owner}{name}, "'s content STORE returning ok...\n" if $Debug == 1;
  return $self->{DATA} = $arg;
}

sub FETCH {
  my $self = shift;
  print "In ", $self->{owner}{name}, "'s content FETCH, from ", (caller(1))[0..3], "\n" if $Debug == 1;
  if( defined $self->{owner}{_data}
      and $self->{owner}{_datasafe} == 0 ) {
    print "    Woop... _as_param_ is ", unpack('b*',$self->{owner}{_data}),"\n" if $Debug == 1;
    my $success = $self->{owner}->_update_(${$self->{owner}->_as_param_});
    croak($self->{name},": Could not update contents!") if not $success;
  }
  croak("Error! Data not safe!") if $self->{owner}{_datasafe} != 1;
  print "  ", $self->{owner}{name}, "'s content FETCH returning ok...\n" if $Debug == 1;
  print "  Returning ", ${$self->{DATA}}, "\n" if $Debug == 1;
  return $self->{DATA};
}

package Ctypes::Type::Pointer::bytes;
use warnings;
use strict;
use Carp;
use Ctypes;

sub TIEARRAY {
  my $class = shift;
  my $owner = shift;
  my $self = { owner => $owner,
               DATA  => [],
             };
  return bless $self => $class;
}

sub STORE {
  my( $self, $index, $arg ) = @_;
  print "In ", $self->{owner}{name}, "'s Bytes STORE, from ", (caller(0))[0..3], "\n" if $Debug == 1;
  if( ref($arg) ) {
    carp("Only store simple scalar data through subscripted Pointers");
    return undef;
  }

  my $data = $self->{owner}{contents}->_as_param_;
  print "\tdata is $$data\n" if $Debug == 1;
  my $each = Ctypes::sizeof($self->{owner}{orig_type});

  my $offset = $index + $self->{owner}{offset};
  if( $offset < 0 ) {
    carp("Pointer cannot store before start of data");
    return undef;
  }
  if( $offset >= length($$data)                  # start at end of data
      or ($offset + $each) > length($$data) ) {  # or will go past it
    carp("Pointer cannot store past end of data");
  }

  print "\teach is $each\n" if $Debug == 1;
  print "\tdata length is ", length($$data), "\n" if $Debug == 1;
  my $insert = pack($self->{owner}{orig_type},$arg);
  print "insert is ", unpack('b*',$insert), "\n" if $Debug == 1;
  if( length($insert) != Ctypes::sizeof($self->{owner}{orig_type}) ) {
    carp("You're about to break something...");
# ??? What would be useful feedback here? Aside from just not doing it..
  }
  print "\tdata before and after insert:\n" if $Debug == 1;
  print unpack('b*',$$data), "\n" if $Debug == 1;
  substr( $$data,
          $each * $offset,
          Ctypes::sizeof($self->{owner}{orig_type}),
        ) =  $insert;
  print unpack('b*',$$data), "\n" if $Debug == 1;
  $self->{DATA}[$index] = $insert;  # don't think this can be used
  $self->{owner}{contents}->_update_($$data);
  print "  ", $self->{owner}{name}, "'s Bytes STORE returning ok...\n" if $Debug == 1;
  return $insert;
}

sub FETCH {
  my( $self, $index ) = @_;
  print "In ", $self->{owner}{name}, "'s Bytes FETCH, from ", (caller(1))[0..3], "\n" if $Debug == 1;

  my $type = $self->{owner}{orig_type};
  if( $type =~ /[pv]/ ) {
    carp("Pointer is to type ", $type,
         "; can't know how to dereference data");
    return undef;
  }

  my $data = $self->{owner}{contents}->_as_param_;
  print "\tdata is $$data\n" if $Debug == 1;
  my $each = Ctypes::sizeof($self->{owner}{orig_type});

  my $offset = $index + $self->{owner}{offset};
  if( $offset < 0 ) {
    carp("Pointer cannot look back past start of data");
    return undef;
  }
  my $start = $offset * $each;
  # 1-byte types can start on last byte and be fine
  if( $start + ($each - 1) > length($$data) ) {
    carp("Pointer cannot look past end of data");
    return undef;
  }

  print "\toffset is $offset\n" if $Debug == 1;
  print "\teach is $each\n" if $Debug == 1;
  print "\tstart is $start\n" if $Debug == 1;
  print "\torig_type: ", $self->{owner}{orig_type}, "\n" if $Debug == 1;
  print "\tdata length is ", length($$data), "\n" if $Debug == 1;
  my $chunk = substr( $$data,
                      $each * $offset,
                      Ctypes::sizeof($self->{owner}{orig_type})
                    );
  print "\tchunk: ", unpack('b*',$chunk), "\n" if $Debug == 1;
  $self->{DATA}[$index] = $chunk;
  print "  ", $self->{owner}{name}, "'s Bytes FETCH returning ok...\n" if $Debug == 1;
  return unpack($self->{owner}{orig_type},$chunk);
}

sub FETCHSIZE {
  my $data = $_[0]->{owner}{contents}{_data}
  ? $_[0]->{owner}{contents}{_data}
  : $_[0]->{owner}{contents}->_as_param_;
  return length($data) / Ctypes::sizeof($_[0]->{owner}{orig_type});
}

1;
