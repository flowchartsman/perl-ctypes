#define PERL_constant_NOTFOUND	1
#define PERL_constant_NOTDEF	2
#define PERL_constant_ISIV	3
#define PERL_constant_ISNO	4
#define PERL_constant_ISNV	5
#define PERL_constant_ISPV	6
#define PERL_constant_ISPVN	7
#define PERL_constant_ISSV	8
#define PERL_constant_ISUNDEF	9
#define PERL_constant_ISUV	10
#define PERL_constant_ISYES	11

#ifndef NVTYPE
typedef double NV; /* 5.6 and later define NVTYPE, and typedef NV to it.  */
#endif
#ifndef aTHX_
#define aTHX_ /* 5.6 or later define this for threading support.  */
#endif
#ifndef pTHX_
#define pTHX_ /* 5.6 or later define this for threading support.  */
#endif

static int
constant_13 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     FFI_TYPE_LAST FFI_TYPE_VOID ffi_type_sint ffi_type_uint */
  /* Offset 9 gives the best switch position.  */
  switch (name[9]) {
  case 'L':
    if (memEQ(name, "FFI_TYPE_LAST", 13)) {
    /*                        ^          */
#ifdef FFI_TYPE_LAST
      *iv_return = FFI_TYPE_LAST;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'V':
    if (memEQ(name, "FFI_TYPE_VOID", 13)) {
    /*                        ^          */
#ifdef FFI_TYPE_VOID
      *iv_return = FFI_TYPE_VOID;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 's':
    if (memEQ(name, "ffi_type_sint", 13)) {
    /*                        ^          */
#ifdef ffi_type_sint
      *iv_return = ffi_type_sint;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'u':
    if (memEQ(name, "ffi_type_uint", 13)) {
    /*                        ^          */
#ifdef ffi_type_uint
      *iv_return = ffi_type_uint;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_14 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     FFI_SIZEOF_ARG FFI_TYPE_FLOAT FFI_TYPE_SINT8 FFI_TYPE_UINT8 ffi_type_schar
     ffi_type_slong ffi_type_uchar ffi_type_ulong */
  /* Offset 10 gives the best switch position.  */
  switch (name[10]) {
  case 'I':
    if (memEQ(name, "FFI_TYPE_SINT8", 14)) {
    /*                         ^          */
#ifdef FFI_TYPE_SINT8
      *iv_return = FFI_TYPE_SINT8;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "FFI_TYPE_UINT8", 14)) {
    /*                         ^          */
#ifdef FFI_TYPE_UINT8
      *iv_return = FFI_TYPE_UINT8;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'L':
    if (memEQ(name, "FFI_TYPE_FLOAT", 14)) {
    /*                         ^          */
#ifdef FFI_TYPE_FLOAT
      *iv_return = FFI_TYPE_FLOAT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case '_':
    if (memEQ(name, "FFI_SIZEOF_ARG", 14)) {
    /*                         ^          */
#ifdef FFI_SIZEOF_ARG
      *iv_return = FFI_SIZEOF_ARG;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'c':
    if (memEQ(name, "ffi_type_schar", 14)) {
    /*                         ^          */
#ifdef ffi_type_schar
      *iv_return = ffi_type_schar;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "ffi_type_uchar", 14)) {
    /*                         ^          */
#ifdef ffi_type_uchar
      *iv_return = ffi_type_uchar;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'l':
    if (memEQ(name, "ffi_type_slong", 14)) {
    /*                         ^          */
#ifdef ffi_type_slong
      *iv_return = ffi_type_slong;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "ffi_type_ulong", 14)) {
    /*                         ^          */
#ifdef ffi_type_ulong
      *iv_return = ffi_type_ulong;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_15 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     FFI_BAD_TYPEDEF FFI_TYPE_DOUBLE FFI_TYPE_SINT16 FFI_TYPE_SINT32
     FFI_TYPE_SINT64 FFI_TYPE_STRUCT FFI_TYPE_UINT16 FFI_TYPE_UINT32
     FFI_TYPE_UINT64 ffi_type_sshort ffi_type_ushort */
  /* Offset 13 gives the best switch position.  */
  switch (name[13]) {
  case '1':
    if (memEQ(name, "FFI_TYPE_SINT16", 15)) {
    /*                            ^        */
#ifdef FFI_TYPE_SINT16
      *iv_return = FFI_TYPE_SINT16;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "FFI_TYPE_UINT16", 15)) {
    /*                            ^        */
#ifdef FFI_TYPE_UINT16
      *iv_return = FFI_TYPE_UINT16;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case '3':
    if (memEQ(name, "FFI_TYPE_SINT32", 15)) {
    /*                            ^        */
#ifdef FFI_TYPE_SINT32
      *iv_return = FFI_TYPE_SINT32;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "FFI_TYPE_UINT32", 15)) {
    /*                            ^        */
#ifdef FFI_TYPE_UINT32
      *iv_return = FFI_TYPE_UINT32;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case '6':
    if (memEQ(name, "FFI_TYPE_SINT64", 15)) {
    /*                            ^        */
#ifdef FFI_TYPE_SINT64
      *iv_return = FFI_TYPE_SINT64;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "FFI_TYPE_UINT64", 15)) {
    /*                            ^        */
#ifdef FFI_TYPE_UINT64
      *iv_return = FFI_TYPE_UINT64;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'C':
    if (memEQ(name, "FFI_TYPE_STRUCT", 15)) {
    /*                            ^        */
#ifdef FFI_TYPE_STRUCT
      *iv_return = FFI_TYPE_STRUCT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'E':
    if (memEQ(name, "FFI_BAD_TYPEDEF", 15)) {
    /*                            ^        */
      *iv_return = FFI_BAD_TYPEDEF;
      return PERL_constant_ISIV;
    }
    break;
  case 'L':
    if (memEQ(name, "FFI_TYPE_DOUBLE", 15)) {
    /*                            ^        */
#ifdef FFI_TYPE_DOUBLE
      *iv_return = FFI_TYPE_DOUBLE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'r':
    if (memEQ(name, "ffi_type_sshort", 15)) {
    /*                            ^        */
#ifdef ffi_type_sshort
      *iv_return = ffi_type_sshort;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "ffi_type_ushort", 15)) {
    /*                            ^        */
#ifdef ffi_type_ushort
      *iv_return = ffi_type_ushort;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_19 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     FFI_SIZEOF_JAVA_RAW FFI_TYPE_LONGDOUBLE ffi_type_longdouble */
  /* Offset 18 gives the best switch position.  */
  switch (name[18]) {
  case 'E':
    if (memEQ(name, "FFI_TYPE_LONGDOUBL", 18)) {
    /*                                 E      */
#ifdef FFI_TYPE_LONGDOUBLE
      *iv_return = FFI_TYPE_LONGDOUBLE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'W':
    if (memEQ(name, "FFI_SIZEOF_JAVA_RA", 18)) {
    /*                                 W      */
#ifdef FFI_SIZEOF_JAVA_RAW
      *iv_return = FFI_SIZEOF_JAVA_RAW;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'e':
    if (memEQ(name, "ffi_type_longdoubl", 18)) {
    /*                                 e      */
#ifdef ffi_type_longdouble
      *iv_return = ffi_type_longdouble;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant (pTHX_ const char *name, STRLEN len, IV *iv_return) {
  /* Initially switch on the length of the name.  */
  /* When generated this function returned values for the list of names given
     in this section of perl code.  Rather than manually editing these functions
     to add or remove constants, which would result in this comment and section
     of code becoming inaccurate, we recommend that you edit this section of
     code, and use it to regenerate a new set of constant functions which you
     then use to replace the originals.

     Regenerate these constant functions by feeding this entire source file to
     perl -x

#!C:\strawberry\perl\bin\perl.exe -w
use ExtUtils::Constant qw (constant_types C_constant XS_constant);

my $types = {map {($_, 1)} qw(IV)};
my @names = (qw(FFI_LONG_LONG_MAX FFI_SIZEOF_ARG FFI_SIZEOF_JAVA_RAW
	       FFI_TYPE_DOUBLE FFI_TYPE_FLOAT FFI_TYPE_INT FFI_TYPE_LAST
	       FFI_TYPE_LONGDOUBLE FFI_TYPE_POINTER FFI_TYPE_SINT16
	       FFI_TYPE_SINT32 FFI_TYPE_SINT64 FFI_TYPE_SINT8 FFI_TYPE_STRUCT
	       FFI_TYPE_UINT16 FFI_TYPE_UINT32 FFI_TYPE_UINT64 FFI_TYPE_UINT8
	       FFI_TYPE_VOID ffi_type_longdouble ffi_type_schar ffi_type_sint
	       ffi_type_slong ffi_type_sshort ffi_type_uchar ffi_type_uint
	       ffi_type_ulong ffi_type_ushort),
            {name=>"FFI_BAD_ABI", type=>"IV", macro=>"1"},
            {name=>"FFI_BAD_TYPEDEF", type=>"IV", macro=>"1"},
            {name=>"FFI_OK", type=>"IV", macro=>"1"});

print constant_types(), "\n"; # macro defs
foreach (C_constant ("Ptypes2", 'constant', 'IV', $types, undef, 3, @names) ) {
    print $_, "\n"; # C constant subs
}
print "\n#### XS Section:\n";
print XS_constant ("Ptypes2", $types);
__END__
   */

  switch (len) {
  case 6:
    if (memEQ(name, "FFI_OK", 6)) {
      *iv_return = FFI_OK;
      return PERL_constant_ISIV;
    }
    break;
  case 11:
    if (memEQ(name, "FFI_BAD_ABI", 11)) {
      *iv_return = FFI_BAD_ABI;
      return PERL_constant_ISIV;
    }
    break;
  case 12:
    if (memEQ(name, "FFI_TYPE_INT", 12)) {
#ifdef FFI_TYPE_INT
      *iv_return = FFI_TYPE_INT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 13:
    return constant_13 (aTHX_ name, iv_return);
    break;
  case 14:
    return constant_14 (aTHX_ name, iv_return);
    break;
  case 15:
    return constant_15 (aTHX_ name, iv_return);
    break;
  case 16:
    if (memEQ(name, "FFI_TYPE_POINTER", 16)) {
#ifdef FFI_TYPE_POINTER
      *iv_return = FFI_TYPE_POINTER;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 17:
    if (memEQ(name, "FFI_LONG_LONG_MAX", 17)) {
#ifdef FFI_LONG_LONG_MAX
      *iv_return = FFI_LONG_LONG_MAX;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 19:
    return constant_19 (aTHX_ name, iv_return);
    break;
  }
  return PERL_constant_NOTFOUND;
}

