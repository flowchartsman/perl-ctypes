package Ctypes;
use strict;
use warnings;

=pod

=encoding utf8

=head1 NAME

Ctypes - Call and wrap C libraries and functions from Perl, using Perl

=head1 VERSION

Version 0.003

=cut

our $VERSION = '0.003';

use AutoLoader;
use Carp;
use Config;
use Ctypes::Type;
use Ctypes::Type::Struct;
use Ctypes::Type::Union;
use DynaLoader;
use File::Spec;
use Getopt::Long;
use Scalar::Util qw|blessed looks_like_number|;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = ( qw|CDLL WinDLL OleDLL PerlDLL
                   WINFUNCTYPE CFUNCTYPE PERLFUNCTYPE
                   POINTER WinError byref is_ctypes_compat
                   Array Pointer Struct Union USE_PERLTYPES
                  |, @Ctypes::Type::_allnames );
our @EXPORT_OK = qw|PERL|;

require XSLoader;
XSLoader::load('Ctypes', $VERSION);

=head1 SYNOPSIS

    use Ctypes;

    my $lib  = CDLL->LoadLibrary("-lm");
    my $func = $lib->sqrt;
    my $ret = $lib->sqrt(16.0); # on Windows only
    # non-windows
    my $ret = $lib->sqrt({sig=>"cdd"},16.0);

    # bare
    my $ret  = Ctypes::call( $func, 'cdd', 16.0  );
    print $ret; # 4

    # which is the same as:
    use DynaLoader;
    my $lib =  DynaLoader::dl_load_file( DynaLoader::dl_findfile( "-lm" ));
    my $func = Dynaloader::dl_find_symbol( $lib, 'sqrt' );
    my $ret  = Ctypes::call( $func, 'cdd', 16.0  );

=head1 ABSTRACT

Ctypes is the Perl equivalent to the Python ctypes FFI library, using
libffi. It provides C compatible data types, and allows one to call
functions in dlls/shared libraries.

=head1 DESCRIPTION

Ctypes is designed to let module authors wrap native C libraries in a pure Perly
(or Python) way. Authors can benefit by not having to deal with any XS or C
code. Users benefit from not having to have a compiler properly installed and
configured - they simply download the necessary binaries and run the
Ctypes-based Perl modules written against them.

The module should also be as useful for the admin, scientist or general
datamangler who wants to quickly script together a couple of functions
from different native libraries as for the Perl module author who wants
to expose the full functionality of a large C/C++ project.

=head2 Typecodes

Here are the currently supported low-level signature typecode characters, with
the matching Ctypes and perl-style packcodes.
As you can see, there is some overlap with Perl's L<pack|perlfunc/pack> notation,
they're not identical (v, h, H), and offer a wider range of types as on the 
python ctypes typecodes (s,w,z,...).

With C<use Ctypes 'PERL'>, you can demand Perl's L<pack|perlfunc/pack> notation.

Typecode: Ctype                  perl Packcode
  'v': void
  'b': c_byte (signed char)      c
  'B': c_ubyte (unsigned char)   C
  'c': c_char (signed char)      c
  'C': c_uchar (unsigned char)   C

  'h': c_short (signed short)    s
  'H': c_ushort (unsigned short) S
  'i': c_int (signed int)        i
  'I': c_uint (unsigned int)     I
  'l': c_long (signed long)      l
  'L': c_ulong (unsigned long)   L
  'f': c_float                   f
  'd': c_double                  d
  'g': c_longdouble              D
  'q': c_longlong                q
  'Q': c_ulonglong               Q

  'Z': c_char_p (ASCIIZ string)  A?
  'w': c_wchar                   U
  'z': c_wchar_p                 U*
  'X': c_bstr (2byte string)     a?

=cut

our $USE_PERLTYPES = 0; # import arg -PERL: full python ctypes types,
                        # or just the simplier perl pack-style types
sub USE_PERLTYPES { $USE_PERLTYPES }
sub PERL {
  $USE_PERLTYPES = 1;
  #eval q|sub Ctypes::Type::c_short::typecode{'s'}; 
  #       sub Ctypes::Type::c_ushort::typecode{'S'};
  #       sub Ctypes::Type::c_longdouble::typecode{'D'}
  #      |;
}

=head1 FUNCTIONS

=over

=item call ADDR, SIG, [ ARGS ... ]

Call the external function via C<libffi> at the address specified by B<ADDR>,
with the signature specified by B<SIG>, optional B<ARGS>, and return a value.

C<Ctypes::call> is modelled after the C<call> function found in
L<FFI.pm|FFI>: it's the low-level, bare bones access to Ctypes'
capabilities. Most of the time you'll probably prefer the
abstractions provided by L<Ctypes::Function>.

I<SIG> is the signature string. The first character specifies the
calling-convention: B<s> for stdcall, B<c> for cdecl (or 64-bit fastcall).
The second character specifies the B<typecode> for the return type
of the function, and the subsequent characters specify the argument types.

L<Typecodes> are single character designations for various C data types.
They're similar in concept to the codes used by Perl's
L<pack|perlfunc/pack> and L<unpack|perlfunc/unpack> functions, but they
are B<not> the same codes!

I<ADDR> is the function address, the return value of L<find_function> or
L<DynaLoader::dl_find_symbol>.

I<ARGS> are the optional arguments for the external function. The types
are converted as specified by sig[2..].

=cut

sub call {
  my $func = shift;
  my $sig = shift;
  my @args = @_;
  my @argtypes = ();
  @argtypes = split( //, substr( $sig, 2 ) ) if length $sig > 2;
  for(my $i=0 ; $i<=$#args ; $i++) {
    # valid ffi sizecode's
    if( $argtypes[$i] =~ /[dDfFiIjJlLnNqQsSvV]/ and
        not looks_like_number( $args[$i] ) ) {
      $args[$i] = $args[$i]->value()
        or die "$i-th argument $args[$i] is no number";
      die "$i-th argument $args[$i] is no number"
        unless looks_like_number( $args[$i] );
    }
  }
  return _call( $func, $sig, @args );
}

=item Array I<LIST>

=item Array I<TYPE>, I<ARRAYREF>

Create a L<Ctypes::Type::Array> object. LIST and ARRAYREF can contain
Ctypes objects, or a Perl natives.

If the latter, Ctypes will try to choose the smallest appropriate C
type and create Ctypes objects out of the Perl natives for you. You
can find out which type it chose afterwards by calling the C<member_type>
accessor method on the Array object.

If you want to specify the data type of the array, you can do so by
passing a Ctypes type as the first parameter, and the contents in an
array reference as the second. Naturally, your data must be compatible
with the type specified, otherwise you'll get an error from the a
C<Ctypes::Type::Simple> constructor.

And of course, in C(types), all your array input has to be of the same
type.

See L<Ctypes::Type::Array> for more detailed documentation.

=cut

sub Array {
  return Ctypes::Type::Array->new(@_);
}

=item Pointer OBJECT

=item Pointer TYPE, OBJECT

Create a L<Ctypes::Type::Pointer> object. OBJECT must be a Ctypes object.
See the relevant documentation for more information.

=cut

sub Pointer {
  return Ctypes::Type::Pointer->new(@_);
}

=item Struct

Create a L<Ctypes::Type::Struct> object. Basing new classes on Struct
may also often be more useful than subclassing other Types. See the
relevant documentation for more information.

=cut

sub Struct {
  return Ctypes::Type::Struct->new(@_);
}

=item Union

Create and return a L<Ctypes::Type::Union> object. See the documentation
for L<Ctypes::Type::Union> and L<Ctypes::Type::Struct> for information on
instantiation etc.

=cut

sub Union {
  return Ctypes::Type::Union->new(@_);
}

=item load_library (lib, [mode])

Searches the dll/so loadpath for the given library, architecture dependently.

The lib argument is either part of a filename (e.g. "kernel32") with
platform specific path and extension defaults,
a full pathname to the shared library
or the same as for L<DynaLoader::dl_findfile>:
"-llib" or "-Lpath -llib", with -L for the optional path.

Returns a libraryhandle, to be used for find_function.
Uses L<Ctypes::Util::find_library> to find the path.
See also the L<LoadLibrary> method for a DLL object,
which also returns a handle and L<DynaLoader::dl_load_file>.

With C<mode> optional dynaloader args can be specified:

=over

=item RTLD_GLOBAL

Flag to use as mode parameter. On platforms where this flag is not
available, it is defined as the integer zero.

=item RTLD_LOCAL

Flag to use as mode parameter. On platforms where this is not
available, it is the same as RTLD_GLOBAL.

=item DEFAULT_MODE

The default mode which is used to load shared libraries. On OSX 10.3,
 this is RTLD_GLOBAL, otherwise it is the same as RTLD_LOCAL.

=back

=cut

sub load_library($;@) {
  my $path = Ctypes::Util::find_library( shift, @_ );
  # XXX This might trigger a Windows MessageBox on error.
  # We might want to suppress it as done in cygwin.
  return DynaLoader::dl_load_file($path, @_) if $path;
}

=item CDLL (library, [mode])

Searches the library search path for the given name, and
returns a library object which defaults to the C<cdecl> ABI, with
default restype C<i>.

For B<mode> see L<load_library>.

=cut

sub CDLL {
  return Ctypes::CDLL->new( @_ );
}

=item WinDLL (library, [mode])

Windows only: Searches the library search path for the given name, and
returns a library object which defaults to the C<stdcall> ABI,
with default restype C<i>.

For B<mode> see L<load_library>.

=cut

sub WinDLL {
  return Ctypes::WinDLL->new( @_ );
}

=item OleDLL (library, [mode])

Windows only: Objects representing loaded shared libraries, functions
in these libraries use the C<stdcall> calling convention, and are assumed
to return the windows specific C<HRESULT> code. HRESULT values contain
information specifying whether the function call failed or succeeded,
together with additional error code. If the return value signals a
failure, a L<WindowsError> is automatically raised.

For B<mode> see L<load_library>.

=cut

sub OleDLL {
  return Ctypes::OleDLL->new( @_ );
}

=item PerlDLL (library)

Instances of this class behave like CDLL instances, except that the
Perl XS library is not released during the function call, and after
the function execution the Perl error flag is checked. If the error
flag is set, a Perl exception is raised.  Thus, this is only useful
to call Perl XS api functions directly.

=cut

sub PerlDLL() {
  return Ctypes::PerlDLL->new( @_ );
}

=item CFUNCTYPE (restype, argtypes...)

The returned L<C function prototype|Ctypes::FuncProto::C> creates a
function that use the standard C calling convention. The function will
release the library during the call.

C<restype> and C<argtypes> are L<Ctype::Type> objects, such as C<c_int>,
C<c_void_p>, C<c_char_p> etc..

=item WINFUNCTYPE (restype, argtypes...)

Windows only: The returned L<Windows function prototype|Ctypes::FuncProto::Win>
creates a function that use the C<stdcall> calling convention.
The function will release the library during the call.

B<SYNOPSIS>

  my $prototype  = WINFUNCTYPE(c_int, HWND, LPCSTR, LPCSTR, UINT);
  my $paramflags = [[1, "hwnd", 0], [1, "text", "Hi"],
	           [1, "caption", undef], [1, "flags", 0]];
  my $MessageBox = $prototype->(("MessageBoxA", WinDLL->user32), $paramflags);
  $MessageBox->({text=>"Spam, spam, spam")});

=item PERLFUNCTYPE (restype, argtypes...)

The returned function prototype creates functions that use the Perl XS
calling convention. The function will not release the library during
the call.

=cut

sub WINFUNCTYPE {
  use Ctypes::FuncProto;
  return Ctypes::FuncProto::Win->new( @_ );
}
sub CFUNCTYPE {
  use Ctypes::FuncProto;
  return Ctypes::FuncProto::C->new( @_ );
}
sub PERLFUNCTYPE {
  use Ctypes::FuncProto;
  return Ctypes::FuncProto::Perl->new( @_ );
}

=item callback (<perlfunc>, <restype>, <argtypes>)

Creates a callable, an external function which calls back into perl,
specified by the signature and a reference to a perl sub.

B<perlfunc> is a named (or anonymous?) subroutine reference.
B<restype> is a single character string representing the return type,
and B<argtypes> is a multi-character string representing the argument
types the function will receive from C. All types are represented
in L<typecode|/"call SIG, ADDR, [ ARGS ... ]"> format.

B<Note> that the interface for C<Callback->new()> will be updated
to be more consistent with C<Function->new()>.

=cut

sub callback($$$) {
  return Ctypes::Callback->new( @_ );
}

=back

=head1 Ctypes::DLL

Define objects for shared libraries and its abi.

Subclasses are B<CDLL>, B<WinDLL>, B<OleDLL> and B<PerlDLL>, returning objects
defining the path, handle, restype and abi of the found shared library.

Submethods are B<LoadLibrary> and the functions and variables inside the library.

Properties are C<_name>, C<_path>, C<_abi>, C<_handle>.

  $lib = CDLL->msvcrt;

is the same as C<CDLL->new("msvcrt")>,
but C<CDLL->libc> should be used for cross-platform compat.

  $func = CDLL->c->toupper;

returns the function for the libc function C<toupper()>,
on Windows and Posix.

Functions within libraries can be declared.
or called directly.

  $ret = CDLL->libc->toupper({sig => "cii"})->ord("y");

=cut

package Ctypes::DLL;
use strict;
use warnings;
use Ctypes;
use Ctypes::Function;
use Carp;

# This AUTOLOAD is used to define the dll/soname for the library,
# or access a function in the library.
# $lib = CDLL->msvcrt; $func = CDLL->msvcrt->toupper;
# Indexed with CDLL->msvcrt[0] (tied array?) on windows only
# or named with WinDLL->kernel32->GetModuleHandle({sig=>"sll"})->(32)
sub AUTOLOAD {
  my $name;
  our $AUTOLOAD;
  ($name = $AUTOLOAD) =~ s/.*:://;
  return if $name eq 'DESTROY';
  # property
  if ($name =~ /^_(abi|handle|path|name)$/) {
    *$AUTOLOAD = sub {
      my $self = shift;
      # only _abi is setable
      if ($name eq 'abi') {
        if (@_) {
          return $self->{$name} = $_[0];
        }
        if (defined $self->{$name} ) {
          return $self->{$name};
        } else { return undef; }
      } else {
        warn("$name not setable") if @_;
        if (defined $self->{$name} ) {
          return $self->{$name};
        } else { return undef; }
      }
      goto &$AUTOLOAD;
    }
  }
  if (@_) {
    # ->library
    my $lib = shift;
    # library not yet loaded?
    if (ref($lib) =~ /^Ctypes::(|C|Win|Ole|Perl)DLL$/ and !$lib->{_handle}) {
      $lib->LoadLibrary($name)
	or croak "LoadLibrary($name) failed";
      return $lib;
    } else { # name is a ->function
      my $props = { lib => $lib->{_handle},
		    abi => $lib->{_abi},
		    restype => $lib->{_restype},
		    name => $name };
      if (@_ and ref $_[0] eq 'HASH') { # declare the sig or restype via HASHREF
	my $arg = shift;
	$props->{sig} = $arg->{sig} if $arg->{sig};
	$props->{restype} = $arg->{restype} if $arg->{restype};
	$props->{argtypes} = $arg->{argtypes} if $arg->{argtypes};
      }
      return Ctypes::Function->new($props, @_);
    }
  } else {
    my $lib = Ctypes::load_library($name)
      or croak "Ctypes::load_library($name) failed";
    return $lib; # scalar handle only?
  }
}

=head1 LoadLibrary (name [mode])

A DLL method which loads the given shared library,
and on success sets the new object properties path and handle,
and returns the library handle.

=cut

sub LoadLibrary($;@) {
  my $self = shift;
  my $path = $self->{_path};
  $self->{_name} = shift;
  $self->{_abi} = ref $self eq 'Ctypes::CDLL' ? 'c' : 's';
  $path = Ctypes::Util::find_library( $self->{_name} ) unless $path;
  $self->{_handle} = DynaLoader::dl_load_file($path, @_) if $path;
  $self->{_path} = $path if $self->{_handle};
  return $self->{_handle};
}

=head1 CDLL

  $lib = CDLL->msvcrt;

is a fancy name for Ctypes::CDLL->new("msvcrt").
Note that you should really use the platform compatible
CDLL->c for the current libc, which can be any msvcrtxx.dll

  $func = CDLL->msvcrt->toupper;

returns the function for the Windows libc function toupper,
but this function cannot be called, since the sig is missing.
It only checks if the symbol is define inside the library.
You can add the sig later, as in

  $func->{sig} = 'cii';

or call the function like

  $ret = CDLL->msvcrt->toupper({sig=>"cii"})->(ord("y"));

On windows you can also define and call functions by their
ordinal in the library.

Define:

  $func = CDLL->kernel32[1];

Call:

  $ret = CDLL->kernel32[1]->();

=head1 WinDLL

  $lib = WinDLL->kernel32;

Windows only: Returns a library object for the Windows F<kernel32.dll>.

=head1 OleDLL

  $lib = OleDLL->mshtml;

Windows only.

=cut

package Ctypes::CDLL;
use strict;
use warnings;
use Ctypes;
our @ISA = qw(Ctypes::DLL);
use Carp;

sub new {
  my $class = shift;
  my $props = { _abi => 'c', _restype => 'i' };
  if (@_) {
    $props->{_path} = Ctypes::Util::find_library(shift);
    $props->{_handle} = Ctypes::load_library($props->{_path});
  }
  return bless $props, $class;
}

#our ($libc, $libm);
#sub libc {
#  return $libc if $libc;
#  $libc = load_library("c");
#}
#sub libm {
#  return $libm if $libm;
#  $libm = load_library("m");
#}

package Ctypes::WinDLL;
use strict;
use warnings;
our @ISA = qw(Ctypes::DLL);

sub new {
  my $class = shift;
  my $props = { _abi => 's', _restype => 'i' };
  if (@_) {
    $props->{_path} = Ctypes::Util::find_library(shift);
    $props->{_handle} = Ctypes::load_library($props->{_path});
  }
  return bless $props, $class;
}

package Ctypes::OleDLL;
use strict;
use warnings;
use Ctypes;
our @ISA = qw(Ctypes::DLL);

sub new {
  my $class = shift;
  my $props = { abi => 's', _restype => 'p', _oledll => 1 };
  if (@_) {
    $props->{_path} = Ctypes::Util::find_library(shift);
    $props->{_handle} = Ctypes::load_library($props->{_path});
  }
  return bless $props, $class;
}

package Ctypes::PerlDLL;
use strict;
use warnings;
our @ISA = qw(Ctypes::DLL);

sub new {
  my $class = shift;
  my $name = shift;
  # TODO: name may be split into subpackages: PerlDLL->new("C::DynaLib")
  my $props = { _abi => 'c', _restype => 'i', _name => $name, _perldll => 1 };
  die "TODO perl xs library search";
  $name =~ s/::/\//g;
  #$props->{_path} = $Config{...}.$name.$Config{soext};
  my $self = bless $props, $class;
  $self->LoadLibrary($props->{_path});
}

package Ctypes;

=over

=item find_function (libraryhandle, functionname)

Returns the function address of the exported function within the shared library.
libraryhandle is the return value of find_library or DynaLoader::dl_load_file.

=cut

sub find_function($$) {
  return DynaLoader::dl_find_symbol( shift, shift );
}

=item load_error ()

Returns the error description of the last L<load_library> call,
via L<DynaLoader::dl_error>.

=cut

sub load_error() {
  return DynaLoader::dl_error();
}

=item addressof (obj)

Returns the address of the memory buffer as integer. C<obj> must be an
instance of a ctypes type.

=cut

sub addressof($) {
  my $obj = shift;
  $obj->isa("Ctypes::Type")
    or die "addressof(".ref $obj.") not a Ctypes::Type";
  return $obj->{address};
}

=item alignment(obj_or_type)

Returns the alignment requirements of a Ctypes type.
C<obj_or_type> must be a Ctypes type or instance.

=cut

sub alignment($) {
  my $obj = shift;
  $obj->isa("Ctypes::Type")
    or die "alignment(".ref $obj.") not a Ctypes::Type or instance";
  return $obj->{alignment};
}

=item byref(obj)

Returns a light-weight pointer to C<obj>, which must be an instance of a
Ctypes type. The returned object can only be used as a foreign
function call parameter. It behaves similar to C<pointer(obj)>, but the
construction is a lot faster.

=cut

sub byref {
  return \$_[0];
}

=item is_ctypes_compat(obj)

Returns 1 if C<obj> is Ctypes compatible - that is, it has a
C<_as_param_>, C<_update_> and C<_typecode_> methods, and the value returned
by C<_typecode_> is valid. Returns C<undef> otherwise.

=cut

sub is_ctypes_compat (\$) {
  if( blessed($_[0]),
      and $_[0]->can('_as_param_')
      and $_[0]->can('_update_')
      and $_[0]->can('typecode')
    ) {
    #my $types = CTypes::Type::_types;
    #return undef unless exists $_types->{$_[0]->typecode};
    eval{ Ctypes::sizeof($_[0]->sizecode) };
    if( !$@ ) {
      return 1;
    }
  }
  return undef;
}

=item cast(obj, type)

This function is similar to the cast operator in C. It returns a new
instance of type which points to the same memory block as C<obj>. C<type>
must be a pointer type, and obj must be an object that can be
interpreted as a pointer.

=item create_string_buffer(init_or_size[, size])

This function creates a mutable character buffer. The returned object
is a Ctypes array of C<c_char>.

C<init_or_size> must be an integer which specifies the size of the array,
or a string which will be used to initialize the array items.

If a string is specified as first argument, the buffer is made one
item larger than the length of the string so that the last element in
the array is a NUL termination character. An integer can be passed as
second argument which allows to specify the size of the array if the
length of the string should not be used.

If the first parameter is a unicode string, it is converted into an
8-bit string according to Ctypes conversion rules.

=item create_unicode_buffer(init_or_size[, size])

This function creates a mutable unicode character buffer. The returned
object is a Ctypes array of C<c_wchar>.

C<init_or_size> must be an integer which specifies the size of the array,
or a unicode string which will be used to initialize the array items.

If a unicode string is specified as first argument, the buffer is made
one item larger than the length of the string so that the last element
in the array is a NUL termination character. An integer can be passed
as second argument which allows to specify the size of the array if
the length of the string should not be used.

If the first parameter is a 8-bit string, it is converted into an
unicode string according to Ctypes conversion rules.

=item DllCanUnloadNow()

Windows only: This function is a hook which allows to implement
in-process COM servers with Ctypes. It is called from the
C<DllCanUnloadNow> function that the Ctypes XS extension dll exports.

=item DllGetClassObject()

Windows only: This function is a hook which allows to implement
in-process COM servers with ctypes. It is called from the
C<DllGetClassObject> function that the Ctypes XS extension dll exports.

=item FormatError([code])

Windows only: Returns a textual description of the error code. If no
error code is specified, the last error code is used by calling the
Windows API function C<GetLastError>.

=item GetLastError()

Windows only: Returns the last error code set by Windows in the calling thread.

=item memmove(dst, src, count)

Same as the standard C memmove library function: copies count bytes from C<src>
to C<dst>. C<dst> and C<src> must be integers or Ctypes instances that can be
converted to pointers.

=item memset(dst, c, count)

Same as the standard C memset library function: fills the memory block
at address C<dst> with C<count> bytes of value C<c>. C<dst> must be an integer
specifying an address, or a Ctypes instance.

=item POINTER(type)

This factory function creates and returns a new Ctypes pointer
type. Pointer types are cached an reused internally, so calling this
function repeatedly is cheap. C<type> must be a Ctypes type.

=item pointer(obj)

This function creates a new pointer instance, pointing to C<obj>. The
returned object is of the type C<POINTER(type(obj))>.

Note: If you just want to pass a pointer to an object to a foreign
function call, you should use C<byref(obj)> which is much faster.

=item resize(obj, size)

This function resizes the internal memory buffer of C<obj>, which must be
an instance of a Ctypes type. It is not possible to make the buffer
smaller than the native size of the objects type, as given by
C<sizeof(type(obj))>, but it is possible to enlarge the buffer.

=item set_conversion_mode(encoding, errors)

This function sets the rules that Ctypes objects use when converting
between 8-bit strings and unicode strings. encoding must be a string
specifying an encoding, like 'utf-8' or 'mbcs', errors must be a
string specifying the error handling on encoding/decoding
errors. Examples of possible values are "strict", "replace", or
"ignore".

C<set_conversion_mode> returns a 2-tuple containing the previous
conversion rules. On Windows, the initial conversion rules are
('mbcs', 'ignore'), on other systems ('ascii', 'strict').

=item sizeof(obj_or_type)

Returns the size in bytes of a Ctypes type or instance memory
buffer. Does the same as the C C<sizeof()> function.

=item string_at(address[, size])

This function returns the string starting at memory address
C<address>. If C<size> is specified, it is used as size, otherwise the
string is assumed to be zero-terminated.

=item WinError( { code=>undef, descr=>undef } )

Windows only: this function is probably the worst-named thing in
Ctypes. It creates an instance of L<WindowsError>.

If B<code> is not specified, L<GetLastError> is called to determine the
error code. If B<descr> is not spcified, FormatError is called to get
a textual description of the error.

=item wstring_at(address [, size])

This function returns the wide character string starting at memory
address C<address> as unicode string. If C<size> is specified, it is used as
the number of characters of the string, otherwise the string is
assumed to be zero-terminated.

=back

=head1 API Comparison

Ctypes:

    my $function = Ctypes::Function->new( 'libc', 'sqrt', 'sig' );

P5NCI:

    my $function  = P5NCI::load_func( $library, 'func', 'sig' );
    my $double_double = $lib->load_function( 'func', 'sig' );

C::DynaLib:

    $func = $lib->DeclareSub( $symbol_name[, $return_type [, @arg_types] ] );
    $func = DeclareSub( $function_pointer[, $return_type [, @arg_types] ] );

FFI.pm:

    $lib = FFI::Library->new("mylib");
    $fn = $lib->function("fn", "signature");

=head1 TODO

=head2 General

Basically you can help porting the mess from the old over-architectured OO layout 
to the new class layout.

  done: Simple and partially Pointer
  todo: Array, Struct, Field, Union, and fix the "not so simple" Simple types.

See http://gitorious.org/perl-ctypes/perl-ctypes/commits/classify

=over

=item * Convert to using actual C-space storage for basic types

Python has an abstract base class with some basic methods, and the same
C structure underlying all C type classes.

    struct tagCDataObject {
       (PyObject_HEAD               /* Standard Python object fields */)

        char *b_ptr;                /* pointer to memory block */
        Py_ssize_t b_size;          /* size of memory block in bytes */
        Py_ssize_t b_length;        /* number of fields of this object */
        Py_ssize_t b_index;         /* index of this object into the base
                                       objects b_object list */

        int b_needsfree;            /* does the object own its memory block? */
        CDataObject *b_base;        /* pointer to base object or NULL */
        PyObject *b_objects;        /* references we need to keep */
        union value b_value;        /* a small default buffer */
    }

=item * Expand range of basic Types (see below for list)

=over

=item * Tests for all basic Types

=back

=item * Raise general code quality to encourage contributions

=over

=item * More consistent method names

=item * Resolve or properly document all XXX's and ???'s

=back

=item * Checking if correct arguments are supplied for argtypeless
calls?

=item * Special library defaults for Strawberry Perl (requrest from
kthakore / SDL)

=item * Thread safety?

=item * Setup scripts (auto-generation of wrapper modules from headers)

=item * Raw data injection into functions (request from Shmuel Fomberg)

=over

=item * Type::Blob?

=back

=back

=head2 XS Cleanup

=over

=item * I<Check for void pointers after each Newxc>

=item * Finish Ctypes::valid_for_type function for other than int

=over

=item - This may be done?

=item - What about Pointers?

=item - What about UTF8?

=back

=back

=head2 Function / Library objects

=over

=item * Test/implement more complex "output arguments" functionality

=item * Cache function (in lib?) on CDLL->lib->func()

=item * Allow a sub as a restype (if func returns integer) in order
to perform error checking.

=over

=item This is actually marked as deprecated, use errcheck attr now?

=back

=item * Python Ctypes requires everything but integers, strings and
unicode strings "to be wrapped in their corresponding ctypes type,
so that they can be converted to the required C data type".

Python Types:

=over

=item Sequence types: str, unicode, list, tuple, buffer, xrange

=item Numeric Types: int, float, long, complex

=item Dicts

=item Files

=item Iterators, generators, Sets, memoryview, contextmanager

=item Modules, Classes, Functions, Methods, Code, Type, Null,
Boolean, Ellipsis

=back

We could maybe choose a sensible defaults?

=over

=item Numbers => depends on IOK/NOK

=item Strings => char* (check SvUTF8)

=item Arrays => lowest common denominator? (logic exists
in Ctypes::Array)

=over

=item int, double, or char*

=item (logic exists in Ctypes::Array):

1) discern LCD

2) pack() appropriately

3) pass packed data

4) unpack() & modify original array

=back

=item Hashes => Build a Ctypes::Struct?

=back

An alternative would be to merge the two logics: if there are
argtypes, accept anything and coerce. If there aren't argtypes,
require ctypes obj wrapping.

=back

=head2 Callbacks

=over

=item * Make signature style more like Function's

=item * Update POD

=item * accessor methods

=back

=head2 Type objects

=over

=item * Casting

Should use same backend func as Ctypes::cast. Current implementation
is ok, needs filled it out.

Cast will return a COPY of the casted object.

Python Ctypes does implicit casting of variables returned from foreign
function calls:

    "Fundamental data types, when returned as foreign function call
    results, or, for example, by retrieving structure field members
    or array items, are transparently converted to native Python
    types. In other words, if a foreign function has a restype of
    c_char_p, you will always receive a Python string, not a c_char_p
    instance.

    "Subclasses of fundamental data types do not inherit this behavior.
    So, if a foreign functions restype is a subclass of c_void_p, you
    will receive an instance of this subclass from the function call.
    Of course, you can get the value of the pointer by accessing the
    value attribute."

=back

=head2 Arrays

=over

=item * Second (Python-style) API:

    TenPointsArrayType = POINT * 10;    # POINT is a class
    arr = TenPointsArrayType();         # Step 2, get actual array!

=back

=head2 Pointers

Python Ctypes may converts pointers-to-type to the type itself in
_build_callargs; see Python's _ctypes.c 3136-3156

=head2 Structs / Unions

=over

=item * Bit fields

=item * Change endianness on-demand

=back

=head2 Constants

Thin wrapper around ExtUtils::Constant?

=head2 Windows Conveniences

=over

=item COM objects?

=item Structured Exception Handling?

=item OLEDLL?

=item Defaulting to returning HRESULT

=item Auto-raise WindowsError on failure

=back

=head2 Header inspection

=over

=item L<GCC::TranslationUnit|GCC::TranslationUnit>?

=item External C parser like C::B::C?

=item Setup scripts (auto-generation of wrapper modules from
headers)

=back

=head2 Full list of Simple data types to be implemented

=over

=item * Ctypes::c_int8

    - ffi_type_sint8
    - pack c
    Represents the C 8-bit signed int datatype.
    Usually an alias for c_byte.

=item * Ctypes::c_uint8

    - ffi_type_uint8
    - pack C
    Represents the C 8-bit unsigned int datatype.
    Usually an alias for c_ubyte.

=item * Ctypes::c_int16

    - ffi_type_sint16
    Represents the C 16-bit signed int datatype.
    Usually an alias for c_short.

=item * Ctypes:c_uint16

    - ffi_type_uint16
    Represents the C 16-bit unsigned int datatype.
    Usually an alias for c_ushort.

=item * Ctypes::c_int32

    Represents the C 32-bit signed int datatype.
    Usually an alias for c_int.

=item * Ctypes::c_uint32

    Represents the C 32-bit unsigned int datatype.
    Usually an alias for c_uint.

=item * Ctypes::c_int64

    Represents the C 64-bit signed int datatype.
    Usually an alias for c_longlong.

=item * Ctypes::c_uint64

    Represents the C 64-bit unsigned int datatype.
   Usually an alias for c_ulonglong.

=item * Ctypes::c_float

    - ffi_type_float
    - f
    Represents the C double datatype.
    The constructor accepts an optional numeric initializer.

=item * Ctypes::c_double

    - ffi_type_double
    - d
    Represents the C double datatype.
    The constructor accepts an optional numeric initializer.

=item * Ctypes::c_byte

     - ffi_type_uint8
     - C
    Represents the C signed char datatype, and interprets the value as small integer.
    The constructor accepts an optional integer initializer
    Overflow checking Is done.
    Also accepts character initializer - **what does this mean for unicode?

=item * Ctypes::c_char

    - ffi_type_uchar / ffi_type_schar (inspect $Config{'stdchar'})
    - C or c (inspect $Config{'stdchar'}, $Config{'charbits'}, $Config{'charsize'}
    Represents the C char datatype, and interprets the value as a single character.
    The constructor accepts an optional string initializer, the length of the string must be exactly one character.

=item * Ctypes::c_char_p

    Represents the C char * datatype, which must be a pointer to a zero-terminated string.
    The constructor accepts an integer address, or a string.
    **what are addresses? How should they be expressed in Perl-land?

=item * Ctypes::c_ushort

    Represents the C unsigned short datatype.
    The constructor accepts an optional integer initializer
    (No) overflow checking is done.

=item * Ctypes::c_short

    Represents the C signed short datatype.
    The constructor accepts an optional integer initializer.
    (No) overflow checking is done.

=item * Ctypes::c_int

    - ffi_type_sint
    Represents the C signed int datatype.
    The constructor accepts an optional integer initializer.
    (No) overflow checking is done.
    On platforms where sizeof(int) == sizeof(long) it is an alias to c_long.

=item * Ctypes::c_uint

    Represents the C unsigned int datatype.
    The constructor accepts an optional integer initializer
    (No) overflow checking is done.
    On platforms where sizeof(int) == sizeof(long) it is an alias for c_ulong.

=item * Ctypes::c_ulong

    Represents the C unsigned long datatype.
    The constructor accepts an optional integer initializer.
    (No) overflow checking is done.

=item * Ctypes::c_long

    Represents the C signed long datatype.
    The constructor accepts an optional integer initializer
    (No) overflow checking is done.

=item * Ctypes::c_longlong

    Represents the C signed long long datatype.
    The constructor accepts an optional integer initializer
    (No) overflow checking is done.

=item * Ctypes::c_size_t

    Represents the C size_t datatype.

=item * Ctypes::c_ubyte

    Represents the C unsigned char datatype, it interprets the value as small integer.
    The constructor accepts an optional integer initializer.
    (No) overflow checking is done.

=item * Ctypes::c_ulonglong

    Represents the C unsigned long long datatype.
    The constructor accepts an optional integer initializer.
    (No) overflow checking is done.

=item * Ctypes::c_void_p

    Represents the C void * type.
    The value is represented as integer.
    The constructor accepts an optional integer initializer.

=item * Ctypes::c_wchar

    Represents the C wchar_t datatype
    Interprets the value as a single character unicode string.
    The constructor accepts an optional string initializer.
    The length of the string must be exactly one character.

=item * Ctypes::c_wchar_p

    Represents the C wchar_t * datatype, which must be a pointer to a zero-terminated wide character string.
    The constructor accepts an integer address, or a string.

=back

=head1 AUTHOR

Ryan Jendoubi C<< <ryan.jendoubi at gmail.com> >>

Reini Urban C<< <rurban at x-ray.at> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ctypes at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Ctypes>.  I will be
notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can see the proposed API and keep up to date with development at
L<http://blogs.perl.org/users/doubi> or by following <at>doubious
on Twitter or <at>doubi on Identi.ca.

You can find documentation for this module with the perldoc command.

    perldoc Ctypes

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Ctypes>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Ctypes>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Ctypes>

=item * Search CPAN

L<http://search.cpan.org/dist/Ctypes/>

=back

=head1 SEE ALSO

The 4 other Perl ffi libraries: L<Win32::API>, L<C::DynaLib>,
L<FFI> and L<P5NCI>.

The Python, Ruby, Javascript and Pure integrations with
L<libffi|http://sourceware.org/libffi/>.

You'll need the headers and/or description of the foreign
library.

=head1 ACKNOWLEDGEMENTS

This module was created under the auspices of Google through their
Summer of Code 2010. My deep thanks to Jonathan Leto, Reini Urban
and Shlomi Fish for giving me the opportunity to work on the project.

=head1 LICENSE AND COPYRIGHT

Copyright 2010—2012 Ryan Jendoubi.

This program is free software; you can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
__END__
