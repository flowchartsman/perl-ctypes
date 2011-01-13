package Ctypes::Type::Struct;
use strict;
use warnings;
use Scalar::Util qw|blessed looks_like_number|;
use Ctypes;
use Ctypes::Type::Field;
use Carp;
use Data::Dumper;
use overload
  '${}'    => \&_scalar_overload,
  '%{}'    => \&_hash_overload,
  '@{}'    => \&_array_overload,
  fallback => 'TRUE';

our @ISA = qw|Ctypes::Type|;
my $Debug = 0;

=head1 NAME

Ctypes::Type::Struct - C Structures

=head1 SYNOPSIS

  use Ctypes;

  my

=head1 ABSTRACT

=cut

sub _process_fields {
  my $self = shift;
  my $fields = shift;
  if( ref($fields) ne 'ARRAY' ) {
    croak( 'Usage: $struct->_process_fields( ARRAYREF )' );
  }
  if( scalar @$fields % 2 ) {
    croak( "Fields must be given as key => value pairs!" );
  }
  my( $key, $val );
  for( 0 .. (( $#$fields - 1 ) / 2) ) {
    $key = shift @{$fields};
    $val = shift @{$fields};
    if( not exists $self->{_fields}->{_hash}->{$key} ) {
      $self->{_fields}->_add_field($key, $val);
    } else {
      $self->{_fields}->{_hash}->{$key}->{_contents} = $val;
    }
  }
}

sub _array_overload {
  return \@{ $_[0]->{_values}->{_array} };
}

sub _hash_overload {
  if( caller =~ /^Ctypes::Type/ ) {
    return $_[0];
  }
  print "Structs's HASH ovld\n" if $Debug;
  my( $self, $key ) = ( shift, shift );
  my $class = ref($self);
  bless $self => 'overload::dummy';
  my $ret = $self->{_values}->{_hash};
  bless $self => $class;
  return $ret;
}

sub _scalar_overload {
  return \$_[0]->{_values};
}

############################################
# TYPE::STRUCT : PUBLIC FUNCTIONS & VALUES #
############################################

=head1 METHODS

Structs expose the following methods in addition to those provided
by Ctypes::Type.

=over

=item new ARRAYREF

=item new HASHREF

Creates and returns a new Struct object. Structs must be initialised
using either an array reference or hash reference (since methods to add
and remove fields after initialisation are currently NYI).

The arrayref syntax is the simpler of the two, suitable for simple
initialisations where the default alignment and endianness is acceptable.

    my $s = Struct([
                     field1 => c_int(10),
                     field2 => c_char('B'),
                     field3 => c_double(999999999999999999),
                   ]);

You might wonder why the hashref form doesn't look like this. The reason
is that we need the hashref form for specifying specific attributes of
the Struct, like C<align> and C<endianness (NYI)>, which would of course
cause problems if you wanted to make a Struct with a field called 'align'.
So with the arrayref syntax, we make use of the fact that Perl's C<=E<gt>>
operator is mostly just a synonym for the comma operator to pass a simple
list of arguments which looks like named key-value pairs to the human
reader.

The hashref syntax currently supports only two named attributes:

=over

=item C<fields>, an arrayref of fieldname-value pairs like the arrayref
syntax above.

=item C<align>, a number indicating the alignment of the struct. Valid
alignments are 0, 1, 2, 4, 8, 16, 32 or 64. The default alignment is 1
(trading processor cycles for saved space). An alignment of 0 is the same
as 1. Note that defining alignment for individual members or sections of
Structs is not yet implemented.

=back

=cut

sub new {
  my $class = ref($_[0]) || $_[0];  shift;
  print "In Struct::new constructor...\n" if $Debug;
  print "    args:\n" if $Debug;
  # Try to determine if ::new was called by a class that inherits
  # from Struct, and get the name of that class
  # XXX Later, the [non-]existence of $progeny is used to make an
  # educated guess at whether Struct was instantiated directly, or
  # via a subclass.
  # Q: What are some of the ways the following logic fails?
  my( $progeny, $extra_fields ) = undef;
  my $caller = caller;
  print "    caller is ", $caller, "\n" if $caller and $Debug;
  if( $caller->isa('Ctypes::Type::Struct') ) {
    no strict 'refs';
    $progeny = $caller;
    if( defined ${"${caller}::_fields_"} ) {
      my $_fields_ = ${"${caller}::_fields_"};
      for( 0..$#$_fields_ ) {
      # Can't just set = as shift() extra_fields later affects every instance
        if( blessed( $_fields_->[$_] )
            and $_fields_->[$_]->isa('Ctypes::Type') ) {
          $extra_fields->[$_] = $_fields_->[$_]->copy;
        } else {
          $extra_fields->[$_] = $_fields_->[$_];
        }
      }
      print "    Got these extra fields:\n" if $Debug;
      print Dumper( $extra_fields ) if $Debug;
      if( scalar @$extra_fields % 2 ) {
        croak( "_fields_ must be key => value pairs!" );
      }
    }
  }

  # Get fields, populate with named/unnamed args
  my $self = {
               _fields     => undef,
               _values     => undef,
               _typecode_  => 'p',
               _subclass   => $progeny,
               _alignment  => 0,
               _data       => '', };
  $self->{_fields} = new Ctypes::Type::Struct::_Fields($self);
  $self->{_values} = new Ctypes::Type::Struct::_Values($self);
  bless $self => $class;
  my $base = $class->SUPER::_new;
  for( keys(%$base) ) {
    $self->{$_} = $base->{$_};
  }
  $self->{_name} = $progeny ? $progeny . '_Struct' : 'Struct';
  $self->{_name} =~ s/.*:://;

  if( $extra_fields ) {
    my( $key, $val );
    for( 0 .. (( $#$extra_fields - 1 ) / 2) ) {
      $key = shift @{$extra_fields};
      $val = shift @{$extra_fields};
      print "    Adding extra field '$key'...\n" if $Debug;
      $self->{_fields}->_add_field( $key, $val );
    }
  }

  my $in = undef;
  if( ref($_[0]) eq 'HASH' ) {
    $in = shift;
    if( exists $in->{align} ) {
      if( $in->{align} !~ /^2$|^4$|^8$|^16$|^32$|^64$/ ) {
        croak( '\'align\' parameter must be 2, 4, 8, 16, 32 or 64' );
      }
      $self->{_alignment} = $in->{align};
      print "    My alignment is now ", $self->{_alignment}, "\n" if $Debug;
      delete $in->{align};
    }
    if( exists $in->{fields} ) {
      $self->_process_fields($in->{fields});
      delete $in->{fields};
    }
  } elsif( ref($_[0]) eq 'ARRAY' ) {
    $in = shift;
    $self->_process_fields($in);
  } else {
    if( ( !$progeny
          or scalar @{$self->{_fields}} == 0 )
        and defined $_[0] ) {
      croak( "Don't know what to do with args without fields" );
    }
    for( 0 .. $#{$self->{_fields}->{_array}} ) {
      my $arg = shift;
      print "  Assigning $arg to ", $_, "\n" if $Debug;
      $self->{_values}->[$_] = $arg;
    }
  }

  print "    Struct constructor returning\n" if $Debug;
  return $self;
}

sub _as_param_ { return $_[0]->data(@_) }

=item copy

Return a copy of the Struct object.

=cut

sub copy {
  my $self = shift;
}

sub data {
  my $self = shift;
  print "In ", $self->{_name}, "'s _DATA(), from ", join(", ",(caller(1))[0..3]), "\n" if $Debug;
  my @data;
  if( defined $self->{_data}
      and $self->{_datasafe} == 1 ) {
    print "    _data already defined and safe\n" if $Debug;
    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug;
    return \$self->{_data};
  }
# TODO This is where a check for an endianness property would come in.
#  if( $self->{_endianness} ne 'b' ) {
    for(@{$self->{_fields}->{_rawarray}}) {
      push @data, $_->{_data};
    }
    $self->{_data} = join('',@data);
    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug;
    print "  ", $self->{_name}, "'s _data returning ok...\n" if $Debug;
    $self->_datasafe(0);
    return \$self->{_data};
#  } else {
  # <insert code for other / swapped endianness here>
#  }
}

sub _update_ {
  my($self, $arg, $index) = @_;
  print "In ", $self->{_name}, "'s _UPDATE_, from ", join(", ",(caller(0))[0..3]), "\n" if $Debug;
  print "  self is: ", $self, "\n" if $Debug;
  print "  current data looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug;
  print "  arg is: $arg" if $arg and $Debug;
  print $arg ? (",  which is\n", unpack('b*',$arg), "\n  to you and me\n") : ('') if $Debug;
  print "  and index is: $index\n" if defined $index and $Debug;
  if( not defined $arg ) {
    print "    Arg wasn't defined!\n" if $Debug;
    if( $self->{_owner} ) {
    print "      Getting data from owner...\n" if $Debug;
    $self->{_data} = substr( ${$self->{_owner}->data},
                             $self->{_index},
                             $self->{_size} );
    }
  } else {
    if( defined $index ) {
      print "     Got an index...\n" if $Debug;
      my $pad = $index + length($arg) - length($self->{_data});
      if( $pad > 0 ) {
        print "    pad was $pad\n" if $Debug;
        $self->{_data} .= "\0" x $pad;
      }
      print "    Setting chunk of self->data\n" if $Debug;
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
    print "    Need to update my owner...\n" if $Debug;
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
  $self->{_datasafe} = 1;
  if( defined $arg or $self->{_owner} ) { # otherwise nothing's changed
    $self->_set_owned_unsafe;
  }
  print "  data NOW looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug;
  print "    updating size...\n" if $Debug;
  $self->{_size} = length($self->{_data});
  print "    ", $self->{_name}, "'s _Update_ returning ok\n" if $Debug;
  return 1;
}

sub _valid_align {

}

# XXX partial alignment NYI

=item align

Returns or sets the alignment for the Struct. Valid alignments are
2, 4, 8, 16, 32 or 64. Setting alignment for individual members /
areas of the struct is not yet implemented.

=item fields

Returns an object used to access information B<about> fields of
the struct. You access individual fields as hash keys of this object.

Take the following hash as an example:

  my $struct = Struct([
    f1 => c_char('P'),
    f2 => c_int(10),
    f3 => c_long(90000),
  ]);

Simply asking C<fields> for a field name returns a short description
of the field.

  print $struct->fields->{f2}; # <Field type=c_int, ofs=1, size=4>

You can access any property of the field's internal Ctypes object through
this hash key as well.

  print $struct->fields->{f2}->name;     # c_int
  print $struct->fields->{f2}->typecode; # i
  print $struct->fields->{f2}->owner;    # Ctypes::Type::Struct=HASH(0x...)

For simple types you could access the field's value by calling the C<value>
method through the hash key, but a much more convenient way to access values
is to use the C<values> method of the Struct object, detailed below.

=item name

Returns the name of the Struct object. If the object is a plain Struct
object, the name will be simply 'Struct'. If the object is a Struct
subclass, the name will be the last part of the package name, followed
by an underscore, followed by Struct, e.g. 'POINT_Struct'.

=item size

Returns the size of the Struct. Using the default alignment of 1, this
will be the sum of the sizes of all the members of the Struct. With
other alignments the C<size> might greater, depending on the contents of
the Struct.

For example, with the alignment set to 4, members I<after>
members which are smaller than 4 bytes (like C<c_char>s and C<c_short>s)
will be aligned to the next multple-of-four'th byte, making the small
member effectively 'take up' 4 bytes of memory in the Struct despite not
using them. But then of course, if the Struct only contains members which
are multiples of 4 bytes long, the 4-byte alignment will make no
difference.

=item typecode

Returns 'P', the typecode of all Structs.

=item values

Returns an object used to access the values of fields. This is what the
scalar dereferencing of Struct objects actually accesses for you, so the
following two lines are equivalent:

  print $struct->values->{field1};
  print $$struct->{field1};

=cut

#
# Accessor generation
#
my %access = (
  typecode      => ['_typecode_'],
  align         => [
    '_alignment',
    sub {if($_[0] =~ /^2$|^4$|^8$|^16$|^32$|^64$/){return 1}else{return 0}},
    1,
                   ],
  name          => ['_name'],
  size          => ['_size'],
  fields        => ['_fields'],
  values        => ['_values'],
             );
for my $func (keys(%access)) {
  no strict 'refs';
  my $key = $access{$func}[0];
  *$func = sub {
    my $self = shift;
    my $arg = shift;
    croak("The $key method only takes one argument") if @_;
    if(defined $access{$func}[1] and defined($arg)){
      print "Validating...\n" if $Debug;
      my $res;
      eval{ $res = $access{$func}[1]->($arg); };
      print "res: $res\n" if $Debug;
      if( $@ or $res == 0 ) {
        croak("Invalid argument for $key method: $arg");
      }
    }
    if($access{$func}[2] and defined($arg)) {
      $self->{$key} = $arg;
    }
    return $self->{$key};
  }
}

sub _datasafe {
  my( $self, $arg ) = @_;
  if( defined $arg and $arg != 1 and $arg != 0 ) {
    croak("Usage: ->_datasafe(1 or 0)")
  }
  if( defined $arg and $arg == 0 ) {
    $self->_set_owned_unsafe;
  }
  $self->{_datasafe} = $arg if defined $arg;
  return $self->{_datasafe};
}

sub _set_owned_unsafe {
  my $self = shift;
  print "Setting _owned_unsafe\n" if $Debug;
  for( @{$self->{_fields}->{_rawarray}} ) {
    $_->_datasafe(0);
    print "    He now knows his data's ", $_->_datasafe, "00% safe\n" if $Debug;
  }
  return 1;
}

=back

=head1 SEE ALSO

L<Ctypes::Union>
L<Ctypes::Type>

=cut

package Ctypes::Type::Struct::_Fields;
use warnings;
use strict;
use Carp;
use Data::Dumper;
use Scalar::Util qw|blessed looks_like_number|;
use overload
  '@{}'    => \&_array_overload,
  '%{}'    => \&_hash_overload,
  fallback => 'TRUE';
use Ctypes;
use Ctypes::Type::Field;

sub _array_overload {
  return $_[0]->{_array};
}

sub _hash_overload {
  my $caller = caller;
  if( $caller =~ /^Ctypes::Type::Struct/ ) {
    return $_[0];
  }
  my( $self, $key ) = ( shift, shift );
  my $class = ref($self);
  bless $self => 'overload::dummy';
#  print "_Fields' HashOverload\n" if $Debug;
  my $ret = $self->{_hash};
  bless $self => $class;
  return $ret;
}

sub new {
  my $class = ref($_[0]) || $_[0];  shift;
  my $obj = shift;
  my $self = {
               _obj         => $obj,
               _hash        => {},
               _array       => [],
               _size        => 0,
               _allowchange => 1,
             };
  bless $self => $class;
  return $self;
}

sub _add_field {
  my( $self, $key, $val ) = ( shift, shift, shift );
  print "In ", $self->{_obj}->{_name}, "'s _add_field(), from ", join(", ",(caller(1))[0..3]), "\n" if $Debug;
  print "    key is $key\n" if $Debug;
  print "    value is $val\n" if $Debug;
  if( exists $self->{_hash}->{$key} ) {
    croak( "Trying to add already extant key!" );
  }

  my $offset = 0;
  my $newfieldindex = 0;
  $newfieldindex = scalar @{$self->{_array}};
  my $align = $self->{_obj}->{_alignment};
  $align = 1 if $align == 0;

  if( $newfieldindex > 0 ) {
    print "    Already stuff in array\n" if $Debug;
    my $lastindex = $#{$self->{_array}};
    print "    lastindex is $lastindex\n" if $Debug;
    print "    lastindex index: ", $self->{_array}->[$lastindex]->index, "\n" if $Debug;
    print "    lastindex size: ", $self->{_array}->[$lastindex]->size, "\n" if $Debug;
    $offset = $self->{_array}->[$lastindex]->index
              + $self->{_array}->[$lastindex]->size;
    print "    alignment is $align\n" if $Debug;
    my $offoff = abs( $offset - $align ) % $align;
    if( $offoff ) { # how much the 'off'set is 'off' by.
      print "  offoff was $offoff off!\n" if $Debug;
      $offset += $offoff;
    }
  }
  print "    offset will be ", $offset, "\n" if $Debug;
  print "  Creating Field...\n" if $Debug;
  my $field = new Ctypes::Type::Field( $key, $val, $offset, $self->{_obj} );
  print "    setting array...\n" if $Debug;
  $self->{_array}->[$newfieldindex] = $field;
  print "    setting hash...\n" if $Debug;
  $self->{_hash}->{$key} = $field;

  print "    _ADD_FIELD returning!\n" if $Debug;
  return $self->{_hash}->{$key};
}

package Ctypes::Type::Struct::_Values;
use warnings;
use strict;
use Carp;
use Data::Dumper;
use Scalar::Util qw|blessed looks_like_number|;
use overload
  '@{}'    => \&_array_overload,
  '%{}'    => \&_hash_overload,
  fallback => 'TRUE';

sub _array_overload {
  print "_Values's ARRAY ovld\n" if $Debug;
  print "    ", ref( $_[0]->{_array} ), "\n" if $Debug;
  my $self = shift;
  return $self->{_array};
}

sub _hash_overload {
  my $caller = caller;
  if( $caller =~ /^Ctypes::Type::Struct/ ) {
    return $_[0];
  }
  print "_Values's HASH ovld\n" if $Debug;
  my( $self, $key ) = ( shift, shift );
  my $class = ref($self);
  bless $self => 'overload::dummy';
  my $ret = $self->{_hash};
  bless $self => $class;
  return $ret;
}

sub new {
  print "In _Values constructor!\n" if $Debug;
  my $class = ref($_[0]) || $_[0];  shift;
  my $obj = shift;
  my $self = {
                _obj         => $obj,
                _hash        => {},
                _rawhash     => undef,
                _array       => [],
                _rawarray    => undef,
                _fields      => $obj->{_fields},
              };
  $self->{_rawhash} = tie %{$self->{_hash}},
                  'Ctypes::Type::Struct::_Fields::_hash', $self->{_fields};
  $self->{_rawarray} = tie @{$self->{_array}},
                  'Ctypes::Type::Struct::_Fields::_array', $self->{_fields};
  bless $self => $class;
  print "    _VALUES constructor returning ok\n" if $Debug;
  return $self;
}

package Ctypes::Type::Struct::_Fields::_array;
use warnings;
use strict;
use Carp;
use Scalar::Util qw|blessed|;
use Ctypes;
use Data::Dumper;

sub TIEARRAY {
  my $class = ref($_[0]) || $_[0];  shift;
  my $fields = shift;
  my $self = {
                _fields   => $fields,
                _array     => [],
              };
  bless $self => $class;
  return $self;
}

sub STORE {
  my $self = shift;
  my $index = shift;
  my $val = shift;
  print "In _Fields::_array::STORE\n" if $Debug;
  print "    index is $index\n" if $Debug;
  print "    val is $val\n" if $Debug;
  $self->{_fields}->{_array}->[$index]->{_contents} = $val;
  return $self->{_fields}->{_array}->[$index]->{_contents};
}

sub FETCH {
  my( $self, $index ) = (shift, shift);
  print "In _array::FETCH, index $index, from ", join(", ",(caller(1))[0..3]), "\n" if $Debug;
  return $self->{_fields}->{_array}->[$index]->{_contents};
}

sub FETCHSIZE { return scalar @{ $_[0]->{_fields}->{_array} } }
sub EXISTS { exists $_[0]->{_fields}->{_array}->[$_[1]] }

package Ctypes::Type::Struct::_Fields::_hash;
use warnings;
use strict;
use Scalar::Util qw|blessed|;
use Ctypes;
use Carp;
use Data::Dumper;

sub TIEHASH {
  my $class = ref($_[0]) || $_[0];  shift;
  my $fields = shift;
  my $self = {
                _fields   => $fields,
                _hash     => {},
              };
  bless $self => $class;
  return $self;
}

sub STORE {
  my $self = shift;
  my $key = shift;
  my $val = shift;
  print "In _Fields::_hash::STORE\n" if $Debug;
  print "    key is $key\n" if $Debug;
  print "    val is $val\n" if $Debug;
  $self->{_fields}->{_hash}->{$key}->{_contents} = $val;
  return $self->{_fields}->{$key};
}

sub FETCH {
  my( $self, $key ) = (shift, shift);
  print "In _hash::FETCH, key $key, from ", join(", ",(caller(1))[0..3]), "\n" if $Debug;
  print "    ", ref($self->{_fields}->{_hash}->{$key}), "\n" if $Debug;
  return $self->{_fields}->{_hash}->{$key}->{_contents};
}

sub FIRSTKEY {
  my $a = scalar keys %{$_[0]->{_fields}->{_hash}};
  each %{$_[0]->{_fields}->{_hash}}
}

sub NEXTKEY { each %{$_[0]->{_fields}->{_hash}} }
sub EXISTS { exists $_[0]->{_fields}->{_hash}->{$_[1]} }
sub DELETE { croak( "XXX Cannot delete Struct fields" ) }
sub CLEAR { croak( "XXX Cannot clear Struct fields" ) }
sub SCALAR { scalar %{$_[0]->{_fields}->{_hash}} }

#  package Ctypes::Type::Struct::_Fields::_Finder;
#  use warnings;
#  use strict;
#  use Ctypes;
#  use Carp;
#  use Data::Dumper;
#
#  #
#  # This was designed to allow method-style access to Struct members
#  # Removed and not yet re-integrated
#  #
#
#  sub new {
#    if( caller ne 'Ctypes::Type::Struct::_Fields' ) {
#      our $AUTOLOAD = '_Finder::new';
#      shift->AUTOLOAD;
#    }
#    my $class = shift;
#    my $fields = shift;
#    return bless [ $fields ] => $class;
#  }
#
#  sub AUTOLOAD {
#    our $AUTOLOAD;
#    print "In _Finder::AUTOLOAD\n" if $Debug;
#    print "    AUTOLOAD is $AUTOLOAD\n" if $Debug;
#    if ( $AUTOLOAD =~ /.*::(.*)/ ) {
#      return if $1 eq 'DESTROY';
#      my $wantfield = $1;
#      print "     Trying to AUTOLOAD for $wantfield\n" if $Debug;
#      my $self = $_[0];
#      my $instance = $self->[0]->{_obj};
#      if( defined $instance->{_subclass}
#          and $instance->can($wantfield) ) {
#        no strict 'refs';
#        goto &{$self->[0]->{_obj}->can($wantfield)};
#      }
#      my $found = 0;
#      if( exists $self->[0]->{_hash}->{$wantfield} ) {
#        $found = 1;
#        print "    Found it!\n" if $Debug;
#        my $object = $self->[0]->{_obj};
#        my $func = sub {
#          my $caller = shift;
#          my $arg = shift;
#          print "In $wantfield accessor\n" if $Debug;
#          croak("Too many arguments") if @_;
#          if( not defined $arg ) {
#            if(ref($caller)) {
#              print "    Returning value...\n" if $Debug;
#              my $ret = $self->[0]->{_hash}->{$wantfield};
#              if( ref($ret) eq 'Ctypes::Type::Simple' ) {
#                return ${$ret};
#              } elsif( ref($ret) eq 'Ctypes::Type::Array') {
#                return ${$ret};
#              } else {
#                return $ret;
#              }
#            } else {
#              # class method?
#              # or should that be done in Type::Struct?
#            }
#          } else {
#          }
#        };
#        if( defined( my $subclass = $self->[0]->{_obj}->{_subclass} ) ) {
#          no strict 'refs';
#          *{"${subclass}::$wantfield"} = $func;
#          goto &{"${subclass}::$wantfield"};
#        }
#      } else { # didn't find field
#        print "    Didn't find it\n" if $Debug;
#        print "    Here's what we had:\n" if $Debug;
#        print Dumper( $self->[0]->{_hash} ) if $Debug;
#        print Dumper( $self->[0]->{_array} ) if $Debug;
#        croak( "Couldn't find field '$wantfield' in ",
#          $self->[0]->{_obj}->name );
#      }
#    }  # if ( $AUTOLOAD =~ /.*::(.*)/ )
#  }

1;
