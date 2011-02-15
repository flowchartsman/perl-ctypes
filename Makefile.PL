# Usage:
# perl Makefile.PL INCDIR=/usr/src/libffi-3.0.10/include LIBDIR=/usr/src/libffi-3.0.10/lib

#use 5.010000;
use ExtUtils::MakeMaker;
use Config;
use File::Copy;
use File::Spec;

our $libffi_version = "3.0.10rc3";

# check the installed version of libffi and override default libdir and incdir
use lib qw(inc);
use Devel::CheckLib;
my ($libdir, $incdir);
if (grep /INCDIR[ =](\S+)/,join(" ", @ARGV)) {
  $incdir = $1;
}
if (grep /LIBDIR[ =](\S+)/,join(" ", @ARGV)) {
  $libdir = $1;
}
if ($libdir or $incdir) {
  eval qq/assert_lib( lib => 'ffi', header => 'ffi.h', libpath => $libdir, incpath => $incdir )/;
} else {
  eval q/assert_lib( lib => 'ffi', header => 'ffi.h' )/;
}
if ($@) {
  use File::Spec;
  if ($^O !~ /MSWin32|msys/) {
    warn "libffi not installed or failing. Use our own libffi $libffi_version\n";
    use Cwd;
    my $tar = $Config{tar} ? $Config{tar} : "tar";
    system ($tar, "xfz", "libffi.tar.gz");
    chdir "libffi";
    my $cwd = getcwd;
    system ($ENV{SHELL},"./configure PREFIX=/");
    system ("make");
    system ("make install DESTDIR=$cwd"); # abspath. install into libffi/lib, bin and include
    $incdir = "$cwd/include";
    $libdir = "$cwd/lib";
    if ($^O eq 'cygwin') { # copy the bin/*.dll
      mkdir "bin";
      File::Copy::cp('bin/libffi-*.dll', 'bin/');
    }
    chdir "..";
  } else { # MSWin32
    warn "Using the builtin win32 binaries $libffi_version\n";
    # built with mingw32
    # install via http://sourceforge.net/projects/mingw/files/Automated%20MinGW%20Installer/mingw-get-inst/
    my $cwd = getcwd;
    $libdir = "win32";
    $incdir = File::Spec->catfile($cwd, $libdir,"include");
    # be sure to install the dll on site, because we link only to the import lib
    mkdir "bin";
    File::Copy::cp(File::Spec->catfile($libdir, "libffi-5.dll"), "bin");
  }
} else {
  warn "Using system libffi.\n";
  warn "If too old (failing tests) install libffi.tar.gz and use INCDIR and LIBDIR.\n";
  warn "  tar xfz libffi.tar.gz; cd libffi; ./configure DESTDIR=`cwd`; make && make install\n";
  warn "  perl Makefile.PL INCDIR=libffi/include LIBDIR=libffi/lib\n";
}

WriteMakefile(
    NAME              => 'Ctypes',
    VERSION_FROM      => 'lib/Ctypes.pm',
    ABSTRACT_FROM     => 'lib/Ctypes.pm',
    AUTHOR            => 'Ryan Jendoubi <ryan d\x{00f6}t jendoubi at gmail d\x{00f6}t com',
    PREREQ_PM         => {},
    LIBS              => $libdir ? [ "-L$libdir -lffi" ] : [ "-lffi" ],
    INC               => $incdir ? "-I. -I$incdir" : "-I.",
);

if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw|FFI_LONG_LONG_MAX FFI_SIZEOF_ARG FFI_SIZEOF_JAVA_RAW
		 FFI_TYPE_DOUBLE FFI_TYPE_FLOAT FFI_TYPE_INT FFI_TYPE_LAST
		 FFI_TYPE_LONGDOUBLE FFI_TYPE_POINTER FFI_TYPE_SINT16
		 FFI_TYPE_SINT32 FFI_TYPE_SINT64 FFI_TYPE_SINT8 FFI_TYPE_STRUCT
		 FFI_TYPE_UINT16 FFI_TYPE_UINT32 FFI_TYPE_UINT64 FFI_TYPE_UINT8
		 FFI_TYPE_VOID PERL_SHORT_MIN PERL_SHORT_MAX PERL_USHORT_MIN
                 PERL_USHORT_MAX PERL_INT_MIN PERL_INT_MAX PERL_UINT_MIN
                 PERL_UINT_MAX PERL_LONG_MIN PERL_LONG_MAX PERL_ULONG_MIN
                 PERL_ULONG_MAX DBL_MIN DBL_MAX FLT_MIN FLT_MAX LDBL_MIN
                 LDBL_MAX PERL_UCHAR_MIN PERL_UCHAR_MAX|,
              {name=>"FFI_BAD_ABI", macro=>"1"},
              {name=>"FFI_BAD_TYPEDEF", macro=>"1"},
              {name=>"FFI_OK", macro=>"1"});
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'Ctypes',
                                     NAMES        => \@names,
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                     DEFAULT_TYPE => 'NV',
                                  );

}
else {
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('win32', $file);
    File::Copy::cp ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}

sub MY::depend {
    "
const-xs.inc: $0 \$(CONFIGDEP)

const-c.inc: $0 \$(CONFIGDEP)

Ctypes.c: \$(XSUBPPDEPS) const-xs.inc \$(XS_FILES) util.c obj_util.c
";
}
