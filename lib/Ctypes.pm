package Ctypes;
use strict;
use warnings;
my $Debug = 0;

=head1 NAME

Ctypes - Call and wrap C libraries and functions from Perl, using Perl

=head1 VERSION

Version 0.002

=cut

our $VERSION = '0.002';

use AutoLoader;
use Carp;
use Config;
use Ctypes::Type;
use Ctypes::Type::Struct;
use Ctypes::Type::Union;
use DynaLoader;
use File::Spec;
use Scalar::Util qw|blessed looks_like_number|;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = ( qw|CDLL WinDLL OleDLL PerlDLL 
                   WINFUNCTYPE CFUNCTYPE PERLFUNCTYPE
                   POINTER WinError byref is_ctypes_compat
                   Array Pointer Struct Union
                  |, @Ctypes::Type::_allnames );
our @EXPORT_OK = qw|_make_arrayref _check_invalid_types
                    _check_type_needed _valid_for_type
                    _cast|;

require XSLoader;
XSLoader::load('Ctypes', $VERSION);

=head1 SYNOPSIS

    use Ctypes;

    # Look Ma, no XS!
    my $lib  = CDLL->LoadLibrary("-lm");
    my $func = $lib->sqrt;
    my $ret = $lib->sqrt(16.0); # on Windows only
    # non-windows
    my $ret = $lib->sqrt({sig=>"cdd"},16.0);

    # bare
    my $ret  = Ctypes::call( $func, 'cdd', 16.0  );
    print $ret; # 4! Eureka!

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

Ctypes is designed to let module authors wrap native C libraries in
a pure Perly way. Authors can benefit by not having to deal with any
XS or C code. Users benefit from not having to have a compiler properly
installed and configured - they simply download the necessary binaries
and run the Ctypes-based Perl modules written against them.

The module should also be as useful for the admin, scientist or general
datamangler who wants to quickly script together a couple of functions
from different native libraries as for the Perl module author who wants
to expose the full functionality of a large C/C++ project.

=cut


=head1 SUBROUTINES

=over

=item call SIG, ADDR, [ ARGS ... ]

Lets you call the external function at the address specified by ADDR,
with the signature specified by SIG, and return a value.

C<Ctypes::call> is modelled after the C<call> function found in
L<FFI.pm|FFI>: it's the low-level, bare bones access to Ctypes'
capabilities. Most of the time you'll probably prefer the
abstractions provided by L<Ctypes::Function>.

I<SIG> is the signature string. The first character specifies the
calling-convention: s for stdcall, c for cdecl (or 64-bit fastcall). 
The second character specifies the typecode for the return type
of the function, and the subsequent characters specify the argument types.

'Typecodes' are single character designations for various C data types.
They're similar in concept to the codes used by Perl's
L<pack|perlfunc/pack> and L<unpack|perlfunc/unpack> functions, but they
are B<not> the same codes!
 
I<ADDR> is the function address, the return value of L<find_function> or
L<DynaLoader::dl_find_symbol>.

I<ARGS> are the optional arguments for the external function. The types
are converted as specified by sig[2..].

Here are the urrently supported signature typecode characters. As you can
see, there is some overlap with Perl's L<pack|perlfunc/pack> notation,
they're not identical (v), and furthermore B<WILL CHANGE> to offer a wider
range of types:

  'v': void
  'c': signed char
  'C': unsigned char
  's': signed short
  'S': unsigned short
  'i': signed int
  'I': unsigned int
  'l': signed long
  'L': unsigned long
  'f': float
  'd': double
  'D': long double
  'p': pointer

=cut

sub call {
  my $func = shift;
  my $sig = shift;
  my @args = @_;
  my @argtypes = ();
  @argtypes = split( //, substr( $sig, 2 ) ) if length $sig > 2;
  for(my $i=0 ; $i<=$#args ; $i++) {
    if( $argtypes[$i] =~ /[dDfFiIjJlLnNqQsSvV]/ and 
        not looks_like_number($args[$i]) ) {
      die "$i-th argument $args[$i] is no number";
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
which also returns a handle.

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
  # This might trigger a Windows MessageBox
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

restype and argtypes are L<Ctype::Type> objects, such as c_int, 
c_void_p, c_char_p etc..

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

B<perlfunc> is a named (or anonymous?) subroutine reference. B<restype>
is a single character string representing the return type, and
B<argtypes> is a multi-character string representing the argument
types the function will receive from C. All types are represented
in typecode format.

B<Note> that the interface for Callback->new() will be updated
to be more consistent with Function->new().

=cut

sub callback($$$) {
  return Ctypes::Callback->new( @_ );
}

=back

=head1 Ctypes::DLL

Define objects for shared libraries and its abi.

Subclasses are CDLL, WinDLL, OleDLL and PerlDLL, returning objects
defining the path, handle, restype and abi of the found shared library.

Submethods are LoadLibrary and the functions and variables inside the library. 

Properties are _name, _path, _abi, _handle.

  $lib = CDLL->msvcrt;

is the same as CDLL->new("msvcrt"),
but CDLL->libc should be used for cross-platform compat.

  $func = CDLL->c->toupper;

returns the function for the libc function toupper, 
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

Windows only: Returns a library object for the Windows kernel32.dll.

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

package Ctypes::Util;
use strict;
use warnings;

=head1 Utility Functions

=over

=item Ctypes::Util::find_library (lib, [dynaloader args])

Searches the dll/so loadpath for the given library, architecture dependently.

The lib argument is either part of a filename (e.g. "kernel32"),
a full pathname to the shared library
or the same as for L<DynaLoader::dl_findfile>:
"-llib" or "-Lpath -llib", with -L for the optional path.

Returns the path of the found library or undef.

  find_library "-lm"
    => "/usr/lib/libm.so"
     | "/usr/bin/cygwin1.dll"
     | "C:\\WINDOWS\\\\System32\\MSVCRT.DLL

  find_library "-L/usr/local/kde/lib -lkde"
    => "/usr/local/kde/lib/libkde.so.2.0"

  find_library "kernel32"
    => "C:\\WINDOWS\\\\System32\\KERNEL32.dll"

On cygwin or mingw C<find_library> might try to run the external program C<dllimport>
to resolve the version specific dll from the found unversioned import library.

With C<mode> optional dynaloader args can or even must be specified as with
L<load_library>, because C<find_library> also tries to load every found
library, and only returns libraries which could successfully be dynaloaded.

=cut

sub find_library($;@) {# from C::DynaLib::new
  my $libname = $_ = shift;
  my $so = $libname;
  -e $so or $so = DynaLoader::dl_findfile($libname) || $libname;
  my $lib;
  $lib = DynaLoader::dl_load_file($so, @_) unless $so =~ /\.a$/;
  return $so if $lib;

  # Duplicate most of the DynaLoader code, since DynaLoader is
  # not ready to find MSWin32 dll's.
  if ($^O =~ /MSWin32|cygwin/) { # activeperl, mingw (strawberry) or cygwin
    my ($found, @dirs, @names, @dl_library_path);
    my $lib = $libname;
    $lib =~ s/^-l//;
    if ($^O eq 'cygwin' and $lib =~ m{^(c|m|pthread|/usr/lib/libc\.a)$}) {
      return "/bin/cygwin1.dll";
    }
    if ($^O eq 'MSWin32' and $lib =~ /^(c|m|msvcrt|msvcrt\.lib)$/) {
      $so = $ENV{SYSTEMROOT}."\\System32\\MSVCRT.DLL";
      if ($lib = DynaLoader::dl_load_file($so, @_)) {
	      return $so;
      }
      # python has a different logic: The version+subversion is taken from 
      # msvcrt dll used in the python.exe
      # We search in the systempath for the first found.
      push(@names, "MSVCRT.DLL","MSVCRT90","MSVCRT80","MSVCRT71","MSVCRT70",
	   "MSVCRT60","MSVCRT40","MSVCRT20");
    }
    # Either a dll if there exists a unversioned dll,
    # or the import lib points to the versioned dll.
    push(@dirs, "/lib", "/usr/lib", "/usr/bin/", "/usr/local/bin")
      unless $^O eq 'MSWin32'; # i.e. cygwin
    push(@dirs, $ENV{SYSTEMROOT}."\\System32", $ENV{SYSTEMROOT}, ".")
      if $^O eq 'MSWin32';
    push(@names, "cyg$_.dll", "lib$_.dll.a") if $^O eq 'cygwin';
    push(@names, "$_.dll", "lib$_.a") if $^O eq 'MSWin32';
    push(@names, "lib$_.so", "lib$_.a");
    my $pthsep = $Config::Config{path_sep};
    push(@dl_library_path, split(/$pthsep/, $ENV{LD_LIBRARY_PATH} || ""))
      unless $^O eq 'MSWin32';
    push(@dirs, split(/$pthsep/, $ENV{PATH}));
  LOOP:
    for my $name (@names) {
      for my $dir (@dirs, @dl_library_path) {
	      next unless -d $dir;
	      my $file = File::Spec->catfile($dir,$name);
	      if (-f $file) {
	        $found = $file;
	        last LOOP;
	      }
      }
    }
    if ($found) {
      # resolve the .a or .dll.a to the dll. 
      # dllimport from binutils must be in the path
      $found = system("dllimport -I $found") if $found =~ /\.a$/;
      return $found if $found;
    }
  } else {
    if (-e $so) {
      # resolve possible ld script
      # GROUP ( /lib/libc.so.6 /usr/lib/libc_nonshared.a  AS_NEEDED ( /lib/ld-linux-x86-64.so.2 ) )
      local $/;
      my $fh;
      open($fh, "<", $so);
      my $slurp = <$fh>;
      # for now the first in the GROUP. We should use ld 
      # or /sbin/ldconfig -p or objdump
      if ($slurp =~ /^\s*GROUP\s*\(\s*(\S+)\s+/m) {
	return $1;
      }
    }
  }
}

package Ctypes;

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

Returns the address of the memory buffer as integer. obj must be an
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
obj_or_type must be a Ctypes type or instance.

=cut

sub alignment($) {
  my $obj = shift;
  $obj->isa("Ctypes::Type")
    or die "alignment(".ref $obj.") not a Ctypes::Type or instance";
  return $obj->{alignment};
}

=item byref(obj)

Returns a light-weight pointer to obj, which must be an instance of a
ctypes type. The returned object can only be used as a foreign
function call parameter. It behaves similar to pointer(obj), but the
construction is a lot faster.

=cut

sub byref {
  return \$_[0];  
}

=item is_ctypes_compat($obj)

Returns 1 if object is Ctypes compatible - that is, it has a
_as_param_, _update_ and _typecode_ methods, and the value returned
by _typecode_ is valid. Returns undef otherwise.

=cut

sub is_ctypes_compat (\$) {
  if( blessed($_[0]),
      and $_[0]->can('_as_param_')
      and $_[0]->can('_update_')
      and $_[0]->can('typecode')
    ) {
    $@ = undef;
    eval{ sizeof($_[0]->typecode) };
    if( !$@ ) {
      return 1;
    }
  }
  return undef;
}

=item cast(obj, type)

This function is similar to the cast operator in C. It returns a new
instance of type which points to the same memory block as obj. type
must be a pointer type, and obj must be an object that can be
interpreted as a pointer.

=item create_string_buffer(init_or_size[, size])

This function creates a mutable character buffer. The returned object
is a ctypes array of c_char.

init_or_size must be an integer which specifies the size of the array,
or a string which will be used to initialize the array items.

If a string is specified as first argument, the buffer is made one
item larger than the length of the string so that the last element in
the array is a NUL termination character. An integer can be passed as
second argument which allows to specify the size of the array if the
length of the string should not be used.

If the first parameter is a unicode string, it is converted into an
8-bit string according to ctypes conversion rules.

=item create_unicode_buffer(init_or_size[, size])

This function creates a mutable unicode character buffer. The returned
object is a ctypes array of C<c_wchar>.

init_or_size must be an integer which specifies the size of the array,
or a unicode string which will be used to initialize the array items.

If a unicode string is specified as first argument, the buffer is made
one item larger than the length of the string so that the last element
in the array is a NUL termination character. An integer can be passed
as second argument which allows to specify the size of the array if
the length of the string should not be used.

If the first parameter is a 8-bit string, it is converted into an
unicode string according to ctypes conversion rules.

=item DllCanUnloadNow()

Windows only: This function is a hook which allows to implement
inprocess COM servers with ctypes. It is called from the
DllCanUnloadNow function that the Ctypes XS extension dll exports.

=item DllGetClassObject()

Windows only: This function is a hook which allows to implement
inprocess COM servers with ctypes. It is called from the
DllGetClassObject function that the Ctypes XS extension dll exports.

=item FormatError([code])

Windows only: Returns a textual description of the error code. If no
error code is specified, the last error code is used by calling the
Windows API function C<GetLastError>.

=item GetLastError()

Windows only: Returns the last error code set by Windows in the calling thread.

=item memmove(dst, src, count)

Same as the standard C memmove library function: copies count bytes
from src to dst. dst and src must be integers or ctypes instances that
can be converted to pointers.

=item memset(dst, c, count)

Same as the standard C memset library function: fills the memory block
at address dst with count bytes of value c. dst must be an integer
specifying an address, or a ctypes instance.

=item POINTER(type)

This factory function creates and returns a new ctypes pointer
type. Pointer types are cached an reused internally, so calling this
function repeatedly is cheap. type must be a ctypes type.

=item pointer(obj)

This function creates a new pointer instance, pointing to obj. The
returned object is of the type POINTER(type(obj)).

Note: If you just want to pass a pointer to an object to a foreign
function call, you should use byref(obj) which is much faster.

=item resize(obj, size)

This function resizes the internal memory buffer of obj, which must be
an instance of a ctypes type. It is not possible to make the buffer
smaller than the native size of the objects type, as given by
sizeof(type(obj)), but it is possible to enlarge the buffer.

=item set_conversion_mode(encoding, errors)

This function sets the rules that ctypes objects use when converting
between 8-bit strings and unicode strings. encoding must be a string
specifying an encoding, like 'utf-8' or 'mbcs', errors must be a
string specifying the error handling on encoding/decoding
errors. Examples of possible values are "strict", "replace", or
"ignore".

set_conversion_mode returns a 2-tuple containing the previous
conversion rules. On windows, the initial conversion rules are
('mbcs', 'ignore'), on other systems ('ascii', 'strict').

=item sizeof(obj_or_type)

Returns the size in bytes of a ctypes type or instance memory
buffer. Does the same as the C sizeof() function.

=item string_at(address[, size])

This function returns the string starting at memory address
address. If size is specified, it is used as size, otherwise the
string is assumed to be zero-terminated.

=item WinError( { code=>undef, descr=>undef } )

Windows only: this function is probably the worst-named thing in
Ctypes. It creates an instance of WindowsError. 

If B<code> is not specified, GetLastError is called to determine the
error code. If B<descr> is not spcified, FormatError is called to get
a textual description of the error.

=item wstring_at(address)

This function returns the wide character string starting at memory
address address as unicode string. If size is specified, it is used as
the number of characters of the string, otherwise the string is
assumed to be zero-terminated.

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
L<http://blogs.perl.org/users/doubi> or by following <at>doubious_code
on Twitter (if anyone knows a microblogging client that lets me manage
my Twitter, Facebook and Iden.ti.ca from the one interface, please let
me know :-)

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

There are 4 other Perl ffi libraries:
L<Win32::API>, L<C::DynaLib>, L<FFI> and L<P5NCI>.

You'll need the headers and/or description of the foreign library.

=head1 ACKNOWLEDGEMENTS

This module was created under the auspices of Google through their
Summer of Code 2010. My deep thanks to Jonathan Leto, Reini Urban
and Shlomi Fish for giving me the opportunity to work on the project.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Ryan Jendoubi.

This program is free software; you can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

See http://dev.perl.org/licenses/ for more information.

=cut


################################
#   PRIVATE FUNCTIONS & DATA   #
################################

# Take input of:
#   ARRAY ref
#   or list
#   or typecode string
# ... and interpret into an array ref
sub _make_arrayref {
  my @inputs = @_;
  my $output = [];
  # Turn single arg or LIST into arrayref...
  if( ref($inputs[0]) ne 'ARRAY' ) {
    if( $#inputs > 0 ) {      # there is a list of inputs 
      for(@inputs) {
        push @{$output}, $_;
      }    
    } else {   # there is only one input 
      if( !ref($inputs[0]) ) {
      # We can make list of argtypes from string of type codes...
        $output = [ split(//,$inputs[0]) ];
      } else {
        push @{$output}, $inputs[0];
      }
    }
  } else {  # first arg is an ARRAY ref, must be the only arg
    croak( "Can't take more args after ARRAY ref" ) if $#inputs > 0;
    $output = $inputs[0];
  }
  return $output;
}

# Take an arrayref (see _make_arrayref) and makes sure all contents are
#   valid typecodes
#   Type objects
#   Objects implementing _as_param_ attribute or method
# Returns UNDEF on SUCCESS
# Returns the index of the failing thingy on failure
sub _check_invalid_types ($) {
  my $typesref = shift;
  # Now check supplied args are valid...
  my $typecode = undef;
  for( my $i=0; $i<=$#{$typesref}; $i++ ) {
    $_ = $typesref->[$i];
    # Check objects fulfil all the requirements...
    if( ref($_) ) {
      if( !blessed($_) ) {
        carp("No unblessed references as types");
        return $i;
      } else {
        if( !$_->can("_as_param_")
            and not defined($_->{_as_param_}) ) {
          carp("types must have _as_param_ method or attribute");
          return $i;
        }
        # try for attribute first
        $typecode = $_->{_typecode_};
        if( not defined($typecode) ) {
          if( $_->can("typecode") ) {
            $typecode = $_->typecode;
          } else {
            carp("types must have typecode method");
            return $i;
          }
        }
        eval{ Ctypes::sizeof($typecode) };
        if( $@ ) { 
          carp( @_ );
          return $i;
        }
      } 
    } else {
    # Not a ref; make sure it's a valid 1-char typecode...
      if( length($_) > 1 ) {
carp("types must be valid objects or 1-char typecodes (perldoc Ctypes)");
        return $i;
      }
      eval{ Ctypes::sizeof($_); };
      if( $@ ) { 
        carp( @_ );
        return $i;
      }
    }
  }
  return undef;
}

# Take an list of Perl natives, return the typecode of
# the smallest C type needed to hold all the data - the
# lowest common demoninator, if you will (will you?)
sub _check_type_needed (@) {
  # XXX This needs changed when we support more typecodes
  print "In _check_type_needed\n" if $Debug == 1;
  my @numtypes = qw|s i l d|; #  1.short 2.int 3.long 4.double
  my $low = 0;
  my $char = 0;
  my $string = 0;
  for(my $i = 0; defined( local $_ = $_[$i]); $i++ ) {
  print "    Now looking at: $_\n" if $Debug == 1; 
   if( $char == 1 or !looks_like_number($_) ) {
      $char = 1;
      $string = 1 if length( $_ ) > 1;
      last if $string == 1;
      next;
    } else {
      next if $low == 3;
      $low = 1 if $_ > Ctypes::constant('PERL_SHORT_MAX') and $low < 1;
      $low = 2 if $_ > Ctypes::constant('PERL_INT_MAX') and $low < 2;
      $low = 3 if $_ > Ctypes::constant('PERL_LONG_MAX') and $low < 3;
    }
  }
  my $ret;
  if( $string == 1 ) {
    $ret = 'p';
  } elsif( $char == 1 ) {
    $ret = 'C';
  } else {
    $ret = $numtypes[$low];
  }
  print "  Returning: $ret\n" if $Debug == 1; 
  return $ret;
}


1;
__END__
