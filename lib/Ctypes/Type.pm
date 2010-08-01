package Ctypes::Type;
# always loaded and all c types are exported.


use Carp;
use Ctypes;
require Exporter;
our @ISA = ("Exporter");
use constant USE_PERLTYPES => 1; # so far use only perl pack-style types, 
                                 # not the full python ctypes types
our @EXPORT_OK = qw(&c_int);

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

package Ctypes::Type::c_int;
use Carp;
use Data::Dumper;
use Devel::Peek;
our @ISA = ("Ctypes::Type");
use fields qw(alignment name typecode size val _as_param_);
use overload q("") => \&string_overload,
             '0+'  => \&num_overload,
             '&{}' => \&code_overload,
             fallback => TRUE;
use subs qw|new val|;

our $DEBUG = 0;
our $allow_overflow_cint = 1;

# XXX do need to tie self->{val} to get lvalue behaviour?
# is such behaviour even wanted? 
sub string_overload { print "In stringOvl with " . ($#_ + 1) . " args!\n" if $DEBUG == 1;
                   print "args 2 and 3: " . $_[1] . " " . $_[2] . "\n" if $DEBUG == 1;
                   print "    stringOvl returning: " . ${$_[0]->{val}} . "\n" if $DEBUG == 1;
                   return shift->{val};
}

sub num_overload { print "In numOvl with $#_ args!\n" if $DEBUG == 1;
                   print "    numOvl returning: " . $_[0]->{val} . "\n" if $DEBUG == 1;
                   return shift->{val};
}

sub code_overload { 
  print "In ovlVal...\n" if $DEBUG == 1;
  if( $DEBUG == 1 ) {
    for(@_) { print "\targref: " . ref($_)  .  "\n"; }
  }
  my $self = shift;
  return sub { val($self, @_) };
}

sub new {
  print "In c_int::new...\n" if $DEBUG == 1;
  my $class = shift;
  my $arg = shift;
  my $self = { val => 0, typecode => 'i', overflow => 0, alignment => 0,
               name=> 'c_int', _as_param_ => '', size => Ctypes::sizeof('i') };
  bless $self, $class;
  $self->val($arg); # !$arg is handled by val()
  if( $DEBUG == 1 ) {
    if( $arg ) { print "    c_int::new ret: " . $self. "\n"; }
    else { print "    c_int::new returning...\n"; }
  }
  return $self;
}

sub val {
  print "In val()...\n" if $DEBUG == 1;
  my $self = shift;
  my $arg = shift;
  $arg = 0 unless defined $arg;
  croak("c_int can only be assigned a single value") if @_;
  # return 1 on success, 0 on fail, -1 if numeric but out of range
  my $is_valid = Ctypes::valid_type_value($arg,$self->{typecode});
  if( $is_valid < 1 ) {
    print "\t$arg wasn't valid type\n" if $DEBUG == 1;
    if( ($is_valid == -1) and not ( $self->{overflow}
      || $allow_overflow_cint || $allow_overflow_all ) ) {
      croak( "Value out of range for c_int: $arg");
    } else {
    # This is not a true C cast. It will always return
    # _something_ if it recognises the typecode
    my $temp = Ctypes::_cast_value($arg,$self->{typecode});
    # XXX check $temp here again in case typecode was invalid?
    $arg = $temp;
    }
  }
  $self->{_as_param_} = pack( $self->{typecode}, $arg );
  $self->{val} = $arg;
  print "    val() ret: " . $self->{_as_param_} . "\n" if $DEBUG == 1;
  return $self->{val};
}

package Ctypes::Type;

sub c_int {
  return Ctypes::Type::c_int->new(@_);
}

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

package Ctypes::Type::Simple;
use Ctypes::Type;
our @ISA = qw(Ctypes::Type);

sub new {
  my ($class, $type, $name) = @_;
  my $size = sizeof($type); # a xs function
  return bless { pack => $type, name => $name, 
		 size => $size, address => 0, 
		 alignment => 0 }, $class;
}

package Ctypes::Type;

# define the simple c_types
#my %_defined;
#for my $k (keys %$_types) {
#  my $name = $_types->{$k};
#  unless ($_defined{$name}) {
#    no strict 'refs';
#    eval "sub $name { Ctypes::Types::Simple->new(\"$k\", \"$name\"); }";
#    # *&{"Ctypes::$name"} = *&name;
#    $_defined{$name} = 1;
#  }
#}
#our @_allnames = keys %_defined;

=item sizeof()

B<Method> of a Ctypes::Type object, returning its size. This size is
that of the represented C type, calculated at instantiation.

=cut

sub sizeof {
  return shift->{size};
}

#sub addressof {
#  return shift->{address};
#}

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
