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
my $Debug;

=head1 NAME

Ctypes::Type::Array - Taking (some of) the misery out of C arrays!

=head1 SYNOPSIS

  use Ctypes;

  my $array = Array( 1, 3, 5, 7, 9 );    # Array of smallest type
                                         # necessary (ushort)

  my $bytes_size = $array->size;         # sizeof(int) * $#array;

  $array->[2] = 4;
  $$array[3] = 10;

  my $num_items = scalar @$array;

=head1 ABSTRACT

This class represents C arrays. Like in C, Arrays are typed,
and can only contain data of that type. Arrays use the double-
syntax of other Ctypes classes, in this case the Perl array
sigil 'C<@>'

=cut

############################################
# TYPE::ARRAY : PRIVATE FUNCTIONS & VALUES #
############################################

sub _arg_to_type {
  my( $arg, $type ) = @_;
  croak("_arg_to_type error: need typecode!") if not defined $type;
  $type = $type->{_typecode} if ref($type); # take typecode or obj
  my $out = undef;
  if( !ref($arg) ) {     # Perl native type
    # new() will handle casting and blow up if inappropriate
    $out =  Ctypes::Type::Simple->new( $type, $arg );
  }
  # Second simplest case: input is a Type object
  if( ref($arg) eq 'Ctypes::Type::Simple' ) {
    if( $arg->{_typecode} eq $type ) {
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
      if $arg->{_typecode} ne $type;
    $out = Ctypes::Type::Simple->new($type,unpack($type,$datum))
        if defined($datum);
  }
  return $out;
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
  # how data comes out [_typecode, _as_param_], not goes in.
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

# Scenario B: Type not defined, try best guesses.
# First get values of inputs, plus some info...
sub _get_members_untyped {
  my $in = shift;
  my( $found_type, $invalid, $found_string);

  for(my $i=0; defined(local $_ = $$in[$i]); $i++) {
    if( defined $found_type ) {
      my $ref = ref $_;
      if( $ref ne $found_type ) {
        carp("Array elements must be all of the same type: "
             . " new type $ref at $i different to $found_type.");
        return undef;
      } else {
        next;
      }
    }
    if( ref $_ ) {
      my $ref = ref $_;
      if ( $i > 0 ) {
        carp("Array elements must be all of the same type: "
           . " new type $ref at $i different to undef.");
        return undef;
      }
      if( $ref ne 'Ctypes::Type::Simple' ) {
        $invalid = Ctypes::_check_invalid_types( [ $_ ] );
        if( not $invalid ) {
          $found_type = $ref;
        } else {
          carp("Arrays can only store Ctypes compatible objects:"
               . " type $ref is not valid");
          return undef;
        }
      }
      $found_type = $ref;
    }
    #if( not looks_like_number($_) ) { $found_string = 1 }; # XXX checked in _check_type_needed
  }

  if( $found_type ) {
    return $in;
  }

  my $members = [];
  # Now, check for non-numerics...
  my $lcd = Ctypes::_check_type_needed(@$in);   # 'lowest common denomenator'
  croak "no lcd of @$in" unless $lcd;
  # Now create type objects for all members...
  for(my $i = 0; defined($$in[$i]); $i++ ) {
    $members->[$i] =
      Ctypes::Type::Simple->new($lcd, $$in[$i]);
    croak "lcd=$lcd: no type for $$in[$i] at index $i" unless $members->[$i];
  }
  return $members;
}

sub _array_overload {
  return shift->{_members};
}

sub _scalar_overload {
  return \shift;
}

###########################################
# TYPE::ARRAY : PUBLIC FUNCTIONS & VALUES #
###########################################

=head1 METHODS

Array object provide the following methods (remember, methods are called
on the object with B<one> sigil, and you access the 'contained' in the
object with the two-sigil syntax).

=over

=item new TYPE, ARRAYREF

=item new LIST

Since L<Ctypes> exports the handy Array() function, you'll hardly ever use
Ctypes::Type::Array::new directly. Arrays can be instantiated either by
passing a Ctypes type as the first argument and an arrayref of values as
the second, or simply by passing a list of values. In the latter case,
Ctypes will use the smallest C type necessary for the arguments provided.

=cut

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
  my $name = $deftype->name;
  $name =~ s/^c_//;

  my $self = $class->_new( {
    _name         => lc($name) . '_Array',
    _typecode     => 'p',
    _can_resize   => 0,
    _endianness   => '',
    _length       => $#$in + 1,
    _member_type  => $deftype->typecode,
    _member_size  => $deftype->size,
  } );
  $self->{_name} =~ s/::/_/g;
  $self->{_size} = $deftype->size * ($#$in + 1);
  $self->{_rawmembers} =
    tie @{$self->{_members}}, 'Ctypes::Type::Array::members', $self;
  @{$self->{_members}} =  @{$inputs_typed};
  return $self;
}

=item can_resize 1 I<or> 0

Get/setter for the property flagging whether or not the Array is
allowed to expand. Defaults to 0. Unlike in C, you can't read off
the end of an Array object into random memory.

=item member_type

Invoking the standard L<Type|Ctypes::Type> method C<typecode> on
an Array will always return 'p', the typecode for the Array itself.
Use the member_type method to find out the typecode of the items
the Array holds.

=item member_size

A similar story to C<member_type>: C<$array->size> will always give
you the size of the whole array, i.e. sizeof(<member_type>) * number
of members. You can use C<member_size> to return the size each of
the items the Array holds (or is typed to hold).

=item length

A convenience method returning the number of items in the array
(simply another, less sigiltastic way of saying C<$#$array + 1>).

=cut

#
# Accessor generation
#
my %access = (
  'length'          => ['_length'],
  can_resize        =>
    [ '_can_resize',
      sub {if( $_[0] != 1 and $_[0] != 0){return 0;}else{return 1;} },
      1 ], # <--- this makes '_can_resize' settable
  member_type       => ['_member_type'],
  member_size       => ['_member_size'],
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

=item copy

Return a copy of the object.

=cut

sub copy {
  my $self = shift;
  my @arr;
  for( 0..$#$self ) {
    $arr[$_] = $self->{_rawmembers}->{VALUES}->[$_];
  }
  return new Ctypes::Type::Array( @arr );
}

sub data {
  my $self = shift;
  print "In ", $self->{_name}, "'s _DATA(), from ", join(", ",(caller(1))[0..3]), "\n" if $Debug;
if( defined $self->{_data}
      and $self->_datasafe == 1 ) {
    print "    _data already defined and safe\n" if $Debug;
    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug;
    return \$self->{_data};
  }
# TODO This is where a check for an endianness property would come in.
  if( $self->{_endianness} ne 'b' ) {
    my @data;
    for(my $i=0;defined(local $_ = $self->{_rawmembers}{VALUES}[$i]);$i++) {
      $data[$i] = # $_->{_data} ?
  #      $_->{_data} :
        ${$_->_as_param_};
    }
    $self->{_data} = join('',@data);
    print "  ", $self->{_name}, "'s _data returning ok...\n" if $Debug;
    $self->_datasafe(0);
    return \$self->{_data};
  } else {
  # <insert code for other / swapped endianness here>
  }
}

=item scalar

Returns the number of elements in the Array (not the highest index),
in the same way as C<scalar @myarray>. Useful for when Arrays are
nested inside other objects, so you don't have to call scalar then put
dereferencing @{} braces around the whole thing.

=cut

sub scalar { return scalar @{ $_[0]->{_members} } }

=back

=head1 SEE ALSO

L<Ctypes::Type::Pointer>
L<Ctypes::Type::Struct>
L<Ctypes>

=cut

sub _as_param_ { return $_[0]->data(@_) }

sub _update_ {
  my($self, $arg, $index) = @_;
  print "In ", $self->{_name}, "'s _UPDATE_, from ", join(", ",(caller(0))[0..3]), "\n" if $Debug;
  print "  self is: ", $self, "\n" if $Debug;
  print "  current data looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug;
  print "  arg is: $arg\n" if $arg and $Debug;
  print "  which is\n", unpack('b*',$arg), "\n  to you and me\n" if $arg and $Debug;
  print "  and index is: $index\n" if $index and $Debug;
  if( not defined $arg ) {
    if( $self->{_owner} ) {
    $self->{_data} = substr( ${$self->{_owner}->data},
                             $self->{_index},
                             $self->{_size} );
    }
  } else {
    if( $index ) {
      my $pad = $index + length($arg) - length($self->{_data});
      if( $pad > 0 ) {
        $self->{_data} .= "\0" x $pad;
      }
      print "  Putting arg where I think it should go...\n" if $Debug;
      substr( $self->{_data},
              $index,
              length($arg)
            ) = $arg;
      print "  In ", $self->name, ", data NOW looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug;
    } else {
      $self->{_data} = $arg; # if data given with no index, replaces all
  print "  In ", $self->name, ", data NOW looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug;
    }
  }

  # Have to send all data upstream even if only 1 member updated
  # ... or do we? Send our _index, plus #bytes updated member starts at?
  # Could C::B::C help with this???
  if( defined $arg and $self->{_owner} ) {
  my $success = undef;
  print "  Sending data back upstream:\n" if $arg and $Debug;
  print "    Index is ", $self->{_index}, "\n" if $arg and $Debug;
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
  $self->_datasafe(1);
  print "BLARG: ", $self->{_rawmembers}, "\n" if $Debug;
  for(@{$self->{_rawmembers}->{VALUES}}) {
    print "    Telling $_ it's not safe\n" if $Debug;
    $_->_datasafe(0);
  }
  print "  In ", $self->name, ", data NOW looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug;
  print "    ", $self->{_name}, "'s _Update_ returning ok\n" if $Debug;
  return 1;
}

sub _datasafe {
  my( $self, $arg ) = @_;
  if( defined $arg and $arg != 1 and $arg != 0 ) {
    croak("Usage: ->_datasafe(1 or 0)")
  }
  if( defined $arg and $arg == 0 ) {
    for(@{$self->{_rawmembers}{VALUES}}) { $_->_datasafe(0) }
  }
  $self->{_datasafe} = $arg if defined $arg;
  return $self->{_datasafe};
}

package Ctypes::Type::Array::members;
use strict;
use warnings;
use Carp;
use Ctypes::Type::Array;

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
  print "In ", $self->{object}{_name}, "'s STORE, from ", join(", ",(caller(1))[0..3]), "\n" if $Debug;

  if( $index > ($self->{object}{_length} - 1)
      and $self->{object}{_can_resize} = 0 ) {
    croak("Max index ", $#$self,"; not allowed to resize!");
    return undef;
  }

  my $val;
  if( !ref($arg) ) {
    $val = Ctypes::Type::Array::_arg_to_type($arg,$self->{object}{_member_type});
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

  if( $val->typecode =~ /p/ ) {  # might add other pointer types...
    if ( ref($self->{VALUES}[0])   # might be first obj added
         and ref($val) ne ref($self->{VALUES}[0]) ) {
    carp( "Cannot put " . ref($val) . " type object into "
          . $self->{object}{_name} );
    return undef;
    }
  } elsif( $val->typecode ne $self->{object}{_member_type} ) {
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
  my $datum = ${$val->data}; # BEFORE setting owner, that's important!
  print "    Arg is ", $val, " / ", ref($val), " / ", ref($val) ? $val->name : '', " / ", ${$val}, "\n" if $Debug;
  print "    ", __PACKAGE__ . ":" . __LINE__, ": In data form, that's\n",unpack('b*',$datum),"\n" if $Debug;
  $self->{VALUES}[$index]->{_owner} = $self->{object};
  $self->{VALUES}[$index]->{_index}
    = $index * $self->{object}->{_member_size};
  print "    Setting {VALUES}[$index] to $val\n" if $Debug;
  $self->{VALUES}[$index] = $val;
  $self->{VALUES}[$index]->{_owner} = $self->{object};
  $self->{VALUES}[$index]->{_index} = $index * $self->{object}->{_member_size};

# XXX Found this while working on Struct, think it's suspect. Sadly,
# tests still pass without it. Doesn't say much for the regime :(
#  if( $self->{object}{_owner} ) {
#    $self->{object}{_owner}->_update_($arg, $self->{_owner}{_index});
#  }
  $self->{object}->_update_($datum, $index * $self->{object}{_member_size});

  return $self->{VALUES}[$index]; # success
}

sub FETCH {
  my($self, $index) = @_;
  print "In ", $self->{object}{_name}, "'s FETCH, looking for [ $index ], called from ", join(", ",(caller(1))[0..3]), "\n" if $Debug;
  if( defined $self->{object}{_owner}
      or $self->{object}{_datasafe} == 0 ) {
    print "    Can't trust data, updating...\n" if $Debug;
    $self->{object}->_update_; # Don't need to update member we're FETCHing;
                               # it will pull from us, because we _owner it
  }
  croak("Error updating values!") if $self->{object}{_datasafe} != 1;
  if( ref($self->{VALUES}[$index]) eq 'Ctypes::Type::Simple' ) {
  print "    ", $self->{object}{_name}, "'s FETCH[ $index ] returning ", $self->{VALUES}[$index], "\n" if $Debug;
  carp "    ", $self->{object}{_name}, "\n" if $Debug;
  carp "    ", $self->{VALUES}[$index], "\n" if $Debug;
    return ${$self->{VALUES}[$index]};
  } else {
    print "    ", $self->{object}{_name}, "'s FETCH[ $index ] returning ", $self->{VALUES}[$index], "\n" if $Debug;
    print "\n" if $Debug;
    return $self->{VALUES}[$index];
  }
}

sub CLEAR { $_[0]->{VALUES} = [] }
sub EXISTS { exists $_[0]->{VALUES}->[$_[1]] }
sub EXTEND { }
sub FETCHSIZE { scalar @{$_[0]->{VALUES}} }

1;
__END__
