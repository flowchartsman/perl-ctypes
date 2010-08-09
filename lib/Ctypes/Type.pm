package Ctypes::Type;
# always loaded and all c types are exported.

use strict;
use warnings;
use Carp;
use Ctypes;
require Exporter;
our @ISA = ("Exporter");
use constant USE_PERLTYPES => 1; # so far use only perl pack-style types, 
                                 # not the full python ctypes types
use Ctypes::Type::Array;
our @EXPORT_OK = qw|&_types|;

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

our $_pytypes = 
{ 
  s =>  "c_char_p",
  c =>  "c_char",
  b =>  "c_byte",
  B =>  "c_ubyte",
  C =>  "c_uchar",
  h =>  "c_short",
  H =>  "c_ushort",
  i =>  "c_int",
  I =>  "c_uint",
  l =>  "c_long",
  L =>  "c_ulong",
  f =>  "c_float",
  d =>  "c_double",
  g =>  "c_longdouble",
  q =>  "c_longlong",
  Q =>  "c_ulonglong",
  P =>  "c_void_p",
  u =>  "c_wchar_p",
  U =>  "c_char_p",
  Z =>  "c_wchar_p",
  X =>  "c_bstr",
  v =>  "c_bool",
  O =>  "c_void_p",
};
our $_types = USE_PERLTYPES ? $_perltypes : $_pytypes;
sub _types () { return $_types; }
sub allow_overflow_all;

# http://docs.python.org/library/ctypes.html
# #ctypes-fundamental-data-types-2:
# Fundamental data types, when returned as foreign function call
# results, or, for example, by retrieving structure field members
# or array items, are transparently converted to native Python types.
# In other words, if a foreign function has a restype of c_char_p,
# you will always receive a Python string, not a c_char_p instance.

# Subclasses of fundamental data types do not inherit this behavior.
# So, if a foreign functions restype is a subclass of c_void_p, you
# will receive an instance of this subclass from the function call.
# Of course, you can get the value of the pointer by accessing the
# value attribute.

package Ctypes::Type::Simple::value;
use strict;
use warnings;
use Carp;

my $_owner;

sub TIESCALAR {
  my $class = shift;
  $_owner = shift;
  return bless \my $self => $class;
}

sub STORE {
  my $self = shift;
  my $arg = shift;
  # Deal with being assigned other Type objects and the like...
  if(my $ref = ref($arg)) {
    if($ref =~ /^Ctypes::Type::/) {
      $arg = $arg->{_as_param_};
    } else {
      if($arg->can("_as_param_")) {
        $arg = $arg->_as_param_;
      } elsif($arg->{_as_param_}) {
        $arg = $arg->{_as_param_};
      } else {
  # ??? Would you ever want to store an object/reference as the value
  # of a type? What would get pack()ed in the end?
        croak("Ctypes Types can only be made from native types or " . 
              "Ctypes compatible objects");
      }
    }
  }
  my $typecode = $_owner->{_typecode_};
  croak("Simple Types can only be assigned a single value") if @_;
  # return 1 on success, 0 on fail, -1 if (numeric but) out of range
  my $is_valid = Ctypes::_valid_for_type($arg,$typecode);
  if( $is_valid < 1 ) {
    no strict 'refs';
    if( ($is_valid == -1)
        and ( $_owner->allow_overflow == 0
        or Ctypes::Type::allow_overflow_all == 0 ) ) {
      carp( "Value out of range for " . $_owner->{name} . ": $arg");
      return undef;
    } else {
      my $temp = Ctypes::_cast($arg,$typecode);
      if( $temp && Ctypes::_valid_for_type($temp,$typecode) ) {
        $arg = $temp;
      } else {
        carp("Unreconcilable argument for type " . $_owner->{name} .
              ": $arg");
        return undef;
      }
    }
  }
  $_owner->{_as_param_} = pack( $typecode, $arg );
  $$self = $arg;
  return $$self;
}

sub FETCH {
  my $self = shift;
  return $$self;
}


package Ctypes::Type::Simple;
use strict;
use warnings;
use Ctypes;
use Carp;
our @ISA = qw|Ctypes::Type|;
use fields qw|alignment name _typecode_ size
              allow_overflow val _as_param_|;
use overload '${}' => \&_scalar_overload,
             fallback => 'TRUE';
             # TODO Multiplication will have to be overridden
             # to implement Python's Array contruction with "type * x"???



sub _num_overload { return shift->{val}; }

sub _add_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{val} + $y; }
    else { $ret = $y->{val} + $x; }
  } else {           # += etc.
    $x->{val} = $x->{val} + $y;
    $ret = $x;
  }
  return $ret;
}

sub _subtract_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{val} - $y; }
    else { $ret = $x - $y->{val}; }
  } else {           # -= etc.
    $x->{val} = $x->{val} - $y;
    $ret = $x;
  }
  return $ret;
}

sub _scalar_overload {
  return \shift->{val};
}

sub new {
  my $class = shift;
  my $typecode = shift;
  my $arg = shift;
  my $self = { _as_param_      => '',
               _typecode_      => $typecode,
               val             => undef,
               address         => undef,
               name            => $_types->{$typecode},
               size            => Ctypes::sizeof($typecode),
               alignment       => 0,
               allow_overflow  => 1,
             };
  bless $self => $class;
  $arg = 0 unless defined $arg;
  tie $self->{val}, 'Ctypes::Type::Simple::value', $self;
  $self->{val} = $arg;
  return undef if not defined $self->{val};
# XXX Unimplemented! How will 'address' this work?
# Is it relevant in our Perl-based model?
#  $self->{address} = Ctypes::addressof($self);
  return $self;
}

#
# Accessor generation
#
my %access = ( 
  _data             => ['_as_param_'],
  typecode          => ['_typecode_'],
  allow_overflow =>
    [ 'allow_overflow',
      sub {if( $_[0] != 1 and $_[0] != 0){return 0;}else{return 1;} },
      1 ], # <--- this makes overflow settable
  alignment         => ['alignment'],
  name              => ['name'],
  size              => ['size'],
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
      $self->{$key} = $arg;
    }
    return $self->{$key};
  }
}


package Ctypes::Type;

=head1 INSTANTIATION

=over

=item c_X<lt>typeX<gt>(x)

=back

The basic Ctypes::Type objects are almost always created with the
correspondingly named functions exported by default from Ctypes.
All basic types are objects of type Ctypes::Type::Simple. You could
call the class constructor directly if you liked, passing a typecode
as the first argument followed by any initialisers, but the named
functions put in the appropriate typecode for you and are normally
more convenient.

A Ctypes::Type object represents a variable of a certain C type. If
uninitialised, the value defaults to zero. You can use uninitialised
instances to find out information about the various types (see list of
accessor methods below).

After creation, you can manipulate the value stored in a Type object
in any of the following ways:

=over

=item $obj->val = 100;

=item $obj->val(100);

=item $obj->(100);

=back

The actual data which will be passed to C is held in
L<packed|perlfunc/"pack"> string form in an internal attribute called
C<{_data}>. Note the underscore! The methods above do all the necessary
validation of values assigned to the object for you, as well as packing
the data into a format C understands. You cannot set C<{_data}> directly
(although you can examine it through its accessor should you ever feel
like looking at some unintelligible gibberish).

=head1 METHODS

Apart from its value, each Ctypes::Type object holds various pieces of
information about itself, which you can access via the methods below.
Most of these are 'getters' only (changing the 'size' of a particular
int-type object is meaningless, and may well confuse Functions and other
internal users of Type objects).

=over

=item _data

Accessor returning the L<pack|perlfunc/"pack">ed value of the object.
Cannot be set directly (use C<val()>).

=item alignment

Accessor returning the alignment of the data in the object. This feature
is NOT YET IMPLEMENTED. I imagine though that alignment will be something
you're most likely to want to tinker with for aggregate data structures
(Array, Struct, Union). I'm not sure if there's cause to make it settable
on an object by object basis. You can be sure it will default to the
sensible choice for your system though.

=item allow_overflow

B<Mutator> setting and/or returning a flag (1 or 0) indicating whether
this particular object is allowed to overflow. Defaults to 1. Note that
overflows can also be prevented by $Ctypes::Type::allow_overflow_all
being set to 0 (see the class method L</allow_overflow_all>).

=item name

Accessor returning the 'name' of the Type instance (c_int, c_double, etc.).
Since all basic types are Ctypes::Type::Simple objects, this is how you
find out what kind of type you actually have.

=item size

Accessor returning the size in bytes on your system of C type represented
by the Type object (I<not> the size of the Perl Type object itself).

=item typecode

Accessor returning the 'typecode' of Type instance. A typecode is a
1-character string used internally for representing different C types,
which might be useful for various things.

=back

=cut

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

=head1 CLASS FUNCTIONS

=over

=item Array ( I<LIST> ) or new Array( TYPE, ARRAYREF )

Create a L<Ctypes::Type::Array> object. See the relevant documentation
for more information.

=cut

sub Array {
  return Ctypes::Type::Array->new(@_);
}
{
no strict 'refs';
*{"Ctypes::Array"} = \&Ctypes::Type::Array;
}
push @_allnames, 'Array';

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

package Ctypes::Type::Field;
use Ctypes::Type;
our @ISA = qw(Ctypes::Type);

package Ctypes::Type::Union;
use Ctypes::Type;
our @ISA = qw(Ctypes::Type);

sub new {
  
my ($class, $fields) = @_;
  my $size = 0;
  for (@$fields) {
    # XXX convert fields to ctypes
    my $fsize = $_->{size}; 
    $size = $fsize if $fsize > $size;
    # TODO: align!!
  }
  return bless { fields => $fields, size => $size, address => 0 }, $class;
}

package Ctypes::Type::Struct;
use Ctypes::Type;
our @ISA = qw(Ctypes::Type);

sub new {
  my ($class, $fields) = @_;
  my $size = 0;
  for (@$fields) { # arrayref of ctypes, or just arrayref of paramtypes
    # XXX convert fields to ctypes
    my $fsize = $_->{size};
    $size += $fsize;
    # TODO: align!!
  }
  return bless { fields => $fields, size => $size, address => 0 }, $class;
}

1;
