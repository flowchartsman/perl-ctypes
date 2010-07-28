package Ctypes::Function;

use strict;
use warnings;
use Ctypes;
use overload '&{}' => \&_call_overload;
use Scalar::Util;
use Carp;

# Public functions defined in POD order
sub new;
sub update;
sub sig;
sub abi_default;

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
                                       abi    => 'c',
                                       argtypes => 'i',
                                       restype  => 'i' } );
    $result = $toupper->(ord("y"));

=head1 DESCRIPTION

Ctypes::Function objects abstracts the raw Ctypes::call() API.

Functions are also created as methods of DLL objects, such as
C<< CDLL->c->toupper({sig=>"cii"})->(ord "Y") >>, but with DLL's 
the abi is not needed, as it is taken from the library definition.
See L<Ctypes::DLL>.

=cut

# TODO:
# - namespace install feature from P5NCI

################################
#   PRIVATE FUNCTIONS & DATA   #
################################

# Public functions defined alphabetically
sub AUTOLOAD;
sub _call;
sub _call_overload;
sub _form_sig;
sub _get_args;
sub _to_typecodes; 

# For which members will AUTOLOAD provide mutators?
my $_setable = { name => 1, sig => 1, abi => 1, 
		 restype => 1, argtypes => 1, lib => 1,
		 errcheck => 1, callable => 1, ArgumentError => 1};
# For abi_default():
my $_default_abi = ($^O eq 'MSWin32' ? 's' : 'c' );

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

  require Data::Dumper;
  print Data::Dumper::Dumper( @_ );
  my $func = shift;
  my $sig = shift;
  my @args = @_;
  my @argtypes = ();
  my @callargs = ();
  @argtypes = split( //, substr( $sig, 2 ) ) if length $sig > 2;
  for(my $i=0 ; $i<=$#args ; $i++) {
    if( $argtypes[$i] =~ /[dDfFiIjJlLnNqQsSvV]/ and
        not Scalar::Util::looks_like_number($args[$i]) ) {
      die "$i-th argument $args[$i] is no number";
    }
    if( ref($args[$i]) ) {
      if( defined $args[$i]->{_as_parameter} ) {
        $callargs[$i] = $args[$i]->{_as_parameter};
      } else {
    }
  }
  return _call( $func, $sig, @args );

$ob = _get_arg($inargs_index, $name, $defval, @inargs, %kwds);
sub _get_arg (\$\$\$\@\%) {
  my $inargs_index = \shift;
  my $name = shift;
  my $defval = shift;
  my @inargs = shift;
  my %kwds = shift;
  
  my $ret;
  if($inargs_index < scalar @inargs) {
    $ret = $inargs[$inargs_index];
    ++$inargs_index;
    return $ret;
  }
  if( scalar %kwds and ($ret = $kwds{$name} ) {
    ++$inargs_index;
    return $ret;
  }
  if( $defval ) {
    return $defval;
  }
  # XXX These are poor error messages, apparently...
  if( $name ) {
    croak("Required argument '", $name, "' is missing");
  } else {
    croak("Not enough arguments");
  }
  return undef;
}

sub PF_IN () { 1; }
sub PF_OUT () { 2; }
sub PF_INDEF0 () { 4; }

sub _build_callargs (\$\@\%\$\$\$) {
  my $self = \shift;
  my @inargs = \shift;
  my %kwds = \shift;
  my $outmask = \shift;
  my $inoutmask = \shift;
  my $numretvals = \shift;
  my( $actual_args );
  if( !defined $self->{argtypes} or !defined $self->{paramflags} or
      $#{$self->{argtypes}} == 0 ) {
    return \@inargs;
  }
  my $inargs_index = 0;
  my $len = $#{$self->{argtypes}} + 1;

  my @callargs;
  for(my $i = 0; $i < $len, $i++) {
    my $item = $self->{paramflags}->[$i];
    my( $ob, $flag, $name, $defval );

    my $pmflg_length = scalar @$item;
    $flag = $item->[0];
    $name = $item->[1] ? $item->[1] : '';
    $defval = $item->[2] ? $item->[2] : '';
# paramflags flag values:
# 1 = input param
# 2 = output param
# 4 = input param defaulting to 0
    SWITCH: {
      if( $flag == (PF_IN | PF_INDEF0) ) { 
        if( !$defval ) {
          defval = Ctypes::Type::c_int(0);
        }
        @callargs[$i] = $defval;
        last SWITCH;
      }
      if( $flag == (PF_IN | PF_OUT) ) {
        $inoutmask |= ( 1 << $i ); # mark as inout arg
        $numretvals++;
      } # fall through ...
      if( $flag == 0 or $flag == PF_IN ) {
        $ob = _get_arg($inargs_index, $name, $defval, @inargs, %kwds);
        @callargs[$i] = $ob;
        last SWITCH;
      }
      if( $flag == PF_OUT ) {
        if( $defval ) {
          @callargs[$i] = $defval;
          $outmask |= ( 1 << i ); # mark as out arg
          $numretvals++;
          last SWITCH; 
        }
        $ob = $self->{argtypes}[$i];
        unless( $ob ) {
          croak("Missing argtype for outarg");
        }
        if( $ob->{proto} ) {
          # XXX don't understand this logic yet..
          # Means $ob is a Pointer/Array type? So what?
          croak( ref($ob) .
            " 'out' parameter must be passed as default value");
        }
        # XXX This probably needs changed when Array objects worked out
        if( ref($ob) =~ /Ctypes::Type::Array/ ) {
          # PyObject_CallObject(ob,NULL)? Wonder what this returns...
          # Will be annoying to do in C space.
          $ob = $ob->();
        } else {
          # /* Create an instance of the pointed-to type */
          # ob = PyObject_CallObject(dict->proto, NULL);
          $ob = $ob->proto->();
        }
        unless( $ob ) {
          croak("Could not create type of Array / Pointer object (I think...)");
        }
        @callargs[$i] = $ob;
        $outmask |= ( 1 << $i ); # mark as out arg
        $numretvals++;
        last SWITCH;
      }
      croak("paramflag ", $flag, " not yet implemented");
    }
  }
  $actual_args = scalar @inargs + scalar %kwds;
  if( $actual_args != $inargs_index) {
    # /* When we have default values or named parameters, this error
    # message is misleading.  See unittests/test_paramflags.py
    croak("call takes ", $inargs_index, "arguments (", $actual_args, " given)... or maybe a different error");
  }
  return @callargs;
}

sub _call {
  require Data::Dumper;
  print Data::Dumper::Dumper( @_ );
  my $self = shift;
  my @inargs = @_;
  my %kwds = {}; # 'keywords': hash of named arguments
  if( ref($inargs[$#inargs]) eq 'HASH' )
    { %kwds = %{pop @inargs}; }
  my( $outmask, $inoutmask, $numretvals );

  my $result; # XXX what is this? array? ref? success indicator?
  my $pProc; # XXX this is to do with COM objects, not implemented yet!
  my $checker;

  # all arguments taken as references...
  my @callargs = _build_callargs( $self,
                                  @inargs,
                                  %kwds,
                                  $outmask,
                                  $inoutmask,
                                  $numretvals);
  if( scalar @callargs == 1 and not defined $callargs[0]) {
    croak("_build_callargs returned a lemon!");
  }

#ctypes-1.0.2/source/ctypes.h:238
# Currently, CFuncPtr types have 'converters' and 'checker'
# entries in their type dict.  They are only used to cache
# attributes from other entries, which is wrong.

# convertors will be an arrayref?
  if( (my $required = scalar @{$self->{convertors}}) ) {
    my $actual = scalar @callargs;
    if( $self->{abi} eq 'c' ) {
# /* For cdecl functions, we allow more actual arguments
#    than the length of the argtypes tuple.               */
      if( $required > $actual ) {
        croak("This function takes at least ", $required,
          "argument", ($required == 1 ? '' : 's'),
          " (", $actual, " given)");
      }
    } elsif( $required != $actual ) {
        croak("This function takes ", $required,
          "argument", ($required == 1 ? '' : 's'),
          " (", $actual, " given)");
    }
  }

  $result = _CallProc( $pProc,
                       @callargs,
              $^O eq 'MSWin32' ? $iunk : undef,
              $^O eq 'MSWin32' ? $self->{iid} : undef,
                       $self->{flags},
                       $self->{converters},
                       $self->{restype},
                       $checker,
                     );

  my $retval;
  my $sig = $self->_form_sig;
  $retval = Ctypes::call( $self->func, $sig, @args );
  return $retval;
}

sub _call_overload {
  my $self = shift;
  return sub { _call($self, @_) };
}

# Put Ctypes::_call style sig string together from $self's attributes
# Takes Ctypes::Function ($self), returns string scalar
sub _form_sig {
  my $self = shift;
  my @sig_parts;
  $sig_parts[0] = $self->{abi} or abi_default();
  $sig_parts[1] = $self->{restype} or 
    die("Return type not defined (even void must be defined with '_')");
  if(defined $self->{argtypes}) {
    for(my $i = 0; $i<=$#{$self->{argtypes}} ; $i++) {
      $sig_parts[$i+2] = $self->{argtypes}[$i];
    }
  }
  return join('',@sig_parts);
}

# Dealing with either named or positional parameters
# Takes 1) arrayref of params received, 2) positional list of vals wanted
# Returns hashref
sub _get_args (\@\@) {
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

# Interpret Ctypes type objects to type-code enotation
# Takes ARRAY ref of typecodes/Type objects
#    or typecode string
#    or list
# Returns ARRAY ref
sub _to_typecodes {
  my @inputs = @_;
  my $output = [];
  # Make sure we've got the input we want...
  if( ref($inputs[0]) ne 'ARRAY' ) {
    if( $#inputs > 0 ) {      # there is a list of inputs 
      for(@inputs) {
        if( ref =~ /Ctypes::Type/ or !ref ) {
          push @{$output}, $_;
        } else {
          die( "argtypes can only be Type objects or 1-character codes");
        }    
      }
    } else {       # there is only one input  
      if( ref($inputs[0]) =~ /Ctypes::Type/ ) {
        push @{$output}, $inputs[0];
      } elsif( !ref($inputs[0]) ) {
      # We can make list of argtypes from string of type codes...
        $output = [ split(//,$inputs[0]) ];
      } else {
        die( "argtypes can only be Type objects or 1-character codes");
      }
    }
  } else {  # first arg is an ARRAY ref, must be the only arg
    die( "Can't take more args after ARRAY ref" ) if $#inputs > 0;
    $output = $inputs[0];
  }
  # Now canonize Type objs to typecodes
  # and check supplied code characters are valid...
  for( my $i=0; $i<=$#{$output}; $i++ ) {
    if( ref($output->[$i]) =~ /Ctypes::Type/ ) {
      $output->[$i] = $output->[$i]->{typecode};
    } else {
      die( "argtypes can only be Type objects or 1-character codes")
        if ref($output->[$i]);
      Ctypes::sizeof($output->[$i]); # this will croak if not a proper type code
    }
  }
  return $output;
}

################################
#       PUBLIC FUNCTIONS       #
################################

=head1 PUBLIC SUBROUTINES/METHODS

Ctypes::Function's methods are designed for flexibility.

=head2 new ( lib, name, [ sig, [ restype, [ abi, [ argtypes, [ func ]]]]] )

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

C<< $lib = CDLL->c; $lib->{_handle} >>

=back

B<N.B.> Although the L<DynaLoader> docs explicitly say that the
handles ("references") it returns are to be considered 'opaque', we
check with a regex to make sure they look like a string of
numbers - what a DL handle normally looks like. This means that
yes, you could do yourself a mischief by passing any string of numbers
as a library reference, even though that would be a Silly Thing To Do.
Thankfully there are no dll's consisting only of numbers, but if so, 
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

This can be one of two things: First, like with the L<FFI> module and
L<P5NCI>, it can be a string of letters representing the function
signature, in the same format as L<Ctypes::call>, i.e. first character
denotes the abi, second character denotes return type, and the remaining
characters denote argument types: <abi><restype><argtypes>. B<Note> that a
'void' return type should be indicated with an underscore '_'.

Alternatively, more in the style of L<C::DynaLib> and Python's ctypes,
it can be an (anonymous) list reference of the functions argument types.
Types can be specified using single-letter codes, similar (but different)
to Perl's L<pack> notation ('i', 'd', etc.) or with Ctypes's Type objects
(c_uint, c_double, etc.).

This is a convenience for positional parameter passing (as they're simply
assigned to the C<argtypes> attribute internally). These alternatives
mean that you can use positional parameters to create a function like
this:

    $to_upper = Ctypes::Function->new( '-lc', 'toupper', 'cii' );

or like this:

    $to_upper = Ctypes::Function->new( '-lc', 'toupper', [ c_int ], 'i' );

where C<[ c_int ]> is an anonymous array reference with one element, and
with the return type given the fourth positional argument C<'i'>. For
functions with many arguments, the latter syntax may be much more readable.
In these cases the ABI can be given as the fifth positional argument, or
omitted and the system default will be used (which will be what you want
in the vast majority of cases).

=item restype

The result type is often defined as default if the function 
is defined as library method.

The return type of the function can be represented as

=over

=item a single character type-code, using the same notation as L<Ctypes::call>,

=item a Ctype::Type definition, or

=item undef for void,

=back

=item abi

This is a single character representing the desired Application Binary
Interface for the call, here used to mean the calling convention. It can
be 'c' for C<cdecl> or 's' for C<stdcall>. Other values will fail.
'f' for C<fastcall> is for now used implicitly with 'c' on WIN64 
and UNIX64 architectures, not yet on 64bit libraries.

=item argtypes

A string of the type-code characters, or a list reference of the types
of arguments the function takes. These can be specified as type-codes 
('i', 'd', etc.)  or with L<Ctypes>'s Type objects (c_int, c_double,
etc.).

=item func

An opaque reference to the function which the object represents. Can be
accessed after initialisation, but cannot be changed.

=item errcheck

Assign a reference of a perl sub or another callable to this attribute. The
callable will be called with three or more arguments.

=item callable (result, func, arguments)

result is what the foreign function returns, as specified by the
restype attribute.

func is the foreign function object itself, this allows to reuse the
same callable object to check or postprocess the results of several
functions.

arguments is a tuple containing the parameters originally passed to
the function call, this allows to specialize the behaviour on the
arguments used.

The object that this function returns will be returned from the
foreign function call, but it can also check the result value and
raise an exception if the foreign function call failed.

=item ArgumentError

This function is called when a foreign function call cannot convert
one of the passed arguments.

=back

=cut

sub new {
  my ($class, @args) = @_;
  # default positional args are library, function name, function signature.
  # will never make sense to pass func address or lib address positionally
  my @attrs = qw(lib name sig restype abi argtypes func);
  our $ret  =  _get_args(@args, @attrs);

  # Just so we don't have to continually dereference $ret
  my ($lib, $name, $sig, $restype, $abi, $argtypes, $func)
      = (map { \$ret->{$_}; } @attrs );

  if (!$$func && !$$name) { die( "Need function ref or name" ); }

  if(defined $$sig) {
    if(ref($$sig) eq 'ARRAY') {
      $$argtypes = _to_typecodes($$sig) unless $$argtypes;
    } else {
      $$abi = substr($$sig, 0, 1) unless $$abi;
      $$restype = substr($$sig, 1, 1) unless $$restype;
      $$argtypes = [ split(//, substr($$sig, 2)) ]  unless $$argtypes;
    }
  }
  if( defined $$argtypes ) { $$argtypes = _to_typecodes( $$argtypes ); }
  if( defined $$restype ) { $$restype = (_to_typecodes( $$restype ))->[0]; }
  $$restype = 'i' unless defined $$restype;

  if (!$$func) {
    $$lib = '-lc' unless $$lib; #default libc
    if (ref $lib ne 'SCALAR' and $$lib->isa("Ctypes::Library")) {
      $$lib = $$lib->{_handle};
      $$abi = $$lib->{_abi} unless $$abi;
    }
    if ($$lib and $$lib !~ /^[0-9]+$/) { # need a number, a dl_load_file handle
      my $newlib = Ctypes::load_library( $$lib );
      die "No library $$lib found" unless $newlib;
      $$lib = $newlib;
    }
    $$func = Ctypes::find_function( $$lib, $$name );
    die "No function $$name found" unless $$func;
  }
  if (!$$abi) { # hash-style: depends on the lib, default: 'c'
    $$abi = 'c';
    $$abi = 's' if $^O eq 'MSWin32' and $$name =~ /(user32|kernel32|gdi)/;
  } else {
    $$abi =~ /^(cdecl|stdcall|fastcall|c|s|f)$/
      or die "invalid abi $$abi";
    $$abi = 'c' if $$abi eq 'cdecl';
    $$abi = 's' if $$abi eq 'stdcall';
    $$abi = 'f' if $$abi eq 'fastcall';
  }
  $$sig = _form_sig($ret); # arrayref -> usual string
  return bless $ret, $class;
}

=head2 update(name, sig, restype, abi, argtypes)

Also hash-style: update({ param => value, [...] })

C<update> provides a quick way of changing many attributes of a function
all at once. Only the function's C<lib> and C<func> references cannot
be updated (because that wouldn't make any sense).

=cut

sub update {
  my $self = shift;
  my @args = @_;
  my @want = qw(name sig restype abi argtypes);
  my $update_self = _get_args(@args, @want);
  for(@want) {
    if(defined $update_self->{$_}) {
      $self->{$_} = $update_self->{$_};
    }
  }
  return $self;
}

=head2 sig('cii')

A self-explanatory get/set method, only listed here to point out that
it will also change the C<abi>, C<restype> and C<argtypes> attributes,
depending on what you give it.

Don't try to set the argtypes with it by passing an array ref, like
you can in new(). Use argtypes() instead.

=cut
 
sub sig {
  my $self = shift;
  my $arg = shift;
  die("Too many arguments") if @_;
  die("Object method") if ref($self) ne 'Ctypes::Function';
  if(defined $arg) {
    $self->{abi} = substr($arg, 0, 1);
    $self->{restype} = substr($arg, 1, 1);
    $self->{argtypes} = [ split(//, substr($arg, 2)) ];
    $self->{sig} = $arg;
  }
  if(!$self->{sig}) {
    $self->{sig} = $self->{abi} . $self->{restype} .
      (defined $self->{argtypes} ? join('',@{$self->{argtypes}}) : '');
  }
  return $self->{sig};
}

=head2 argtypes( I<LIST> )

Or: argtypes( $arrayref [ offset ] )

# $obj->argtypes returns qw()'able string of arg types
# argtypes (\$;@) works like substr;

=cut

sub argtypes {
  my $self = shift;
  die("Object method") if ref($self) ne 'Ctypes::Function';
  my $new_argtypes;
  if(@_) {
    # if we got an offset...
    if(Scalar::Util::looks_like_number($_[1])) {
      die("Usage: argtypes( \$arrayref, <offset> )") if exists $_[2];
      $new_argtypes = _to_typecodes(shift);
      my $offset = shift;
      if($self->{argtypes}) {
        splice(@{$self->{argtypes}},$offset,$#$new_argtypes,@$new_argtypes);
      } else {
        # user provided offset, but there were no pre-existing argtypes
        $self->{argtypes} = $new_argtypes; 
      }
    } else {
      $new_argtypes = _to_typecodes( @_ );
      $self->{argtypes} = $new_argtypes;
    }
  }
  return undef if not defined $self->{argtypes}; # <3 Perl
  return $self->{argtypes};
}



=head2 abi_default( [ 'c' | $^O ] )

Also hash-style: abi_default( [ { abi => <char> | os => $^O } ] )

This class method is used to return the default ABI (calling convention)
for the current system. It can also be used to change the 'default' for
your script, either through passing a specific ABI code ( 'c' for C<cdecl>
or 's' for C<stdcall> ) or by specifying an operating system type.
Everything but 'MSWin32' yields the 'c' (cdecl) ABI type.

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

1;
