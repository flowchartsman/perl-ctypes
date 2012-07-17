# Usage:
# perl Makefile.PL INCDIR=/usr/src/libffi-3.0.10/include LIBDIR=/usr/src/libffi-3.0.10/lib

#use 5.010000;
use Carp;
use ExtUtils::MakeMaker;
use Config;
use File::Copy;
use File::Spec;
use feature 'say';
use subs qw|create_ctypes_limits_h get_fp_define_values|; 
our $libffi_version = "3.0.10rc3";

# check the installed version of libffi and override default libdir and incdir
use lib qw(inc);
use Devel::CheckLib;
my ($libdir, $incdir);
my $args = join(" ", @ARGV);
if ($args =~ /INCDIR[ =](\S+)/) {
  $incdir = $1;
}
if ($args =~ /LIBDIR[ =](\S+)/) {
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
    system ($ENV{SHELL},"./configure --prefix=/");
    system ("make");
    system ("make install DESTDIR='$cwd'"); # abspath. install into libffi/lib, bin and include
    $incdir = "$cwd/include";
    $libdir = "$cwd/lib";
    if ($^O eq 'cygwin') { # copy the bin/*.dll
      mkdir "bin";
      File::Copy::cp('lib/cygffi-*.dll', 'bin/');
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
  warn "  If too old (failing _call tests) install our libffi.tar.gz and use INCDIR and LIBDIR.\n";
  warn "  tar xfz libffi.tar.gz; cd libffi; . configure --prefix=/; make && make install DESTDIR=`pwd`; cd ..\n";
  warn "  perl Makefile.PL INCDIR=libffi/include LIBDIR=libffi/lib\n";
}

WriteMakefile(
    NAME              => 'Ctypes',
    VERSION_FROM      => 'lib/Ctypes.pm',
    ABSTRACT_FROM     => 'lib/Ctypes.pm',
    AUTHOR            => 'Ryan Jendoubi <ryan d\x{00f6}t jendoubi at gmail d\x{00f6}t com, Reini Urban',
    PREREQ_PM         => {},
    BUILD_REQUIRES    => {"Regexp::Common" => 0},
    LIBS              => $libdir ? [ "-L$libdir -lffi" ] : [ "-lffi" ],
    INC               => $incdir ? "-I. -I$incdir" : "-I.",
    realclean         => {FILES => "Ctypes_float_minima.h"},
);

sub get_fp_define_values {
  my $self = shift;
  my $filename = "Ctypes_float_minima_test";
  my @needed = qw|FLT_MIN DBL_MIN LDBL_MIN|;
  map { $_ = 'CTYPES_' . $_ } @needed;
  my @candidate;
  my $vals;
  my $cleanup = sub {
	unlink ("$filename.c", "$filename$self->{EXE_EXT}",
		"$filename$self->{OBJ_EXT}");
  };
  &$cleanup;
  unless (open PROG, ">$filename.c") {
	print ("Can't write $filename.c\n");
	return undef;
  }
  print PROG <<'PROG';
#include <stdio.h>
#include <limits.h>
#include <float.h>
int main()
{
    float f_max = FLT_MAX;
    float f_try = -FLT_MAX + 1;
    float f_last_try = 0;
    float f_delta = FLT_EPSILON;
    float f_min = 0;
    do {
      f_last_try = f_min = f_try;
      f_try = f_try - f_delta;
      if( f_try == f_last_try )
        break;
    } while ( f_try < f_max && f_try < 0 );
    double d_max = DBL_MAX;
    double d_try = -DBL_MAX + 1;
    double d_last_try = 0;
    double d_delta = DBL_EPSILON;
    double d_min = 0;
    do {
      d_last_try = d_min = d_try;
      d_try = d_try - d_delta;
      if( d_try == d_last_try )
        break;
    } while ( d_try < d_max && d_try < 0 );
    long double ld_max = LDBL_MAX;
    long double ld_try = -LDBL_MAX + 1;
    long double ld_last_try = 0;
    long double ld_delta = LDBL_EPSILON;
    long double ld_min = 0;
    do {
      ld_last_try = ld_min = ld_try;
      ld_try = ld_try - ld_delta;
      if( ld_try == ld_last_try )
        break;
    } while ( ld_try < ld_max && ld_try < 0 );
    printf("%f\n", f_min);
    printf("%f\n", d_min);
    printf("%Lf\n", ld_min);
    return 0;
}
PROG
  close PROG;
  my $ccflags = $Config{ccflags};
  @candidate = ();
  $devnull = $^O eq 'MSWin32' ? "> NUL" : ">/dev/null 2>&1";
  push @candidate, "$Config{cc} $Config{ccflags} -DNARF $filename.c -o $filename$self->{EXE_EXT} $devnull"
	unless $Verbose;
  push @candidate, "$Config{cc} $Config{ccflags} -DNARF $filename.c -o$filename$self->{EXE_EXT} $devnull"
	unless $Verbose;
  push @candidate, "$Config{cc} $Config{ccflags} -DNARF $filename.c -o $filename$self->{EXE_EXT}";
  push @candidate, "$Config{cc} $Config{ccflags} -DNARF $filename.c -o$filename$self->{EXE_EXT}";
  while ($self->{how_to_compile} = shift (@candidate)) {
	unlink "$filename$self->{EXE_EXT}";
	system ($self->{how_to_compile});
	last if $? == 0 && -x "$filename$self->{EXE_EXT}";
  }
  &$cleanup && return undef unless $self->{how_to_compile};
  @candidate = ();
  push @candidate, "./$filename$self->{EXE_EXT} $devnull"
	unless $Verbose;
  push @candidate, "$filename$self->{EXE_EXT} $devnull"
	unless $Verbose;
  push @candidate, "$filename$self->{EXE_EXT}";
  push @candidate, "./$filename$self->{EXE_EXT}";
  push @candidate, "run $filename$self->{EXE_EXT}";
  while ($self->{how_to_run} = shift (@candidate)) {
    my @output = qx/$self->{how_to_run}/;
    if( $? == 0 && @output ) {
      $self->{Ctypes_limits}->{$_} = shift @output
        for @needed;
      &$cleanup;
      return $self->{Ctypes_limits};
    }
  }
  &$cleanup;
  return undef;
}

sub create_ctypes_limits_h {
  my $self = shift;
  croak "Couldn't get limits!"
    unless my $vals = get_fp_define_values;
  croak "Can't write Ctypes_float_minima.h"
   unless (open HEADER, ">Ctypes_float_minima.h");
  print HEADER <<"HEADER";
/*###########################################################################
## Name:        Ctypes_float_minima.h
## Purpose:     Generated by Ctypes.pm Makefile.PL to define minimum
##              (-ve) value alternatives to FLT_MIN, DBL_MIN etc
## Author:      Ryan Jendoubi
## Based on:    C::DynaLib's Makefile.PL
## Created:     2012-06-28
## Copyright:   (c) 2012 Ryan Jendoubi
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the Artistic License 2.0. For details see
##              http://www.opensource.org/licenses/artistic-license-2.0.php
###########################################################################*/
#ifndef _INC_CTYPES_FLOAT_MINIMA_H
#define _INC_CTYPES_FLOAT_MINIMA_H

#define CTYPES_FLT_MIN $vals->{CTYPES_FLT_MIN}
#define CTYPES_DBL_MIN $vals->{CTYPES_DBL_MIN}
#define CTYPES_LDBL_MIN $vals->{CTYPES_LDBL_MIN}

#endif
HEADER
  close HEADER;   
}

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
                 PERL_ULONG_MAX PERL_UCHAR_MIN PERL_UCHAR_MAX CHAR_MIN CHAR_MAX
                 FLT_MAX CTYPES_FLT_MIN FLT_EPSILON
                 DBL_MAX CTYPES_DBL_MIN DBL_EPSILON
                 LDBL_MAX CTYPES_LDBL_MIN LDBL_EPSILON|,
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
  my $self = shift;
  create_ctypes_limits_h;
    "
const-xs.inc: $0 \$(CONFIGDEP)

const-c.inc: $0 \$(CONFIGDEP)

Ctypes.c: \$(XSUBPPDEPS) const-xs.inc \$(XS_FILES) util.c obj_util.c

README : lib/Ctypes.pm
	pod2text lib/Ctypes.pm > README

gcov : Ctypes.c.gcov Ctypes.xs.gcov cover_db/Ctypes-xs.html

Ctypes.c.gcov Ctypes.xs.gcov : Ctypes.xs
	\$(MAKE) CCFLAGS=\"\$(CCFLAGS) -fprofile-arcs -ftest-coverage\" LDDLFLAGS=\"\$(LDDLFLAGS) -fprofile-arcs -ftest-coverage\"
	gcov Ctypes.c Ctypes.xs

cover_db/Ctypes-xs.html : Ctypes.xs.gcov
	-PERL5OPT=-MDevel::Cover make test
	-$^X -S gcov2perl Ctypes.c.gcov Ctypes.xs.gcov
	$^X -S cover

gprof :
	\$(MAKE) CCFLAGS=\"\$(CCFLAGS) -pg\" LDDLFLAGS=\"\$(LDDLFLAGS) -pg\"
";
}
