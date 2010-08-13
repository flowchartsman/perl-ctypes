package Ctypes::Type::Array;
use strict;
use warnings;
use Carp;
use Ctypes;
use Scalar::Util qw|looks_like_number|;
use overload '@{}'    => \&_array_overload,
             '${}'    => \&_scalar_overload,
             fallback => 'TRUE';

our @ISA = qw|Ctypes::Type|;
my $Debug = 0;

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
# TYPE::ARRAY : PRIVATE FUNCTIONS & VALUES #
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
    my $datum = $arg->{_data} ?
      $arg->{_data} :
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
          $values[$i] = $_->{_data} ?
            $_->{_typecode_} ?
              unpack($_->{_typecode_}, $_->{_data}) :
              unpack($_->_typecode_, $_->{_data}) :
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
# TYPE::ARRAY : PUBLIC FUNCTIONS & VALUES  #
##########################################

sub new {
  my $class = ref($_[0]) || $_[0]; shift;
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

  my $self = $class->SUPER::_new;
  my $attrs = {
    _name         => ref($deftype) . '_Array',
    _typecode_    => 'p',
    _can_resize   => 0,
    _endianness   => '',
    _length       => $#$in + 1,
    _member_type  => $deftype->_typecode_,
    _member_size  => $deftype->size,
               };
  for(keys(%{$attrs})) { $self->{$_} = $attrs->{$_}; };
  bless $self => $class;
  $self->{_name} =~ s/::/_/g;
  $self->{_size} = $deftype->size * ($#$in + 1);
  $self->{_rawmembers} =
    tie @{$self->{members}}, 'Ctypes::Type::Array::members', $self;
  @{$self->{members}} =  @{$inputs_typed};
  return $self;
}

#
# Accessor generation
#
my %access = (
  'length'          => ['_length'],
  _typecode_        => ['_typecode_'],
  can_resize        =>
    [ '_can_resize',
      sub {if( $_[0] != 1 and $_[0] != 0){return 0;}else{return 1;} },
      1 ], # <--- this makes 'flexible' settable
  alignment         => ['_alignment'],
  name              => ['_name'],
  member_type       => ['_member_type'],
  member_size       => ['_member_size'],
  size              => ['_size'],
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

sub _data { 
  my $self = shift;
  print "In ", $self->{_name}, "'s _DATA(), from ", join(", ",(caller(1))[0..3]), "\n" if $Debug == 1;
if( defined $self->{_data}
      and $self->{_datasafe} == 1 ) {
    print "    _data already defined and safe\n" if $Debug == 1;
    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
    return \$self->{_data};
  }
#  if( defined $self->{_data} ) {
#    print "    asparam already defined\n" if $Debug == 1;
#    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
#    return \$self->{_data};
#  }
# TODO This is where a check for an endianness property would come in.
  if( $self->{_endianness} ne 'b' ) {
    my @data;
    for(my $i=0;defined(local $_ = $self->{_rawmembers}{VALUES}[$i]);$i++) {
      $data[$i] = # $_->{_data} ?
  #      $_->{_data} :
        ${$_->_as_param_};
    }
    my $string;
    for(@data) { $string .= $_ }
    $self->{_data} = join('',@data);
    print "  ", $self->{_name}, "'s _data returning ok...\n" if $Debug == 1;
    $self->{_datasafe} = 0;
    for(@{$self->{_rawmembers}{VALUES}}) { $_->{_datasafe} = 0 }
    return \$self->{_data};
  } else {
  # <insert code for other / swapped endianness here>
  }
}

sub _as_param_ { return $_[0]->_data(@_) }

sub _update_ {
  my($self, $arg, $index) = @_;
  print "In ", $self->{_name}, "'s _UPDATE_, from ", join(", ",(caller(0))[0..3]), "\n" if $Debug == 1;
  print "  self is: ", $self, "\n" if $Debug == 1;
  print "  current data looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
  print "  arg is: $arg\n" if $arg and $Debug == 1;
  print "  which is\n", unpack('b*',$arg), "\n  to you and me\n" if $arg and $Debug == 1;
  print "  and index is: $index\n" if $index and $Debug == 1;
  if( not defined $arg ) {
    if( $self->{_owner} ) {
    $self->{_data} = substr( ${$self->{_owner}->_data},
                             $self->{_index},
                             $self->{_size} );
    #  $self->{_data} = $self->{_owner}->_fetch_data($self->{_index});
    }
  } else {
    if( $index ) {
      my $pad = $index + length($arg) - length($self->{_data});
      if( $pad > 0 ) {
        $self->{_data} .= "\0" x $pad;
      }
      substr( $self->{_data},
              $index,
              length($arg)
            ) = $arg;
    } else {
      $self->{_data} = $arg; # if data given with no index, replaces all
    }
  }

  # Have to send all data upstream even if only 1 member updated
  # ... or do we? Send our _index, plus #bytes updated member starts at?
  # Could C::B::C help with this???
  if( defined $arg and $self->{_owner} ) {
  my $success = undef;
  print "  Sending data back upstream:\n" if $arg and $Debug == 1;
  print "    Index is ", $self->{_index}, "\n" if $arg and $Debug == 1;
    $success =
      $self->{_owner}->_update_(
        $self->{_data},
        $self->{_index}
      );
    if(!$success) {
      croak($self->{_name},
            ": Error updating member in owner object ",
              $self->{_owner}->{_name});
    }
  }
  $self->{_datasafe} = 1;
  for(@{$self->{_rawmembers}{VALUES}}) { $_->{_datasafe} = 0 }
  print "  data NOW looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
  print "    ", $self->{_name}, "'s _Update_ returning ok\n" if $Debug == 1;
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
  my $object = shift;
  my $self = { object   => $object,
               VALUES     => [],
             };
  return bless $self => $class;
}

sub STORE {
  my( $self, $index, $arg ) = @_;

  if( $index > ($self->{object}{_length} - 1)
      and $self->{object}{_can_resize} = 0 ) {
    carp("Max index ", $#$self,"; not allowed to resize!");
    return undef;
  }

  my $val;
  if( !ref($arg) ) {
    $val = Ctypes::Type::Array::_arg_to_type($arg,$self->{object}{_type});
    if( not defined $val ) {
      carp("Could not create " . $self->{object}{_name}
           . " type from argument '$arg'");
      return undef;
    }
    $val->{_needsfree} = 1;
  } else {
  # Deal with being assigned other Type objects and the like...
    $val = $arg;
  }

  if( ref($val) eq 'ARRAY' ) {
    $val = new Ctypes::Type::Array( $val );
  }

  if( $val->_typecode_ =~ /p/ ) {  # might add other pointer types...
    if ( ref($self->{VALUES}[0])   # might be first obj added
         and ref($val) ne ref($self->{VALUES}[0]) ) {
    carp( "Cannot put " . ref($val) . " type object into "
          . $self->{object}{_name} );
    return undef;
    }
  } elsif( $val->_typecode_ ne $self->{object}{_member_type} ) {
    carp( "Cannot put " . ref($val) . " type object into "
          . $self->{object}{_name} );
    return undef;
  }

  if( $self->{VALUES}[$index] ) {
    $self->{VALUES}[$index]->{_owner} = undef;
#    if( $self->{VALUES}[$index]{_needsfree} == 1 )  # If this were C (or
# if it were someday being translated to C), I think this might be where
# one would make use of the disappearing object's _needsfree attribute.
  }
  print "    Setting {VALUES}[$index] to $val\n" if $Debug == 1;
  $self->{VALUES}[$index] = $val;
  $self->{VALUES}[$index]->{_owner} = $self->{object};
  $self->{VALUES}[$index]->{_index}
    = $index * $self->{object}->{_member_size};
  my $datum = ${$val->_data};
  print "    In data form, that's $datum\n" if $Debug == 1;
  if( $self->{object}{_owner} ) {
    $self->{object}{_owner}->_update_($arg, $self->{_owner}{_index});
  }
  $self->{object}->_update_($datum, $index * $self->{object}{_member_size});
  
  return $self->{VALUES}[$index]; # success
}

sub FETCH {
  my($self, $index) = @_;
  print "In ", $self->{object}{_name}, "'s FETCH, looking for [ $index ], called from ", (caller(1))[0..3], "\n" if $Debug == 1;
  if( defined $self->{object}{_owner}
      or $self->{object}{_datasafe} == 0 ) {
    print "    Can't trust data, updating...\n" if $Debug == 1;
    $self->{object}->_update_;
#    $self->{object}{_owner}->_fetch_data($self->{object}{_index});
  }
  croak("Error updating values!") if $self->{object}{_datasafe} != 1;
  if( ref($self->{VALUES}[$index]) eq 'Ctypes::Type::Simple' ) {
  print "    ", $self->{object}{_name}, "'s FETCH[ $index ] returning ", $self->{VALUES}[$index]->{_rawvalue}->{DATA}, "\n" if $Debug == 1;
    return ${$self->{VALUES}[$index]};
#  } elsif ( ref($$self[$index]) eq 'Ctypes::Type::Array' ) {
#    return @{$$self[$index]};
  } else {
    print "    ", $self->{object}{_name}, "'s FETCH[ $index ] returning ", $self->{VALUES}[$index], "\n" if $Debug == 1;
    print "\n" if $Debug == 1;
    return $self->{VALUES}[$index];
  }
}

sub CLEAR { $_[0]->{VALUES} = [] }
sub EXTEND { }
sub FETCHSIZE { scalar @{$_[0]->{VALUES}} }

1;
