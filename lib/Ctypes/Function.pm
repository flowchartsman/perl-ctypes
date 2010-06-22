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
                                       sig    => 'i',
                                       rtype  => 'i' } );
    $result = $toupper->(ord("y"));

=head1 DESCRIPTION

Ctypes::Function objects abstracts the raw Ctypes::call() API.

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
  my @sig = split(//, $self->sig);
  $sig[0] = $self->abi if defined $self->abi;
  $sig[1] = $self->rtype if defined $self->rtype;
  $self->sig( join( '', @sig) );
  $retval = Ctypes::call( $self->func, $self->sig, @args );
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

=item A linker argument style string, e.g. '-lc' for libc.
 
For Win32, mingw and cygwin special rules are used:
"c" resolves on Win32 to msvcrt<ver>.dll.
-llib will probably find an import lib ending with F<.a> or F<.dll.a>), 
so C<dllimport> is called to find the DLL behind. 
DLL are usually versioned, import libs not, 
so specifying the unversioned library name will find the most recent DLL.

=item A path to a shared library.

=item A L<Ctypes::Library> object.

=item A library handle as returned by DynaLoader, or the C<_handle> 
property of a Ctypes::Library object, such as C<CDLL>.
$lib = CDLL->c; $lib->{_handle}.

=back

B<N.B.> Although the L<DynaLoader> docs explicitly say that the
handles ("references") it returns are to be considered 'opaque', we
check with a regex to make sure they look like a string of
numbers - what a DL handle normally looks like. This means that
yes, you could do yourself a mischief by passing any string of numbers
as a library reference, even though that would be a Silly Thing To Do.
Thanksfully there are no dll's consisting only of numbers, but if so, 
add the extension.

=item name

The name of the function. On initialising, it's used internally by
L<DynaLoader> as the function symbol to look for in the library given
by C<lib>. It can also be useful for remembering what an object does
if you've assigned it to a non-intuitively named reference. In theory
though it's never looked at after initialization (and not even then if
you supply a C<func> reference) so you could store any information you
want in there.

=item sig

A string of letters representing the function signature, in the
same format as L<Ctypes::call>, i.e. first character denotes the abi,
second character denotes return type, and the remaining characters
denote argument types: <abi><rtype><argtypes>. If the C<abi> or
C<rtype> attributes are defined separately, they are substituted
in to the C<sig> at call time (and C<sig> is redefined accordingly.)

=item abi

This is a single character representing the desired Application Binary
Interface for the call, here used to mean the calling convention. It can
be 'c' for C<cdecl> or 's' for C<stdcall>. Other values will fail.
'f' for C<fastcall> is for now used implicitly with 'c' on WIN64 
and UNIX64 architectures, not yet on 64bit libraries.

=item rtype

A single character representing the return type of the function, using
the same notation as L<Ctypes::call>.

=item func

An opaque reference to the function which the object represents. Can be
accessed after initialisation, but cannot be changed.

=back

=cut

sub new {
  my ($class, @args) = @_;
  # default positional args are library, function name, function signature.
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
      if (ref $lib ne 'SCALAR' and $$lib->isa("Ctypes::Library")) {
	$$lib = $$lib->{_handle};
	$ret->{abi} = $$lib->{_abi} unless $ret->{abi};
      }
      die "No library $$lib found" unless $$lib;
      if ($$lib and $$lib !~ /^[0-9]+$/) { # need a number, a dl_load_file handle
        my $newlib = Ctypes::load_library( $$lib );
	die "No library $$lib found" unless $newlib;
	$$lib = $newlib;
      }
      $$func = Ctypes::find_function( $$lib, $$name );
    }
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
  if( ($arg eq 's') or ($arg->{os} eq 'MSWin32') ) {
    $_default_abi = 's'; return 's';
  } else {
    $_default_abi = 'c'; return 'c';
  }
}

=head2 validate_abi

TODO

=head2 validate_types

TODO

=cut

1;
