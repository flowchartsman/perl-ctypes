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
use fields qw(alignment name packcode size val);

sub new {
  print "I'm in c_int::new...\n";
  for(@_) { print "\t$_\n"; }
  my $class = shift;
  my $arg = shift;
  croak("Usage: new $class($arg)") if @_;
  my $ret = { val => 0, packcode => 'i', obj => '' };
  $ret->{obj} = tie $ret->{val}, "Ctypes::Type::c_int", $ret;
  $ret->{val} = $arg;
  return  bless $ret, $class; 
}

sub TIESCALAR {
  print "I'm in TIESCALAR...\n";
  for(@_) { print "\t$_\n"; }
  my $class = shift;
  my $self = shift;
  bless $self, $class;
}

sub STORE {
  print "I'm in STORE...\n";
  for(@_) { print "\t$_\n"; }
  my $self = shift;
  my $arg = shift;
  print "\tref(\$self): " . ref($self) . "\n";
  croak("c_int can only be assigned a single value") if @_;
  croak("c_int can only be assigned an integer")
    unless Ctypes::realtype($arg,$self->{packcode});
  $self->{obj}->{data} = pack( $self->{packcode}, $arg );
#  print "\t" . Dumper( $blarg );
#  print "\t" . Dump( $blarg );
  print "\tdata: " . Dumper( $self->{obj}->{data} ) . "\n";
  return $self->{obj}->{data};
}

sub FETCH {
  print "I'm in FETCH...\n";
  print "caller: " . caller() . "\n";
  for(@_) { print "\t$_\n"; }
  my $self = shift;
  print Dumper( $self );
  print "\tref(\$self): " . ref($self) . "\n";
#  my $val = unpack( $self->{packcode}, $self->{obj}->{val} );
  my $valnow = $self->{obj}->{data};
  my $blarg = unpack( 'i', $valnow );
  print "\tvalnow: " . Dumper( $valnow );
  print "\tblarg: " . Dumper( $blarg ) . "\n\n\n";
  return $blarg;
}

package Ctypes::Type;

sub c_int {
  print "I'm in Ctypes::Type::c_int...\n";
  for(@_) { print "\t$_\n"; }
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
