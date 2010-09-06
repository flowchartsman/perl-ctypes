package Ctypes::Type;
# always loaded and all c types are exported.
use strict;
use warnings;
use Carp;
require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT_OK = qw|&_types &allow_overflow_all|;
our $VERSION = 0.002;
use constant USE_PERLTYPES => 1; # so far use only perl pack-style types, 
                                 # not the full python ctypes types
use Ctypes;
use Ctypes::Type::Simple;
use Ctypes::Type::Array;
use Ctypes::Type::Pointer;
use Ctypes::Type::Struct;
my $Debug = 0;

=head1 NAME

Ctypes::Type - Abstract base class for Ctypes Data Type objects

=cut

our $_perltypes = 
{ 
  v =>  "c_void",
  c =>  "c_byte",
  C =>  "c_char",
  s =>  "c_short",
  S =>  "c_ushort",
  i =>  "c_int",
  I =>  "c_uint",
  l =>  "c_long",
  L =>  "c_ulong",
  f =>  "c_float",
  d =>  "c_double",
  D =>  "c_longdouble",
  p =>  "c_void_p",
};

# c_char c_wchar c_byte c_ubyte c_short c_ushort c_int c_uint c_long c_ulong
# c_longlong c_ulonglong c_float c_double c_longdouble c_char_p c_wchar_p
# c_size_t c_ssize_t c_bool c_void_p

# implemented as aliases:
# c_int8 c_int16 c_int32 c_int64 c_uint8 c_uint16 c_uint32 c_uint64

our $_pytypes = 
{ 
  b =>  "c_byte",        # -128 < int < 128, c?
  B =>  "c_ubyte",       # 0 < int < 256, C?
  X =>  "c_bstr",        # a?
  c =>  "c_char",        # single character, c?
  C =>  "c_uchar",       # C?
  s =>  "c_char_p",      # null terminated string, A?
  w =>  "c_wchar",       # U
  z =>  "c_wchar_p",     # U*
  h =>  "c_short",       # s
  H =>  "c_ushort",      # S
  i =>  "c_int",         # Alias to c_long where equal, i
  I =>  "c_uint",        # ''                           I
  l =>  "c_long",        # l
  L =>  "c_ulong",       # L
  f =>  "c_float",       # f
  d =>  "c_double",      # d
  g =>  "c_longdouble",  # Alias to c_double where equal, D
  q =>  "c_longlong",    # q
  Q =>  "c_ulonglong",   # Q
  v =>  "c_bool",        # ?
  O =>  "c_void_p",      # i???
};
our $_types = USE_PERLTYPES ? $_perltypes : $_pytypes;
sub _types () { return $_types; }
sub allow_overflow_all;

=head1 SYNOPSIS

use Ctypes;

my $int = c_int(10);

$$int = 15;                          # Note the double sigil
$$int += 3;
print $int->size;                    # sizeof(int) in C
print $int->name;                    # 'c_int'

my $array = Array( 7, 6, 5, 4, 3 );  #Create array (of c_ushort)
my $dblarray = Array( c_double, [ 2, 1, 0, -1, -2 ] );
$$dblarray[2] = $$int;               # Again, note sigils
print $dblarray->size;               # sizeof(type) * #members

# Create int-type pointer to double-type array
my $intp = Pointer( c_int, $dblarray );
print $$intp[2];                     # 1073741824 on my system

=head1 ABSTRACT

Ctypes::Type is the base class for classes representing the
simple C types, as well as L<Arrays|Ctypes::Type::Array>,
L<Pointers|Ctypes::Type::Pointer>, L<Structs|Ctypes::Type::Struct>
and L<Unions|Ctypes::Type::Union> (although there are functions for
all of them in the main L<Ctypes> namespace, so you can normally
just C<use Ctypes>).

Common methods are documented here. See the relevant documentation
for the above packages for more detailed information.

=cut

# Ctypes::Type::_new: Abstract base class for all Ctypes objects
sub _new {
  return bless my $self = {
    _data       =>  "\0",             # raw (binary) memory block
    _needsfree  =>  0,             # does object own its data? (not used yet, 0.002)
    _owner      =>  undef,         # ref to object that owns this one
    _size       =>  0,             # size of memory block in bytes
    _length     =>  1,             # ? number of fields of this object ???
    _index      =>  undef,         # index of this object into the base
                                   # object's _object list
    _objects    =>  undef,         # objects this object holds
    _value      =>  undef,         # 'a small default buffer'
    _address    =>  undef,
    _datasafe   =>  1,             # Can object trust & return its _value
                                   # or must it update its _data?
    _name       => undef,
    _typecode   => undef,
     } => ref($_[0]) || $_[0];
}

# Pod for these functions is on down below

# can't be relied upon to be lvalue as compound types will override
sub _datasafe {
  $_[0]->{_datasafe} = $_[1] if defined $_[1]; return $_[0]->{_datasafe};
}

sub _needsfree : lvalue {
  $_[0]->{_needsfree} = $_[1] if defined $_[1]; $_[0]->{_needsfree};
}

#
# Create global c_<type> functions...
#
my %_defined;
for my $k (keys %$_types) {
  my $name = $_types->{$k};
  my $func;
  unless ($_defined{$name}) {
    no strict 'refs';
    $func = sub { Ctypes::Type::Simple->new($k, @_); };
    *{"Ctypes::$name"} = $func;
    $_defined{$name} = 1;
  }
}
our @_allnames = keys %_defined;

=head1 METHODS

Apart from its value or values, each Ctypes::Type object holds various
pieces of information about itself, which you can access via the methods
below. Some are only 'getters', but some could be misused to greatly
confuse the object internals, so you shouldn't assign to them lightly.

=over

=item data

Returning a I<reference> to the object's data field, where its value is
held in L<pack|perlfunc/"pack">ed form. This was originally designed
for internal use, so the semantics are likely to change in future, as
handing out direct access to the data field isn't a good default for
such an innocuously named method.

=cut

#
# Hello! Currently classes implement their own data() methods.
# Looking into commonalities and whether they can be abstracted
# in some way is still TODO.
#

=item index

Returns the offset of the object into its 'owner' object, if it
has one (i.e. an Array, Struct or Union).

=cut

sub index {
  return $_[0]->{_index};
}

sub _set_index {
  $_[0]->{_index} = $_[1] if defined $_[1]; return $_[0]->{_index};
}

=item name

Accessor returning the 'name' of the Type instance ('c_int', 'c_double',
etc.).

B<Note> The use of the C<name> attribute is currently quite
inconsistent. It's used in places it shouldn't be. There should be some
kind of C<Ctypes::are_like()> function to do a deep equivalence check
for data types. At that time C<name> will become simpler. Until then
though, the following rules apply:

Since all basic types are currently Ctypes::Type::Simple objects,
the C<name> attribute is how you find out what kind of type you
actually have.

For compound data types, the name will tell you something about the
object's contents.

For Arrays, C<name> is the lowercased C<name> of the type of object
contained in the array, minus any leading 'c_', plus the suffix '_Array',
e.g. 'int_Array'.

For Pointers, C<name> is the lowercased C<name> of the type of object
being pointed to, minus any leading 'c_', plus the suffix '_Pointer',
e.g. 'int_array_Pointer'.

In the case of Structs, the preceeding convention could get out of hand
(even quicker than it does with the others), so C<name> consists of the
typecodes of the Struct's constituent types, in order, concatenated
together, plus the suffix '_Struct'. So a Struct of three unsigned ints
and two signed doubles would have the name 'iiiDD_Struct' (of course,
this can't be relied upon for checking equivalence, as all compound
Types have the typecode 'p').

=cut

sub name   { return $_[0]->{_name}  }
sub _set_name { die unless scalar @_ == 2; return $_[0]->{_name} = $_[1] }

=item owner

Return the object's 'owner' object, i.e. the Array, Struct or Union
of which it is currently part. Returns undef if the object isn't
inside any others.

=cut

sub owner { return $_[0]->{_owner} }
sub _set_owner {
  $_[0]->{_owner} = $_[1] if defined $_[1]; return $_[0]->{_owner};
}

=item size

Accessor returning the size in bytes on your system of the C type
represented by the Type object. For example, a c_int object might
have size 4, and an Array of five of them would have size 20.

=cut

sub size   { return $_[0]->{_size}  }
sub _set_size { return $_[0]->{_size} = $_[1] }

=item typecode

Accessor returning the 'typecode' of the Type instance. A typecode
is a 1-character string used internally for representing different
C types, which might be useful for various things.

=cut

sub typecode { return $_[0]->{_typecode} }

=back

=head1 CLASS FUNCTIONS

=over

=item allow_overflow_all

This class method can put a stop to all overflowing for all Type
objects. Sets/returns 1 or 0. See L</"allow_overflow"> above.

=back

=cut

{
  my $allow_overflow_all = 1;
  sub allow_overflow_all {
# ??? This could be improved; could still be called as a class method
# with an object instead of a 1 or 0 and user would not be notified
    my $arg = shift;
    if( @_ or ( defined($arg) and $arg != 1 and $arg != 0 ) ) {
      croak("Usage: allow_overflow_all(x) (1 or 0)");
    }
    $allow_overflow_all = $arg if defined $arg;
    return $allow_overflow_all;
  }
}

=head1 SEE ALSO

L<Ctypes::Type::Simple>
L<Ctypes::Type::Array>
L<Ctypes::Type::Struct>

=cut

1;
__END__
