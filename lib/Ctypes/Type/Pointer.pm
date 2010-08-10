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
  return shift->{bytes};
}

sub _scalar_overload {
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
  my $class = shift;
  my $contents = shift;
  return undef unless defined($contents);  # No null pointers plz :)

  return undef unless Ctypes::is_ctypes_compat($contents);

  my $tc = $contents->_typecode_;
  my $self = { name        => $tc.'_Pointer',
               size        => Ctypes::sizeof('p'),
               offset      => 0,
               contents    => $contents,   # \reference?
               bytes       => undef,
               orig_type   => $tc,
               _as_param_  => undef,
               _typecode_  => 'p',
               _datasafe   => 1,
             };
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
  $self->{_datasafe} = 0;  # used by FETCH
  if( defined $self->{_as_param_} ) {
#    print "already have _as_param_:\n";
#    print "  ", $self->{_as_param_}, "\n";
#    print "   ", unpack('b*', $self->{_as_param_}), "\n";
    return \$self->{_as_param_} 
  }
# Can't use $self->{contents} as FETCH will bork at _datasafe
# use $self->{_raw}{DATA} instead
  $self->{_as_param_} =
    ${$self->{_rawcontents}{DATA}->_as_param_};
  return \$self->{_as_param_};
}

sub _update_ {
  my( $self, $arg ) = @_;
  return undef unless $arg;

  my $success = $self->{_rawcontents}{DATA}->_update_($arg);
  if(!$success) {
    croak($self->{name}, ": Error updating contents!");
  }
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
  if( not Ctypes::is_ctypes_compat($arg) ) {
    if ( $arg =~ /^\d*$/ ) {
croak("Cannot make Pointer to plain scalar; did you mean to say '\$ptr++'?")
    }
  croak("Pointers are to Ctypes compatible objects only")
  }
  $self->{owner}{_as_param_} = undef;
  $self->{owner}{offset} = 0; # makes sense to reset offset
  return $self->{DATA} = $arg;
}

sub FETCH {
  my $self = shift;
  if( defined $self->{owner}{_as_param_}
      and $self->{owner}{_datasafe} == 0 ) {
    my $success = $self->{owner}->_update_($self->{owner}{_as_param_});
    croak($self->{name},": Could not update contents!") if not $success;
  }
  croak("Error! Data not safe!") if $self->{owner}{_datasafe} != 1;
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
  if( ref($arg) ) {
    carp("Only store simple scalar data through subscripted Pointers");
    return undef;
  }

  my $data = $self->{owner}{contents}->_as_param_;
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

  my $insert = pack($self->{owner}{orig_type},$arg);
  if( length($insert) != Ctypes::sizeof($self->{owner}{orig_type}) ) {
    carp("You're about to break something...");
# ??? What would be useful feedback here? Aside from just not doing it..
  }
  substr( $$data,
          $each * $offset,
          Ctypes::sizeof($self->{owner}{orig_type}),
        ) =  $insert;
  $self->{DATA}[$index] = $insert;  # don't think this can be used
  return $insert;
}

sub FETCH {
  my( $self, $index ) = @_;
  my $data = $self->{owner}{contents}->_as_param_;
  my $each = Ctypes::sizeof($self->{owner}{orig_type});

  my $offset = $index + $self->{owner}{offset};
  if( $offset < 0 ) {
    carp("Pointer cannot look back past start of data");
    return undef;
  }
  if( $offset >= length($$data)                  # start at end of data
      or ($offset + $each) > length($$data) ) {  # or will go past it
    carp("Pointer cannot look past end of data");
    return undef;
  }

  my $chunk = substr( $$data,
                      $each * $offset,
                      Ctypes::sizeof($self->{owner}{orig_type})
                    );
  $self->{DATA}[$index] = $chunk;
  return unpack($self->{owner}{orig_type},$chunk);
}

sub FETCHSIZE {
  my $data = $_[0]->{owner}{contents}->_as_param_;
  return length($data);
}

1;
