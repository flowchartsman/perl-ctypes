package Ctypes::Type::Pointer;
use strict;
use warnings;
use Carp;
use Ctypes;
use overload
  '+'      => \&_add_overload,
  '-'      => \&_substract_overload,
  '${}'    => \&_scalar_overload,
  '@{}'    => \&_array_overload,
  fallback => 'TRUE';

our @ISA = qw|Ctypes::Type|;
my $Debug;

=head1 NAME

Ctypes::Type::Pointer - What's that over there?

=head1 SYNOPSIS

    use Ctypes;

    my $int = c_int(5);
    print $$int;                   #   5

    my $ptr = Pointer( $int );
    print $$ptr;                   #   SCALAR(0x9b3ba30)
    print $$ptr[0];                #   5

    $$ptr[0] = 10;
    print $$int;                   #   10

=head1 ABSTRACT

This class emulates C pointers. Or rather, pointers to other
Ctypes objects (there's no raw memory manipulation going on here).

=head1 DESCRIPTION

In the current implementation, Pointer objects are the only Ctypes
type which come close to dealing with raw memory. For most types,
which simply represent a value, that value can be normally be cached
as a Perl scalar up until the point it is required by a C library
function. However, in order to emulate pointer arithmetic, Pointer
objects have to access the raw data fields of the Ctypes objects
to which they point whenever they are dereferenced.

This needn't happen on all occasions though. Since Ctypes types are
both 'object' and 'value', and it would be nice to use Pointers to
access both, Pointer objects can be 'dereferenced' in two different
ways.

=head3 Pointer as alias

When you wish to use a Pointer as a straight-forward alias to another
Ctypes Type object, you can use B<scalar dereferencing> of the
Pointer object, or the C<contents> object method.

  my $int = c_int(10);
  my $ptr = Pointer( $int );

  print $ptr;             # SCALAR(0xb1ab1aa), the Pointer object
  print $$prt;            # SCALAR(0xf00f000), the c_int object
  print $ptr->contents;   # the c_int object again

This means that to use the C<c_int> object via the Pointer, you
can add (yet) another dollar-sign to perform dereferencing on the
returned C<c_int> object:

  print $$$ptr;           # 10
  $$$ptr = 25;
  print $$int;            # 25

It might be helpful to remember what each sigil is doing what here:

                      $$$ptr;
                      ^^^
                     / | \
                    /  |  Sigil for the Pointer object
  Dereferencing the    |
  returned c_int, to  Scalar dereferncing of the
  return the value    Pointer object, returning the
                      c_int object

=head3 Pointer to data

The other way of using Pointer objects is in contexts of 'pointer
arithmetic', using them to index to arbitrary memory locations.
Due to Ctypes' current implementation (mainly Perl, as opposed
to mainly C), there is a limit to the arbitrariness of these
memory locations. You can use Pointers to access locations within
the C<data> fields of Ctypes objects, but you can't stray out
into uncharted memory. This has its advantages and disadvantages.
In any case, the situation would likely change should Ctypes move
to a mainly C implementation.

You access memory with Pointers using B<array dereferencing>.
If the type of the pointer is the same as the type of the object
you it's currently pointing to, C<$$ptr[0]> will return the value
held by the object. If the Pointer type and the object type
are different, then strange, hard to predict, but potentially
very useful things can happen. See below under the C<new> method
for an example.

=cut

############################################
# TYPE::POINTER : PRIVATE FUNCTIONS & DATA #
############################################

sub _add_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{_offset} + $y; }
    else { $ret = $y->{_offset} + $x; }
  } else {           # += etc.
    $x->{_offset} = $x->{_offset} + $y;
    $ret = $x;
  }
  return $ret;
}

sub _array_overload {
  print ". . .._wearemany_.. . .\n" if $Debug;
  return shift->{_bytes};
}

sub _scalar_overload {
  print "We are One ^_^\n" if $Debug;
  return \shift->{_contents};
}

sub _subtract_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{_offset} - $y; }
    else { $ret = $x - $y->{_offset}; }
  } else {           # -= etc.
    $x->{_offset} -= $y;
    $ret = $x;
  }
  return $ret;
}

############################################
# TYPE::POINTER : PUBLIC FUNCTIONS & DATA  #
############################################

=head1 METHODS

Ctypes::Type::Pointer provides the following methods.

=over

=item new OBJECT

=item new CTYPE, OBJECT

Like with Arrays and Structs, you'll rarely use Ctypes::Type::Pointer->new
directly since L<Ctypes> exports the C<Pointer> function by default.

Pointers can be instantiated in two ways. First, you can pass a Ctypes
object to which you want to create a pointer. The Pointer will be
typed according to that object.

Alternatively, you can pass a Ctype to indicate the type in the first
position, and the object at which to point in the second position. In this
way you can index into data at arbitrary intervals based on the size of
the 'type' of pointer you choose. For example, on a system where C<short>
is two octets and C<char> is one:

  my $uint = c_uint(691693896);
  my $charptr = Pointer( c_char, $uint );
  print @$charptr, "\n";

Here, a Pointer has been made of type C<c_char>, four of which can be
elicited from the four-byte C<c_uint> number. The output of this code
on a Big-endian system would be a friendly greeting.

=cut

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

  carp("Usage: Pointer( [type, ] \$object )") if @_;

  return undef unless Ctypes::is_ctypes_compat($contents);

  my $typecode = $type->typecode if ref($type);
  #if( not Ctypes::sizeof($type) ) {
  #  carp("Invalid Array type specified (first position argument)");
  #  return undef;
  #}
  my $self = $class->_new( {
     _name        => $type.'_Pointer',
     _size        => Ctypes::sizeof('p'),
     _offset      => 0,
     _contents    => $contents,
     _bytes       => undef,
     _type        => $type,
     _typecode    => 'p',
  } );
  $self->{_rawcontents} =
    tie $self->{_contents}, 'Ctypes::Type::Pointer::contents', $self;
  $self->{_rawbytes} =
    tie @{$self->{_bytes}},
          'Ctypes::Type::Pointer::bytes',
          $self;
  $self->{_contents} = $contents;
  return $self;
}

=item copy

Return a copy of the Pointer object.

=cut

sub copy {
  return Ctypes::Type::Pointer->new( $_[0]->contents );
}

=item deref

This accessor returns the Ctypes object to which the Pointer points,
like C<$$pointer>, but since it doesn't require the double sigil it
is useful in e.g. accessing members of compound objects like Arrays.

=cut

sub deref () : method {
  return ${shift->{_contents}};
}

sub data { &_as_param_(@_) }

sub _as_param_ {
  my $self = shift;
  print "In ", $self->{_name}, "'s _As_param_, from ", join(", ",(caller(1))[0..3]), "\n" if $Debug;
  if( defined $self->{_data}
      and $self->{_datasafe} == 1 ) {
    print "already have _as_param_:\n" if $Debug;
    print "  ", $self->{_data}, "\n" if $Debug;
    print "   ", unpack('b*', $self->{_data}), "\n" if $Debug;
    return \$self->{_data}
  }
# Can't use $self->{_contents} as FETCH will bork at _datasafe
# use $self->{_raw}{DATA} instead
  $self->{_data} =
    ${$self->{_rawcontents}{DATA}->_as_param_};
  print "  ", $self->{_name}, "'s _as_param_ returning ok...\n" if $Debug;
  $self->{_datasafe} = 0;  # used by FETCH
  return \$self->{_data};
}

sub _update_ {
  my( $self, $arg ) = @_;
  print "In ", $self->{_name}, "'s _UPDATE_, from ", join(", ",(caller(0))[0..3]), "\n" if $Debug;
  print "  self is ", $self, "\n" if $Debug;
  print "  arg is $arg\n" if $Debug;
  print "  which is\n", unpack('b*',$arg), "\n  to you and me\n" if $Debug;
  $arg = $self->{_data} unless $arg;

  my $success = $self->{_rawcontents}{DATA}->_update_($arg);
  if(!$success) {
    croak($self->{_name}, ": Error updating contents");
  }
#
#  $self->{_data} = $self->_as_param_;
  $self->{_datasafe} = 1;
  return 1;
}

=item contents

This accessor returns the object to which the Pointer points (as
opposed to the I<value> represented by that object). C<$ptr-E<gt>
contents> is a synonym for C<$$ptr>, but since it doesn't require
the double-sigil syntax it can be used e.g. when accessing members
of compound objects like L<Arrays|Ctypes::Type::Array>.

=item type

This accessor returns the typecode of the type to which the Pointer
points. It is analogous to the pointer 'type' in C. Pointer I<objects>
themselves are always typecode 'p'.

=item offset NUMBER

=item offset

This method sets and/or returns the current offset of the Pointer
object. The offset of the Pointer object can also be manipulated by
using various mathematical operators on the object:

  $pointer++;
  $pointer--;
  $pointer += 2;

Note that these are performed on the Pointer object itself (with one
sigil). Two sigils gets you the value the Pointer points to, and they're
not what you want to increment.

When using Perl array-style subscript dereferencing on the Pointer to
access chunks of data, the subscript B<is added to the offset>. The
following shows two ways to get the same result:

  my $array = Array( c_int, [ 1, 2, 3, 4, 5 ] );
  my $intptr = ( c_int, $array );      # offset is 0

  print $$intptr[2];                   # 3
  $intptr += 3;
  print $$intptr[0];                   # 3

Note that since Perl translates negative subscripts into positive ones
based on array size, negative subscripts on Pointer objects do not
work.

=cut

#
# Accessor generation
#
my %access = (
  contents          => ['_contents'],
  offset            => ['_offset',undef,1],
);

sub type { $_[0]->{_type}->typecode; }
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
  print "In Bytes' TIESCALAR\n" if $Debug;
  my $class = shift;
  my $owner = shift;
  my $self = { _owner => $owner,
               DATA  => undef,
             };
  print "    my owner is ", $self->{_owner}{_name}, "\n" if $Debug;
  return bless $self => $class;
}

sub STORE {
  my( $self, $arg ) = @_;
  print "In ", $self->{_owner}{_name}, "'s content STORE, from ", (caller(1))[0..3], "\n" if $Debug;
  if( not Ctypes::is_ctypes_compat($arg) ) {
    if ( $arg =~ /^\d*$/ ) {
      croak("Cannot make Pointer to plain scalar; did you mean to say '\$ptr++'?")
    }
    croak("Pointers are to Ctypes compatible objects only")
  }
  $self->{_owner}{_data} = undef;
  $self->{_owner}{_offset} = 0; # makes sense to reset offset
  print "  ", $self->{_owner}{_name}, "'s content STORE returning ok...\n" if $Debug;
  return $self->{DATA} = $arg;
}

sub FETCH {
  my $self = shift;
  print "In ", $self->{_owner}{_name}, "'s content FETCH, from ", (caller(1))[0..3], "\n" if $Debug;
  if( defined $self->{_owner}{_data}
      or $self->{_owner}{_datasafe} == 0 ) {
    print "    Woop... _as_param_ is ", unpack('b*',$self->{_owner}{_data}),"\n" if $Debug;
    my $success = $self->{_owner}->_update_(${$self->{_owner}->_as_param_});
    croak($self->{_name},": Could not update contents") if not $success;
  }
  croak("Error: Data not safe") if $self->{_owner}{_datasafe} != 1;
  print "  ", $self->{_owner}{_name}, "'s content FETCH returning ok...\n" if $Debug;
  print "  Returning ", ${$self->{DATA}}, "\n" if $Debug;
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
  my $self = { _owner => $owner,
               DATA  => [],
             };
  return bless $self => $class;
}

sub STORE {
  my( $self, $index, $arg ) = @_;
  print "In ", $self->{_owner}{_name}, "'s Bytes STORE, from ", (caller(0))[0..3], "\n" if $Debug;
  if( ref($arg) ) {
    carp("Only store simple scalar data through subscripted Pointers");
    return undef;
  }

  my $data = $self->{_owner}{_rawcontents}{DATA}->_as_param_;
  print "\tdata is $$data\n" if $Debug;
  my $each = $self->{_owner}{_type}->size;

  my $offset = $index + $self->{_owner}{_offset};
  if( $offset < 0 ) {
    carp("Pointer cannot store before start of data");
    return undef;
  }
  if( $offset >= length($$data)                  # start at end of data
      or ($offset + $each) > length($$data) ) {  # or will go past it
    carp("Pointer cannot store past end of data");
  }

  print "\teach is $each\n" if $Debug;
  print "\tdata length is ", length($$data), "\n" if $Debug;
  my $insert = pack($self->{_owner}{_type}->packcode,$arg);
  print "\tinsert is ", unpack('b*',$insert), "\n" if $Debug;
  if( length($insert) != $self->{_owner}{_type}->size ) {
    carp("You're about to break something...");
# ??? What would be useful feedback here? Aside from just not doing it..
  }
  print "\tdata before and after insert:\n" if $Debug;
  print unpack('b*',$$data), "\n" if $Debug;
  substr( $$data,
          $each * $offset,
          $self->{_owner}{_type}->size,
        ) =  $insert;
  print unpack('b*',$$data), "\n" if $Debug;
  $self->{DATA}[$index] = $insert;  # don't think this can be used
  $self->{_owner}{_rawcontents}{DATA}->_update_($$data);
  print "  ", $self->{_owner}{_name}, "'s Bytes STORE returning ok...\n" if $Debug;
  return $insert;
}

sub FETCH {
  my( $self, $index ) = @_;
  print "In ", $self->{_owner}{_name}, "'s Bytes FETCH, from ", (caller(1))[0..3], "\n" if $Debug;

  my $type = $self->{_owner}{_type};
  if( $type->name =~ /[pv]/ ) {
    carp("Pointer is to type ", $type,
         "; can't know how to dereference data");
    return undef;
  }

  my $data = $self->{_owner}{_rawcontents}{DATA}->_as_param_;
  print "\tdata is $$data\n" if $Debug;
  my $each = $self->{_owner}{_type}->size;

  my $offset = $index + $self->{_owner}{_offset};
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

  print "\toffset is $offset\n" if $Debug;
  print "\teach is $each\n" if $Debug;
  print "\tstart is $start\n" if $Debug;
  print "\torig_type: ", $self->{_owner}{_type}->name, "\n" if $Debug;
  print "\tdata length is ", length($$data), "\n" if $Debug;
  my $chunk = substr( $$data,
                      $each * $offset,
                      $self->{_owner}{_type}->size
                    );
  print "\tchunk: ", unpack('b*',$chunk), "\n" if $Debug;
  $self->{DATA}[$index] = $chunk;
  print "  ", $self->{_owner}{_name}, "'s Bytes FETCH returning ok...\n" if $Debug;
  return unpack($self->{_owner}{_type}->packcode,$chunk);
}

sub FETCHSIZE {
  my $data = $_[0]->{_owner}{_rawcontents}{DATA}{_data}
    ? $_[0]->{_owner}{_rawcontents}{DATA}{_data}
    : $_[0]->{_owner}{_rawcontents}{DATA}->_as_param_;
  my $type = $_[0]->{_owner}{_type};
  return length($data) / $type->size;
}

sub EXISTS { 0 }  # makes no sense for ::bytes
sub EXTEND { }
sub UNSHIFT { croak("Pointer::bytes isn't a normal array - can't unshift") }
sub SHIFT { croak("Pointer::bytes isn't a normal array - can't shift") }
sub PUSH { croak("Pointer::bytes isn't a normal array - can't push") }
sub POP { croak("Pointer::bytes isn't a normal array - can't pop") }
sub SPLICE { croak("Pointer::bytes isn't a normal array - can't splice") }

1;
