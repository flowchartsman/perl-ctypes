#  use inc::Module::Install;
#
#  name     'Ctypes';
#  all_from 'lib/Ctypes.pm';
#  author   q{Ryan Jendoubi <ryan.jendoubi@gmail.com>};
#  license  'artistic';
#
#  build_requires 'Test::More';
#
#  requires_external_bin 'libffi';
#
#  WriteAll;

use 5.010000;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Ctypes',
    VERSION_FROM      => 'lib/Ctypes.pm',
    PREREQ_PM         => {},
    ($] >= 5.005 ?  
     (ABSTRACT_FROM     => 'lib/Ctypes.pm',
      AUTHOR            => 'Ryan Jendoubi <ryan d\x{00f6}t jendoubi at gmail d\x{00f6}t com', )
     : () ),
    LIBS              => [ '-Llibffi -lffi' ],
    INC               => '-I. -I./include',
    #OPTIMIZE         => '-ggdb3 -O0',
    #LDDLFLAGS        => '-shared -L/usr/local/lib -fstack-protector',
    NEEDS_LINKING     => 1,
);
if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw(FFI_LONG_LONG_MAX FFI_SIZEOF_ARG FFI_SIZEOF_JAVA_RAW
		 FFI_TYPE_DOUBLE FFI_TYPE_FLOAT FFI_TYPE_INT FFI_TYPE_LAST
		 FFI_TYPE_LONGDOUBLE FFI_TYPE_POINTER FFI_TYPE_SINT16
		 FFI_TYPE_SINT32 FFI_TYPE_SINT64 FFI_TYPE_SINT8 FFI_TYPE_STRUCT
		 FFI_TYPE_UINT16 FFI_TYPE_UINT32 FFI_TYPE_UINT64 FFI_TYPE_UINT8
		 FFI_TYPE_VOID ffi_type_longdouble ffi_type_schar ffi_type_sint
		 ffi_type_slong ffi_type_sshort ffi_type_uchar ffi_type_uint
		 ffi_type_ulong ffi_type_ushort),
              {name=>"FFI_BAD_ABI", macro=>"1"},
              {name=>"FFI_BAD_TYPEDEF", macro=>"1"},
              {name=>"FFI_OK", macro=>"1"});
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'Ctypes',
                                     NAMES        => \@names,
                                     DEFAULT_TYPE => 'ffi_type',
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                  );

}
else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}
