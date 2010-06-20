package Ctypes;

use strict;
use warnings;
use Carp;
use DynaLoader;
use Scalar::Util;
use File::Spec;
use Config;

=head1 NAME

Ctypes - Call and wrap C libraries and functions from Perl, using Perl

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

our @EXPORT = ( qw(CDLL WinDLL OleDLL PerlDLL $libc $libm) );
our @EXPORT_OK = ( qw(
	FFI_BAD_ABI
	FFI_BAD_TYPEDEF
	FFI_LONG_LONG_MAX
	FFI_OK
	FFI_SIZEOF_ARG
	FFI_SIZEOF_JAVA_RAW
	FFI_TYPE_DOUBLE
	FFI_TYPE_FLOAT
	FFI_TYPE_INT
	FFI_TYPE_LAST
	FFI_TYPE_LONGDOUBLE
	FFI_TYPE_POINTER
	FFI_TYPE_SINT16
	FFI_TYPE_SINT32
	FFI_TYPE_SINT64
	FFI_TYPE_SINT8
	FFI_TYPE_STRUCT
	FFI_TYPE_UINT16
	FFI_TYPE_UINT32
	FFI_TYPE_UINT64
	FFI_TYPE_UINT8
	FFI_TYPE_VOID
) );

sub AUTOLOAD {
  # This AUTOLOAD is used to 'autoload' constants from the constant()
  # XS function.

  my $constname;
  our $AUTOLOAD;
  ($constname = $AUTOLOAD) =~ s/.*:://;
  croak "&Ctypes::constant not defined" if $constname eq 'constant';
  my ($error, $val) = constant($constname);
  if ($error) { croak $error; }
  {
    no strict 'refs';
    *$AUTOLOAD = sub { $val };
  }
  goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Ctypes', $VERSION);

=head1 SYNOPSIS

    use Ctypes;

    # Look Ma, no XS!
    my $lib  = CDLL->LoadLibrary("-lm");
    my $func = $lib->sqrt;
    my $ret = $lib->sqrt(16.0); # on Windows only

    my $ret  = Ctypes::call( $func, 'cdd', 16.0  );
    print $ret; # 4! Eureka!

    # which is the same as:
    use DynaLoader;
    my $lib =  DynaLoader::dl_load_file( DynaLoader::dl_findfile( "-lm" ));
    my $func = Dynaloader::dl_find_symbol( $lib, 'sqrt' );
    my $ret  = Ctypes::call( $func, 'cdd', 16.0  );

=head1 DESCRIPTION

Ctypes is designed to let you, the Perl module author, who doesn't
want to have to mess about with XS or C, to wrap native C libraries in
a Perly way. You benefit by writing only Perl. Your users benefit from
not having to have a compiler properly installed and configured.

The module should also be as useful for the admin, scientist or general
datamangler who wants to quickly script together a couple of functions
from different native libraries as for the Perl module author who wants
to expose the full functionality of a large C/C++ project.

=head1 SUBROUTINES/METHODS

Ctypes will offer both a procedural and OO interface (to accommodate
both types of authors described above). At the moment only the
procedural interface is working.

=over

=item call (sig, addr, args)

Call an external function, specified by the signature and the address,
with the given arguments.
Return a value as specified by the seconf character in sig.

sig is the signature string. The first character specifies the
calling-convention, s for stdcall, c for cdecl (or 64-bit fastcall). 
The second character specifies the pack-style return type, the subsequent
characters specify the pack-style argument types.

addr is the function address, the return value of find_function or
L<DynaLoader::dl_find_symbol>.

args are the optional arguments for the external function. The types
are converted as specified by sig[2..].

Supported signature characters equivalent to python ctypes:

  's': pointer to string
  'c': signed char as char
  'b': signed char as byte
  'B': unsigned char as byte
  'C': unsigned char as char
  'h': signed short
  'H': unsigned short
  'i': signed int
  'I': unsigned int
  'l': signed long
  'L': unsigned long
  'f': float
  'd': double
  'g': long double
  'q': signed long long
  'q': unsigned long long
  'P': pointer
  'z': pointer to ASCIIZ string
  'u': unicode string
  'U': unicode string
  'Z': unicode string
  'X': MSWin32 BSTR
  'v': MSWin32 bool
  'O': pointer to perl object

=cut

sub call {
  my $func = shift;
  my $sig = shift;
  my @args = @_;
  my @argtypes = split( //, substr( $sig, 2 ) );
  for(my $i=0 ; $i<=$#args ; $i++) {
    if( $argtypes[$i] =~ /[dDfFiIjJlLnNqQsSvV]/ and 
        not Scalar::Util::looks_like_number($args[$i]) ) {
      die "$i-th argument $args[$i] is no number";
    }
  }
  return _call( $func, $sig, @args );
}

=item find_library (lib, [dynaloader args])

Searches the dll/so loadpath for the given library, architecture dependently.

The lib argument is either part of a filename (e.g. "kernel32"),
a full pathname to the shared library
or the same as for L<DynaLoader::dl_findfile>:
"-llib" or "-Lpath -llib", with -L for the optional path.

Returns a libraryhandle, to be used for find_function.

  find_library "-lm"
    => "/usr/lib/libm.so"
     | "/usr/bin/cygwin1.dll"
     | "C:\\WINDOWS\\\\System32\\MSVCRT.DLL

  find_library "-L/usr/local/kde/lib -lkde"
    => "/usr/local/kde/lib/libkde.so.2.0"

  find_library "kernel32"
    => "C:\\WINDOWS\\\\System32\\KERNEL32.dll"

On cygwin or mingw C<find_library> might try to run the external program dllimp
to resolve the version specific dll from the found unversioned import library.

TODO: On Windows loading a library should also define the ABI and signatures.

=cut

sub find_library($;@) {
  my $path = Ctypes::Util::find_library( shift, @_ );
  # This might trigger a Windows MessageBox
  return DynaLoader::dl_load_file($path, @_) if $path;
}


=item CDLL (library)

Calls L<find_library> and returns a library object which defaults to the cdecl ABI.

=cut

sub CDLL($;@) {
  return Ctypes::CDLL->new( @_ );
}

=item WinDLL (library)

Calls L<find_library> and returns a library object which defaults to the stdcall ABI.

=cut

sub WinDLL($;@) {
  return Ctypes::WinDLL->new( @_ );
}

=item OleDLL (library)

Windows only: Objects representing loaded shared libraries, functions
in these libraries use the stdcall calling convention, and are assumed
to return the windows specific HRESULT code. HRESULT values contain
information specifying whether the function call failed or succeeded,
together with additional error code. If the return value signals a
failure, a WindowsError is automatically raised.

=cut

sub OleDLL($;@) {
  return Ctypes::OleDLL->new( @_ );
}

=item PerlDLL (library)

Instances of this class behave like CDLL instances, except that the
Perl XS library is not released during the function call, and after
the function execution the Perl error flag is checked. If the error
flag is set, a Perl exception is raised.  Thus, this is only useful
to call Perl XS api functions directly.

=cut

sub PerlDLL($;@) {
  return Ctypes::PerlDLL->new( @_ );
}

=item callback (sig, perlfunc)

Creates an external function which calls back into perl, 
specified by the signature and a reference to a perl sub.

sig is the signature string. The first character specifies the
calling-convention, s for stdcall, c for cdecl (or 64-bit fastcall). 
The second character specifies the pack-style return type, 
the subsequent characters specify the pack-style argument types.

=cut

sub callback($$) { # TODO ffi_prep_closure
  return Ctypes::Callback->new( @_ );
}

=item c_array (ARRAYREF)

Alloc a perl array externally and copy the perl values over.

=cut

sub c_array {
  return 0;
}

=item c_struct (HASHREF)

Alloc a struct externally and copy the perl values over from a HASHREF.

=cut

sub c_struct {
  return 0;
}

=back

=head1 CTypes::Library

Subclasses are CDLL, WinDLL, OleDLL and PerlDLL, returning objects
defining the path, handle and abi of the found shared library.

Submethods are the functions and variables inside the library. 
Functions can be called.

  $lib = CDLL::msvcrt;

is more than a fancy name for Ctypes::find_library("msvcrt").

  $func = CDLL::msvcrt::toupper;

returns the function for the Windows clib function toupper.

=cut

package Ctypes::Library;
use Ctypes;
use Carp;

sub AUTOLOAD {
  # This AUTOLOAD is used to define the dll/soname for the library,
  # or access a function in the library, $lib = CDLL::msvcrt; $func = 
  # Indexed with CDLL::msvcrt[0]() or
  # or named with WinDLL::kernel32::GetModuleHandle(32)
  my ($name, $func, $lib);
  our $AUTOLOAD;
  ($name = $AUTOLOAD) =~ s/.*DLL:://;
  if ($name =~ /^(.+)::(.+)$/) {
    $name = $1;
    $func = $2;
  }
  $lib = Ctypes::find_library($name)
    or croak "Ctypes::find_library($name) failed";
  # TODO: call or just define a function?
  return $func ? return Ctypes::find_function($lib, $func) : $lib;
}

=head1 CDLL

  $lib = CDLL::msvcrt;

is a fancy name for Ctypes::find_library("msvcrt").

  $func = CDLL::msvcrt::toupper;

returns the function for the Windows clib function toupper.

  $ret = CDLL::msvcrt::toupper("y");

is possible on Windows only, where the argument and return types are known. 

On windows you can also define and call functions by their ordinal in the library, as in 

  $func = CDLL::kernel32[1];

or

  $ret = CDLL::kernel32[1]();

=head1 WinDLL

  $lib = WinDLL::kernel32;

Windows only: Teturns a library object for the Windows kernel32.dll.

=head1 OleDLL

  $lib = WinDLL::kernel32;

Windows only: Teturns a library object for the Windows kernel32.dll.

=cut

package Ctypes::CDLL;
our @ISA = qw(Ctypes::Library);

sub new {
  my $class = shift;
  my $props = { abi => 'c' };
  $props->{_name} = Ctypes::Util::find_library(shift);
  $props->{_handle} = Ctypes::find_library($props->{lib});
  return bless $props, $class;
}

package Ctypes::WinDLL;
our @ISA = qw(Ctypes::Library);

sub new {
  my $class = shift;
  my $props = { abi => 's' };
  $props->{lib} = Ctypes::Util::find_library(shift);
  $props->{handle} = Ctypes::find_library($props->{lib});
  return bless $props, $class;
}

package Ctypes::OleDLL;
our @ISA = qw(Ctypes::Library);

sub new {
  my $class = shift;
  my $props = { abi => 's' };
  $props->{lib} = Ctypes::Util::find_library(shift);
  $props->{handle} = Ctypes::find_library($props->{lib});
  return bless $props, $class;
}

package Ctypes::PerlDLL;
our @ISA = qw(Ctypes::Library);

sub new {
  my $class = shift;
  my $props = { abi => 'c' };
  $props->{lib} = Ctypes::Util::find_library(shift);
  $props->{handle} = Ctypes::find_library($props->{lib});
  return bless $props, $class;
}

package Ctypes::Util;

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

On cygwin or mingw C<find_library> might try to run the external program dllimp
to resolve the version specific dll from the found unversioned import library.

=cut

sub find_library($;@) {# from C::DynaLib::new
  my $libname = shift;
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
      # resolve the .a or .dll.a to the dll. dllimport from binutils must be in the path
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

=back

=cut

sub find_function($$) {
  return DynaLoader::dl_find_symbol( shift, shift );
}

our $libc = find_library("c");
our $libm = find_library("m");

=head1 AUTHOR

Ryan Jendoubi, C<< <ryan.jendoubi at gmail.com> >>
Reini Urban, C<< <rurban at x-ray.at> >>

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

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

=head1 ACKNOWLEDGEMENTS

This module was created under the auspices of Google through their
Summer of Code 2010. My deep thanks to Jonathan Leto, Reini Urban
and Shlomi Fish for giving me the opportunity to work on the project.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Ryan Jendoubi.

This program is free software; you can redistribute it and/or modify it
under the terms of the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Ctypes
__END__
