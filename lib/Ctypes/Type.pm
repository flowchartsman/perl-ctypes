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
our $allow_overflow_all = 0;

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

my $owner;

sub protect ($) {
  ref shift or return undef;
  my($cpack, $cfile, $cline, $csub) = caller(0);
  if( $cpack ne __PACKAGE__ 
      or $cfile ne __FILE__ ) {
    return undef;
  }
  return 1;
}
 
sub TIESCALAR {
  my $class = shift;
  $owner = shift;
  return bless \my $self => $class;
}

sub STORE {
  my $self = shift;
  protect $self
    or carp("Unauthorised access of val attribute") && return undef;
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
        croak("Can only store native types or Ctypes compatible objects");
      }
    }
  }
  my $typecode = $owner->{_typecode_};
  croak("Simple Types can only be assigned a single value") if @_;
  # return 1 on success, 0 on fail, -1 if (numeric but) out of range
  my $is_valid = Ctypes::_valid_for_type($arg,$typecode);
  if( $is_valid < 1 ) {
    no strict 'refs';
    if( ($is_valid == -1)
        and not ( $owner->allow_overflow
        || $owner->allow_overflow_class
        || $Ctypes::Type::allow_overflow_all ) ) {
      croak( "Value out of range for " . $owner->{name} . ": $arg");
    } else {
      my $temp = Ctypes::_cast($arg,$typecode);
      if( $temp && Ctypes::_valid_for_type($temp,$typecode) ) {
        if( $is_valid == -1 ) {
          carp("Argument $arg overflows for type " . $owner->{name}
                . ". Value now " . $temp );
        }
        $arg = $temp;
      } else {
        croak("Unreconcilable argument for type '$typecode': $arg");
      }
    }
  }
  no warnings;
  $owner->{_as_param_} = pack( $typecode, $arg );
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
use overload '0+'  => \&_num_overload,
             '+'   => \&_add_overload,
             '-'   => \&_subtract_overload,
             '&{}' => \&_code_overload,
             '%{}' => \&_hash_overload,
             fallback => 'TRUE';
             # TODO Multiplication will have to be overridden
             # to implement Python's Array contruction with "type * x"???

{
  my $allow_overflow_class = 1;
  sub allow_overflow_class {
# ??? This could be improved; could still be called as a class method
# with an object instead of a 1 or 0 and user would not be notified
    my $self = shift if ref($_[0]);
    my $arg = shift;
    if( @_ or ( defined($arg) and $arg != 1 and $arg != 0 ) ) {
      croak("Usage: allow_overflow_class(x) (1 or 0)");
    }
    $allow_overflow_class = $arg if $arg;
    return $allow_overflow_class;
  }
}

sub _num_overload { return shift->{val}; }

sub _add_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{val} + $y; }
    else { $ret = $y->{val} + $x; }
  } else {           # += etc.
    $x->val($x->{val} + $y);
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
    $x->val($x->{val} - $y);
    $ret = $x;
  }
  return $ret;
}

sub _hash_overload {
  my($cpack, $cfile) = caller(0);
  if( $cpack !~ /^Ctypes/
      or $cfile !~ /Ctypes\// ) {
    carp("Unauthorized direct Type attribute access!");
    return {};
  }
  return shift;
}

sub _code_overload { 
  my $self = shift;
  return sub { val($self, @_) };
}

sub new {
  my $class = shift;
  my $typecode = shift;
  my $arg = shift;
  my $self = { _as_param_      => '',
               _typecode_      => $typecode,
               val             => 0,
               address         => undef,
               name            => $_types->{$typecode},
               size            => 0,
               alignment       => 0,
               allow_overflow  => 0,
             };
  bless $self => $class;
  $self->{size} = Ctypes::sizeof($self->{_typecode_});
  $arg = 0 unless $arg;
  tie $self->{val}, "Ctypes::Type::Simple::value", $self;
  $self->{val} = $arg;
# XXX Unimplemented! Must come after setting val;
#  $self->{address} = Ctypes::addressof($self);
  return $self;
}

# val can't go in the loop below simply because
# it's an lvalue. To make them all lvalue would
# require more tie'ing for validity checks.
sub val : lvalue {
  my $self = shift;
  my $arg = shift;
  $self->{val} = $arg if $arg;
  $self->{val};
}

#
# Accessor generation
#
my %access = ( 
  _data             => ['_as_param_',undef],
  typecode          => ['_typecode_',\&Ctypes::sizeof],
  allow_overflow =>
    [ 'allow_overflow',
      sub {if( $_[0] != 1 and $_[0] != 0){return 0;}else{return 1;} } ],
  alignment         => ['alignment',undef],
  name              => ['name',undef],
# Users ~could~ modify size, but only of they delight in the meaningless.
  size              => ['size',undef],
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
    $self->{$key} = $arg if $arg;
    $self->{$key};
  }
}


package Ctypes::Type;

=head1 METHODS

=over

=item new Ctypes::Type (type-code, c_type-name) 

Create a simple Ctypes::Type instance. This is almost always 
called by the global c_X<lt>typeX<gt> functions.

A Ctypes::Type object holds information about simple and aggregate types, 
i.e. unions and structs, but also about actual external values, e.g. 
function arguments and return values.

Each type is defined as function returning a c_type object.

Each c_type object holds the type-code char, the c name, the size, 
the alignment and the address if used.

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

package Ctypes::Array;
use strict;
use warnings;
use Ctypes;  # which uses Ctypes::Type?

sub new {
  my $class = shift;
  return undef unless $_[0]; # TODO: Uninitialised Arrays? Why??
  my $in = Ctypes::_make_arrayref(@_);
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

=back
=cut
1;
