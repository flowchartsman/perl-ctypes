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

package Ctypes::Type::c_int;
use Carp;
use Data::Dumper;
use Devel::Peek;
our @ISA = ("Ctypes::Type");
use fields qw(alignment name packcode size val data);
use overload q("") => \&stringOvl,
             '0+'  => \&numOvl,
             '&{}' => \&ovlSTORE,
             fallback => TRUE;
our $DEBUG = 0;
 
sub stringOvl : lvalue { print "In stringOvl with " . ($#_ + 1) . " args!\n" if $DEBUG == 1;
                   print "    stringOvl returning: " . ${$_[0]->{obj}->{val}} . "\n" if $DEBUG == 1;
                   return shift->{obj}->{val};
}

sub numOvl : lvalue { print "In numOvl with $#_ args!\n" if $DEBUG == 1;
                   print "    numOvl returning: " . $_[0]->{obj}->{val} if $DEBUG == 1;
                   return shift->{obj}->{val};
}


sub new {
  print "In c_int::new...\n" if $DEBUG == 1;
  my $class = shift;
  my $arg = shift;
  croak("Usage: new $class($arg)") if @_;
  my $ret = { val => 0, packcode => 'i', obj => '',
              data => '', size => Ctypes::sizeof('i') };
  bless $ret, $class;
  $ret->{obj} = tie $ret->{val}, "Ctypes::Type::c_int", $ret;
  $ret->STORE($arg);
  print "    c_int::new ret: " . $ret . "\n" if $DEBUG == 1;
  return $ret; 
}

sub TIESCALAR {
  print "In TIESCALAR...\n" if $DEBUG == 1;
  my $class = shift;
  my $self = shift;
  bless $self, $class;
}

sub ovlSTORE { 
  print "In ovlSTORE...\n" if $DEBUG == 1;
  if( $DEBUG == 1 ) {
    for(@_) { print "\targref: " . ref($_)  .  "\n"; }
  }
  my $self = shift;
  return sub { STORE($self, @_) };
}


sub STORE {
  print "In STORE...\n" if $DEBUG == 1;
  my $self = shift;
  my $arg = shift;
  croak("c_int can only be assigned a single value") if @_;
  croak("c_int can only be assigned an integer")
    unless Ctypes::realtype($arg,$self->{packcode});
  $self->{obj}->{data} = pack( $self->{packcode}, $arg );
  print "    STORE ret: " . $self->{obj}->{data} . "\n" if $DEBUG == 1;
  return $self->{obj}->{data};
}

sub FETCH {
  print "In FETCH called by " . caller() . "\n" if $DEBUG == 1;
  my $self = shift;
  my $valnow = $self->{obj}->{data};
  my $ret = unpack( 'i', $valnow );
  print "    FETCH ret: " . $ret . "\n" if $DEBUG == 1;
  return $ret;
}

package Ctypes::Type;

sub c_int {
  return Ctypes::Type::c_int->new(@_);
}

=head1 METHODS

=over

=item new Ctypes::Type (pack-char, c_type-name) 

Create a simple Ctypes::Type instance. This is almost always 
called by the global c_X<lt>typeX<gt> functions.

A Ctypes::Type object holds information about simple and aggregate types, 
i.e. unions and structs, but also about actual external values, e.g. 
function arguments and return values.

Each type is defined as function returning a c_type object.

Each c_type object holds the pack-style char, the c name, the size, 
the alignment and the address if used.

=cut

package Ctypes::Type::Simple;
use Ctypes::Type;
our @ISA = qw(Ctypes::Type);

sub new {
  my ($class, $pack, $name) = @_;
  my $size = sizeof($pack); # a xs function
  return bless { pack => $pack, name => $name, 
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
