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

package Ctypes::Type::value;
use Carp;

our $DEBUG = 0;
my $owner;

sub protect ($) {
  ref shift or return undef;
  my($cpack, $cfile, $cline, $csub) = caller(0);
  print "# In protect()\n" if $DEBUG > 1;
  if( $DEBUG > 3 ) {
    print "\t\$cpack: $cpack\n";
    print "\t\$cfile: $cfile\n";
    print "\t\$cline: $cline\n";
    print "\t\$csub: $csub\n";
  }
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
  print "In STORE called by " . (caller(1))[3] . "\n" if $DEBUG > 1;
  protect $self or carp("Unauthorised access of val attribute") && return undef;
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
  # XXX Would you ever want to store an object/reference as the value
  # of a type? What would get pack()ed in the end?
        croak("Can only store native types or Ctypes compatible objects");
      }
    }
  }
  my $typecode = $owner->{_typecode_};
  print "    Got $arg as arg\n" if $DEBUG > 32;
  croak("c_int can only be assigned a single value") if @_;
  # return 1 on success, 0 on fail, -1 if numeric but out of range
  my $is_valid = Ctypes::_valid_for_type($arg,$typecode);
  if( $is_valid < 1 ) {
    print "\t$arg wasn't valid type\n" if $DEBUG > 3;
    no strict 'refs';
    if( ($is_valid == -1)
        and not ( $owner->allow_overflow
        || $owner->allow_overflow_class
        || $Ctypes::Type::allow_overflow_all ) ) {
      croak( "Value out of range for c_int: $arg");
    } else {
    my $temp = Ctypes::_cast($arg,$typecode);
    if( $temp && Ctypes::_valid_for_type($temp,$typecode) ) {
      $arg = $temp;
    } else {
      croak("Unreconcilable argument for type '$typecode': $arg");
    }
  }
  $owner->{_as_param_} = pack( $typecode, $arg );
  $$self = $arg;
  print "    STORE ret: " . $$self . "\n" if $DEBUG > 1;
  return $$self;
}

sub FETCH {
  print "FETCHing, called by " . (caller(1))[3] . "\n" if $DEBUG > 1;
  my $self = shift;
  print "My \$self: $$self\n" if $DEBUG > 1;
  return $$self;
}

package Ctypes::Type::c_int;
use Ctypes;
use Carp;
use Data::Dumper;
use Devel::Peek;
our @ISA = ("Ctypes::Type");
use fields qw(alignment name _typecode_ size val _as_param_);
use overload '0+'  => \&_num_overload,
             '+'   => \&_add_overload,
             '-'   => \&_subtract_overload,
             '&{}' => \&_code_overload,
             '%{}' => \&_hash_overload,
             fallback => TRUE;
             # XXX Multiplication will have to be overridden
             # to implement Python's Array contruction with "type * x"?
use subs qw|new val|;

our $DEBUG = 0;
{
  my $allow_overflow_class = 1;
  sub allow_overflow_class {
    my $self = shift;
    my $arg = shift;
    if( @_ or ( $arg and $arg != 1 and $arg != 0 ) ) {
      croak("Usage: allow_overflow(x) (1 or 0)");
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
  my($cpack, $cfile, $cline, $csub) = caller(0);
  if( $cpack !~ /^Ctypes::/ 
      or $cfile !~ /Ctypes\// ) {
    carp("Unauthorized direct Type attribute access!");
    return {};
  }
  return shift;
}

sub _code_overload { 
  print "In ovlVal...\n" if $DEBUG > 2;
  if( $DEBUG > 3 ) {
    for(@_) { print "\targref: " . ref($_)  .  "\n"; }
  }
  my $self = shift;
  return sub { val($self, @_) };
}

sub new {
  print "In c_int::new...\n" if $DEBUG > 1;
  print Dumper( @_ ) if $DEBUG > 3;
  my $class = shift;
  my $arg = shift;
  my $self = { val => 0, _typecode_ => 'i', allow_overflow => 0, alignment => 0,
               name=> 'c_int', _as_param_ => '', size => Ctypes::sizeof('i') };
  bless $self => $class;
  $arg = 0 unless $arg;
  print "    \$arg: $arg\n" if $DEBUG > 2;
  $self->{obj} = tie $self->{val}, "Ctypes::Type::value", $self;
  $self->{val} = $arg;
  if( $DEBUG > 2 ) {
    if( $arg ) { print "    c_int::new ret: " . $self. "\n"; }
    else { print "    c_int::new returning...\n"; }
  }
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
my %access = ( _data => ['_as_param_',undef],
               typecode => ['_typecode_',\&Ctypes::sizeof],
             );
for my $func (keys(%access)) {
  no strict 'refs';
  my $key = $access{$func}[0];
  *$func = sub {
    my $self = shift;
    my $arg = shift;
    croak("The $key method only takes one argument") if @_;
    if($access{$func}[1] and $arg){
      eval{ $access{$func}[1]->($arg); };
      if( $@ ) {
        croak("Invalid argument for $key method: $@");
      }
    }
    $self->{$key} = $arg if $arg;
    $self->{$key};
  }
}


sub allow_overflow {
  my $self = shift;
  my $arg = shift;
  if( @_ or ( $arg and $arg != 1 and $arg != 0 ) ) {
    croak("Usage: allow_overflow(x) (1 or 0)");
  }
  unless( ref($self) ) {  # object method
    croak("allow_overflow is an object method; maybe you wanted allow_overflow_class?");
  }
  $self->{allow_overflow} = $arg if $arg;
  return $self->{allow_overflow};
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
