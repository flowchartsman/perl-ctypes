package Ctypes::Function;

use strict;
use warnings;
use Ctypes;
use overload '&{}' => \&_call_overload;

# Public functions are defined in POD order
sub new;
sub update;
sub abi_default;
sub validate_abi;
sub validate_types;

=head1 NAME

Ctypes::Function - Object-oriented access to C function calls

=head1 VERSION

Version 0.002

=head1 SYNOPSIS

    use Ctypes::Function;

    $toupper = Ctypes::Function->new( "-lc", "toupper", "cii" );
    $result = $func->(ord("y"));

    # or
    $toupper = Ctypes::Function->new({ lib    => 'c',
                                       name   => 'toupper',
                                       atypes => 'i',
                                       rtype  => 'i' } );
    $result = chr($toupper->(ord("y")));

=head1 DESCRIPTION

Ctypes::Function abstracts the raw Ctypes::call() API

=cut

# TODO:
# - namespace install feature from P5NCI

################################
#   PRIVATE FUNCTIONS & DATA   #
################################

# For which members will AUTOLOAD provide mutators?
my $_setable = { name => 1, sig => 1, abi => 1, rtype => 1, lib => 1 };
# For abi_default():
my $_default_abi = ($^O eq 'MSWin32' ? 's' : 'c' );

sub _get_args (\@\@;$) {
  my $args = shift;
  my $want = shift;
  my $ret = {};

  if (ref($args->[0]) eq 'HASH') {
    # Using named parameters.
    for(@{$want}) {
      $ret->{$_} = $args->[0]->{$_} }
  } else {
    # Using positional parameters.
    for(my $i=0; $i <= $#{$args}; $i++ ) {
      $ret->{$want->[$i]} = $args->[$i] }
  }
  return $ret;
}

sub _call_overload {
  my $self = shift;
  return sub { _call($self, @_) };
}

sub _call {
  my $self = shift;
  my @args = @_;
  my $retval;
  die "Function needs a signature (even '' must be defined)"
    unless defined $self->sig;
  #print Dumper( $self );
  # Constructing / validating full sig to pass to Ctypes::call
  validate_types($self->sig);
  my $whole_sig;
  if ($self->abi) {
    validate_abi($self->abi); # chops to 1 char & checks letters
    if ($self->rtype) {
      # validate_types also used for sig so must chop here
      $self->rtype = substr($self->rtype, 0, 1);
      validate_types($self->rtype);
      $whole_sig = $self->abi . $self->rtype . $self->sig;
    } else {
      $whole_sig = $self->abi . $self->sig;
    }
  } elsif( $self->rtype ) {
    warn("Got rtype but no abi; using system default");
    $self->abi = abi_default();
    $whole_sig = $self->abi . $self->rtype . $self->sig;
  } 
  if (!defined $self->abi and !defined $self->rtype) { # for clarity
    $whole_sig = $self->sig; 
  }
  $retval = Ctypes::call( $self->func, $whole_sig, @args );
  return $retval;
}

sub AUTOLOAD {
  our $AUTOLOAD;
  if( $AUTOLOAD =~  /.*::(.*)/ ) {
    return if $1 eq 'DESTROY';
    my $mem = $1; # member
    no strict 'refs';
    *$AUTOLOAD = sub { 
      my $self = shift;
      if($_setable->{$mem}) {
        if(@_) {
          return $self->{$mem} = $_[0];
        }
        if( defined $self->{$mem} ) {
          return $self->{$mem};
        } else { return undef; }
      } else {
        if(@_) {
          warn("$mem not setable"); }
        if( defined $self->{$mem} ) {
          return $self->{$mem}; 
        } else { return undef; }
      }
    };
    goto &$AUTOLOAD;
  }
}

################################
#       PUBLIC FUNCTIONS       #
################################

=head1 PUBLIC SUBROUTINES/METHODS

Ctypes::Function's methods are designed for flexibility.

=head2 new ( lib, name, [ sig, [ abi, [ rtype, [ func ]]]] )

or hash-style: new ( { param => value, ... } )

Ctypes is happy to leave as much as possible until later, where it makes
sense. The only thing on which a Function object insists is knowing
where to find the C function it represents. This means that upon
instantiation, you must supply B<either> both the library and the name
of the function, B<or> a reference to the function itself. Further, to
avoid confusion, the C<func> reference is immutible after instantiation:
if you want a new function, make a new Function object.

Most of a Function's attributes can be accessed with a getter like this:
C<$obj->attr>, and set with a setter like this C<$obj->attr('value')> 
(apart from C<func>, which only has the getter). Each attribute's precise
meanings are explained below.

=over

=item lib

Describes the library in which the target function resides. It can
be one of three things:

=over

=item A linker argument style string, e.g. '-lc' for libc. Bear in mind
that on Win32 library name resolution may be a bit sketchy, so you might
want to use another option.

=item A path to a library file (B<unimplemented> as of v0.002).

=item An opaque library reference as returned by DynaLoader.

=back

B<N.B.> Although the L<DynaLoader> docs explicitly say that the references
it returns are to be considered 'opaque', we sneak a little regex on them
to make sure they look like a string of numbers - what a DL reference
normally looks like. This means that yes, you could do yourself a mischief
by passing any string of numbers as a library reference, even though that
would be a Silly Thing To Do.

=item name

The name of the function your object represents. On initialising,
it's used internally by L<DynaLoader> as the function symbol to look for
in the library given by C<lib>. It can also be useful for remembering
what an object does if you've assigned it to a non-intuitively named
reference. In theory though it's never looked at after initialization
(and not even then if you supply a C<func> reference) so you could
store any information you want in there.

=item sig

A string of letters representing the function signature, in the
same format as L<Ctypes::call>. In a Function object, it can represent the
full signature (like Ctypes::call), or just the return value + arguments,
or just the arguments, depending on whether C<abi> and/or C<rtype> have
been defined. See the note L</"abi, rtype and sig"> below.

=item abi

This is a single character representing the desired Application Binary
Interface for the call, here used to mean the calling convention. It can
be 'c' for C<cdecl> or 's' for C<stdcall>. Other values will fail.
'f' for C<fastcall> is for now used implicitly with 'c' on WIN64 
and UNIX64 architectures, not yet on 64bit libraries. 
See note L</"abi, rtype and sig"> below.

=item rtype

A single character representing the return type of the function, using
the same notation as Ctypes::call. See note L</"abi, rtype and sig">
below.

=item func

An opaque reference to the function which the object represents. Can be
accessed after initialisation, but cannot be changed.

=back

=head3 C<abi>, C<rtype> and C<sig>

For the short of time:

=over

=item If neither C<abi> nor C<rtype> are defined (as is the usual case),
C<sig> will be taken to include everything: the ABI, the return type, and
the parameter list, in that order.

=item If only C<abi> is set, C<sig> will be taken to include the other
two attributes, return type and parameter list, in that order.

=item If only C<rtype> is set, C<abi> will be defined I<for you>, to the
system default. C<sig> will be taken to include just the parameter
list, just like if you had defined both C<rtype> and C<abi> yourself. It
is B<not> possible for C<sig> to represent only the ABI and parameter
list.

=back

The simplest way to use a Function is to specify the ABI, return type
and parameters all in one string stored in C<$obj->sig>. However, there
may be times when you want to change the set ABI or return type
of your object after its creation. For these occasions, you can set
those attributes separately with their eponymous mutator methods. The
important thing to consider is that I<the definedness of> C<$obj->abi>
I<and> C<$obj->rtype> I<change the way> C<$obj->sig> I<will be
interpreted>.

This is pretty much common sense: if you have taken the time to specify
C<abi> and C<rtype> separately, then C<sig> must only represent the
parameter list. Where there may be uncertainty however is when only
one of C<abi> and C<rtype> is provided. The rules above describe the
logic used in those instances.

=cut

sub new {
  my ($class, @args) = @_;
  # default positional args are library, function name, function signature
  # will never make sense to pass func address or lib address positionally
  my @attrs = qw(lib name sig abi rtype func);
  our $ret  =  _get_args(@args, @attrs);

  # Just so we don't have to continually dereference $ret
  my ($lib, $name, $sig, $abi, $rtype, $func)
      = (map { \$ret->{$_}; } @attrs );

  if (!$$func && !$$name) { die( "Need function ref or name" ); }

  if (!$$func) {
    if (!$$lib) {
      die( "Can't find function without a library!" );
    } else {
      do {
        $$lib = Ctypes::load_library( $$lib );
      } unless ($$lib =~ /^[0-9]$/); # looks like dl_load_file libref
    }
    $$func = Ctypes::find_function( $$lib, $$name );
  }
  return bless $ret, $class;
}

=head2 update(name, sig, abi, args)

Also hash-style: update({ param => value, [...] })

C<update> provides a quick way of changing many attributes of a function
all at once. Only the function's C<lib> and C<func> references cannot
be updated (because that wouldn't make any sense).

=cut

sub update {
  my $self = shift;
  my @args = @_;
  my @want = qw(name sig abi rtype);
  my $update_self = _get_args(@args, @want);
  for(@want) {
    if(defined $update_self->{$_}) {
      $self->{$_} = $update_self->{$_};
    }
  }
  return $self;
}

=head2 abi_default( [ 'c' | $^O ] );

Also hash-style: abi_default( [ { abi => <char> | os => $^O } ] )

This class method is used to return the default ABI (calling convention)
for the current system. It can also be used to change the 'default' for
your script, either through passing a specific ABI code ( 'c' for C<cdecl>
or 's' for C<stdcall> ) or by specifying an operating system type. The OS
must be specified using a string returned by $^O on the target system.

=cut

sub abi_default {
  my $arg = shift;
  if( !defined $arg ) {
    return $_default_abi;
  }
  # What kind of argument did we get?
  if(ref($arg) eq 'SCALAR') {
    if( ($arg eq 's') or ($arg eq 'MSWin32') ) { 
      $_default_abi = 's'; return 1; }
    if( ($arg eq 'c') or ($arg eq 'linux') or ($arg eq 'cygwin') ) { 
      $_default_abi = 'c'; return 1; }
    die("abi_default: unrecognised ABI code or OS identifier");
  } elsif(ref($arg) eq 'HASH') {
    if( (defined $arg->{abi} and $arg->{abi} eq 's') or 
        (defined $arg->{os} and $arg->{os} eq 'MSWin32') ) {
      $_default_abi = 's'; return 1;
    }
    if( (defined $arg->{abi} and $arg->{abi} eq 'c') or
        (defined $arg->{os} and $arg->{os} eq 'linux') or 
        (defined $arg->{os} and $arg->{os} eq 'cygwin') ) {
      $_default_abi = 'c'; return 1;
    }
  }
  die("abi_default: unrecognised ABI code or OS identifier");
}

=head2 validate_abi

TODO

=head2 validate_types

TODO

=cut

1;
