package Ctypes::Type::Array;
use strict;
use warnings;
use Carp;
use Ctypes;
use Scalar::Util qw|looks_like_number|;
use overload '@{}'    => \&_array_overload,
             '${}'    => \&_scalar_overload,
             fallback => 'TRUE';

=head1 NAME

Ctypes::Type::Array - Taking (some of) the misery out of C arrays!

=head1 SYNOPSIS

  use Ctypes;

  my $array = Array( 1, 3, 5, 7, 9 );

  my $bytes_size = $array->size;         # sizeof(int) * $#array;

  $array->[2] = 4;                       # That's ok.
  my $longnum = INT_MAX() + 1;
  $array->[2] = $longnum;                # Error!

=cut

##########################################
# TYPE::ARRAY : PRIVATE FUNCTIONS & DATA #
##########################################

sub _arg_to_type {
  my( $arg, $type ) = @_;
  $type = $type->{_typecode_} if ref($type); # take typecode or obj
  my $out = undef;
  if( !ref($arg) ) {     # Perl native type
    # new() will handle casting and blow up if inappropriate
    $out =  Ctypes::Type::Simple->new( $type, $arg );
  } 
  # Second simplest case: input is a Type object
  if( ref($arg) eq 'Ctypes::Type::Simple' ) {
    if( $arg->{_typecode_} eq $type ) {
      $out = $arg;
    } else {
      $out = Ctypes::Type::Simple->new( $type, $arg->{val} );
    }
  }
  if( ref($arg) and ref($arg) ne 'Ctypes::Type::Simple') {
  # This is the long shot: some other kind of object.
  # In theory it Should work. TODO: a good test for this!
    my $datum = $arg->{_as_param_} ?
      $arg->{_as_param_} :
      $arg->can("_as_param_") ? $arg->_as_param_ : undef;
    carp("Object typecode differs but, you asked for it...")
      if $arg->{_typecode_} ne $type;
    $out = Ctypes::Type::Simple->new($type,unpack($type,$datum))
        if defined($datum);
  }
  return $out;
}

# Arguments to Array could be Perl natives, Type objects, or
# user-defined types conforming to the 'Ctypes protocol'
# We need to look at the _values_ of all args to see what kind
# of array to make. This function gets all the values out for us.
sub _get_values ($;\@) {
  my $in = shift;
  my $which_kind = shift;
  my @values;
  for(my $i = 0; defined(local $_ = $$in[$i]); $i++) {
    if( !ref ) { 
      $values[$i] = $_;
      $which_kind->[$i] = 1;
    }
    elsif( ref eq 'Ctypes::Type::Simple' ) {
      $values[$i] = $_->{val};
      $which_kind->[$i] = 2;
    }
    else {
      my $invalid = Ctypes::_check_invalid_types( [ $_ ] );
      if( not $invalid ) {
        my $tc = $_->{_typecode_} ?
          $_->{_typecode_} : $_->typecode;
        if( $tc ne 'p' ) {
          $values[$i] = $_->{_as_param_} ?
            $_->{_typecode_} ?
              unpack($_->{_typecode_}, $_->{_as_param_}) :
              unpack($_->_typecode_, $_->{_as_param_}) :
            $_->{_typecode_} ?
              unpack($_->{_typecode_}, $_->_as_param_) :
              unpack($_->_typecode_, $_->_as_param_); 
        } else {
          return -1;
        } 
      $which_kind->[$i] = 3;
      } else {
  carp("Cannot discern value of object at position $invalid");
  return undef;
      }
    }
  }
  return @values;
}

# Scenario A: We've been told what type to make the array
#   Cast all inputs to that type.
sub _get_members_typed {
  my $deftype = shift;
  my $in = shift;
  my $members = [];
  my $newval;
  # A.a) Required type is a Ctypes Type
  if( ref($deftype) eq 'Ctypes::Type::Simple' ) {
    for(my $i = 0; defined(local $_ = $$in[$i]); $i++) {
    $newval = _arg_to_type( $_, $deftype );
    if( defined $newval ) {
      $members->[$i] = $newval;
      } else {
   carp("Array input at $i could not be coaersed to type ",
       $deftype->{name});
       return undef;
      }
    }
  } else {
  # A.b) Required type is a user-defined object (which we've already
  #      checked is 'Ctypes compatible'
  # Since it's a non-type object, we can't do casting (we only know
  # how data comes out [_typecode_, _as_param_], not goes in.
  # Just check they're all the same type, err if not
    for(my $i = 0; $i <= $#$in; $i++) {
      if( ref($$in[$i]) ne $deftype ) {
        carp("Input at $i is not of user-defined type $deftype");
        return undef;
      }
    }
  }
  return $members;
}

# Scenario B: Type not defined. Here come the best guesses!
# First get values of inputs, plus some info...
sub _get_members_untyped {
  my $in = shift;
  my $members = [];

  my( $found_type, $invalid, $found_string) = undef;

  for(my $i=0;defined(local $_ = $$in[$i]);$i++) {
    if( defined $found_type ) {
      if( ref ne $found_type ) {
        carp("Arrays must be all of the same type: "
             . " new type found at position $i");
        return undef;
      } else {
        next;
      }
    }
    if( ref ) {
      if( $i > 0 ) {
        carp("Arrays must be all of the same type: "
           . " new type found at position $i");
        return undef;
      }
      if( ref ne 'Ctypes::Type::Simple' ) {
      $invalid = Ctypes::_check_invalid_types( [ $_ ] );
        if( not $invalid ) {
          $found_type = ref;
        } else {
          carp("Arrays can only store Ctypes compatible objects:"
               . " type " . ref() . " is not valid");
          return undef;
        }
      }
    }
    if( not looks_like_number($_) ) { $found_string = 1 };
  }

  if( $found_type ) {
    return $in;
  }

# Now, check for non-numerics...
  my @numtypes = qw|s i l d|; #  1.short 2.int 3.long 4.double
  if(not $found_string) {
  # Determine smallest type suitable for holding all numbers...
  # XXX This needs changed when we support more typecodes
    my $low = 0;  # index into @numtypes
    for(my $i = 0; defined( local $_ = $$in[$i]); $i++ ) {
      $low = 1 if $_ > Ctypes::constant('PERL_SHORT_MAX') and $low < 1;
      $low = 2 if $_ > Ctypes::constant('PERL_INT_MAX') and $low < 2;
      $low = 3 if $_ > Ctypes::constant('PERL_LONG_MAX') and $low < 3;
      last if $low == 3;
    }
    # Now create type objects for all members...
    for(my $i = 0; defined( local $_ = $$in[$i]); $i++ ) {
      $members->[$i] =
        Ctypes::Type::Simple->new($numtypes[$low], $$in[$i]);
    }
  } else { # $found_string = 1 (got non-numerics)...
    for(my $i = 0; defined( local $_ = $$in[$i]); $i++ ) {
      $members->[$i] =
        Ctypes::Type::Simple->new('p', $$in[$i]);
    }
  }
  return $members;
}

sub _array_overload {
  return shift->{members};
}

sub _scalar_overload {
  return \shift;
}

##########################################
# TYPE::ARRAY : PUBLIC FUNCTIONS & DATA  #
##########################################

sub new {
  my $class = shift;
  my $self = {};
  return undef unless defined($_[0]); # TODO: Uninitialised Arrays? Why??
  # Specified array type in 1st pos, members in arrayref in 2nd
  my( $deftype, $in );
  # Note that since $deftype is a Ctypes::Type object, its presence must
  # be ascertained with defined rather than a simple if( $deftype ) (since
  # it will in many cases be the default 0 and return such in simple checks.
  if( defined($_[0]) and ref($_[1]) eq 'ARRAY' ) {
    $deftype = shift;
    croak("Array type must be specified as Ctypes Type or similar object")
      unless ref($deftype);
    Ctypes::_check_invalid_types( [ $deftype ] );
    $in = shift;
  } else {  # no specification of array type, guess reasonable defaults
    $in = Ctypes::_make_arrayref(@_);
  }

  my $inputs_typed = defined $deftype ?
    _get_members_typed($deftype, $in) :
    _get_members_untyped( $in );

  if( not defined @{$inputs_typed} ) {
    croak("Could not create Array from arguments supplied: see warnings");
  }

  $deftype = $inputs_typed->[0] if not defined $deftype;

  $self = { type        => $deftype,
            name        => $deftype->{name} . ' Array',
            _typecode_  => 'p',
            size        => $deftype->{size} * ($#$in + 1),
            can_resize  => 1,
            endianness  => '',
            _as_param_  => '',
            'length'    => $#$in,
            _datasafe   => 1,
          };

  bless $self => $class;

  $self->{_rawmembers} =
    tie @{$self->{members}}, 'Ctypes::Type::Array::members', $self;
  my @arr =  @{$inputs_typed};
  @{$self->{members}} = @arr;
  return $self;
}

#
# Accessor generation
#
my %access = (
  'length'          => ['length'],
  typecode          => ['_typecode_'],
  can_resize =>
    [ 'can_resize',
      sub {if( $_[0] != 1 and $_[0] != 0){return 0;}else{return 1;} },
      1 ], # <--- this makes 'flexible' settable
  alignment         => ['alignment'],
  type              => ['type'],
  size              => ['size'],
  endianness        => ['_endianness'],
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

sub _data { &_as_param_(@_); }

sub _as_param_ {
  my $self = shift;
  # STORE will always undef _as_param_
  $self->{_datasafe} = 0; # used by FETCH
  return $self->{_as_param_} if defined $self->{_as_param_};
# TODO This is where a check for an endianness property would come in.
  if( $self->{endianness} ne 'b' ) {
    my @data;
    for(my $i=0;defined(local $_ = $self->{_rawmembers}{DATA}[$i]);$i++) {
      $data[$i] = $_->{_as_param_} ?
        $_->{_as_param_} :
        ${$_->_as_param_};
    }
    my $string;
    for(@data) { $string .= $_ }
    $self->{_as_param_} = join('',@data);
    return \$self->{_as_param_};
  } else {
  # <insert code for other / swapped endianness here>
  }
}

sub _update_ {
  my($self, $arg) = @_;
  return undef unless $arg;

  my $num_members = scalar @{$self->{_rawmembers}{DATA}};
  my $chunk_size = length($self->{_as_param_}) / $num_members;
  my @renew;
  my $temp;
  for( 0..$num_members-1 ) {
    $renew[$_] = substr( $self->{_as_param_},
                         ($_ * $chunk_size),
                         $chunk_size
                       );
  }
  my $success;
  for(my $i=0;defined(local $_=$renew[$i]);$i++) {
    $success = $self->{_rawmembers}{DATA}[$i]->_update_($renew[$i]);
    if(!$success) {
      croak("Error updating member at position $i");
    }
  }
  $self->{_datasafe} = 1;
  return 1;
}

package Ctypes::Type::Array::members;
use strict;
use warnings;
use Carp;
use Ctypes::Type::Array;
use Tie::Array;

# our @ISA = ('Tie::StdArray');

sub TIEARRAY {
  my $class = shift;
  my $owner = shift;
  my $self = { owner    => $owner,
               DATA     => [],
             };
  return bless $self => $class;
}

sub STORE {
  my( $self, $index, $arg ) = @_;
  # Deal with being assigned other Type objects and the like...

  if( $index > $#{$self->{DATA}} and $self->{owner}{can_resize} = 0 ) {
    carp("Max index ", $#$self,"; not allowed to resize!");
    return undef;
  }

  my $val;
  if( !ref($arg) ) {
    $val = Ctypes::Type::Array::_arg_to_type($arg,$self->{owner}{type});
    if( not defined $val ) {
      carp("Could not create " . $self->{owner}{name}
           . " type from argument '$arg'");
      return undef;
    }
  } else {
    $val = $arg;
  }

  if( ref($val) eq 'ARRAY' ) {
    $val = new Ctypes::Type::Array( $val );
  }

  if( $val->{_typecode_} ne $self->{owner}{type}{_typecode_} ) {
    carp( "Cannot put " . ref($val) . " type object into "
          . ref($self->{owner}{type}) . " Array");
    return undef;
  }

# XXX Simple types pack() every time they're assigned to.
# That's hassle. How about only producing the pack()'d data when
# asked for it? Can then cache it in _as_param_.

  # This check is because FETCH must repopulate $self if _as_param_ exists
  # (since it may have been manipulated by a C lib)
  if( caller ne 'Ctypes::Type::Array::members' ) {
    $self->{owner}{_as_param_} = undef;  # cache no longer up to date
  }
  $self->{DATA}[$index] = $val;
  return $self->{DATA}[$index]; # success
}

sub FETCH {
  my($self, $index) = @_;
  if( defined $self->{owner}{_as_param_}
      and $self->{owner}{_datasafe} == 0 ) {
    $self->{owner}->_update_($self->{owner}{_as_param_});
  }
  croak("Error updating values!") if $self->{owner}{_datasafe} != 1;
  if( ref($self->{DATA}[$index]) eq 'Ctypes::Type::Simple' ) {
    return ${$self->{DATA}[$index]};
#  } elsif ( ref($$self[$index]) eq 'Ctypes::Type::Array' ) {
#    return @{$$self[$index]};
  } else {
    return $self->{DATA}[$index];
  }
}

sub CLEAR { $_[0]->{DATA} = [] }
sub EXTEND { }
sub FETCHSIZE { scalar @{$_[0]->{DATA}} }

1;
