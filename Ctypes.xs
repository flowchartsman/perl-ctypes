/*###########################################################################
## Name:        Ctypes.xs
## Purpose:     Perl binding to libffi
## Author:      Ryan Jendoubi
## Based on:    FFI.pm, P5NCI.pm
## Created:     2010-05-21
## Copyright:   (c) 2010 Ryan Jendoubi
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
###########################################################################*/

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "ffi.h"

// #include "const-c.inc"

// Copied verbatim from FFI.xs on 21/05/2010: http://cpansearch.perl.org/src/GAAL/FFI-1.04/FFI.xs
static int validate_signature (char *sig)
{
    STRLEN i;
    STRLEN len = strlen(sig);

    if (len < 2)
        croak("Invalid function signature: %s (too short)", sig);

    if (sig[0] != 'c' && *sig != 's')
        croak("Invalid function signature: '%c' (should be 'c' or 's')", sig[0]);

    if (strchr("cCsSiIlLfdpv", sig[1]) == NULL)
        croak("Invalid return type: '%c' (should be one of \"cCsSiIlLfdpv\")", sig[1]);

    i = strspn(sig+2, "cCsSiIlLfdp");
    if (i != len-2)
        croak("Invalid argument type (arg %d): '%c' (should be one of \"cCsSiIlLfdp\")",
              i+1, sig[i+2]);
    return (len - 2);
}

ffi_type* get_ffi_type(char type)
{
  switch (type) {
    case 'v': return &ffi_type_void;         break;
    case 'c': return &ffi_type_schar;        break;
    case 'C': return &ffi_type_uchar;        break;
    case 's': return &ffi_type_sshort;       break;
    case 'S': return &ffi_type_ushort;       break;
    case 'i': return &ffi_type_sint;         break;
    case 'I': return &ffi_type_uint;         break;
    case 'l': return &ffi_type_slong;        break;
    case 'L': return &ffi_type_ulong;        break;
    case 'f': return &ffi_type_float;        break;
    case 'd': return &ffi_type_double;       break;
    case 'D': return &ffi_type_longdouble;   break;
    case 'p': return &ffi_type_pointer;      break;
    default: croak( "Unrecognised type: %c!", type );
  }
}

MODULE = Ctypes		PACKAGE = Ctypes

void
call( addr, sig, ... )
    int addr;
    char* sig;
  PROTOTYPE: $$;$
  PPCODE:
#ifdef CTYPES_TEST_VERBOSE
    warn( "\n\n[Ctypes.xs: %i ] XS_Ctypes_call( %x, \"%s\",...)", __LINE__, addr, sig );
    warn( "Module compiled with -DCTYPES_TEST_VERBOSE for detailed output from XS" );
    warn( "Remove this -D define in Makefile.PL to disable this option" );
#endif
    int num_args = items - 2;
    if( num_args < 0 ) {
      croak( "INIT: You must provide at least the calling convention and return type" );
    } else {
    }
    ffi_cif cif;
    ffi_status status;
    unsigned int nargs;
    ffi_type *argtypes[num_args];
    void *argvalues[num_args];
    void *rvalue;
    ffi_type *rtype;
    STRLEN len;
    int args_in_sig;
    args_in_sig = validate_signature(sig);
    if( args_in_sig != num_args ) {
      croak( "[Ctypes.xs: %i ] Error: specified %i arguments but supplied %i", __LINE__, args_in_sig, num_args );
#ifdef CTYPES_TEST_VERBOSE
    } else {
       warn( "[Ctypes.xs: %i ] Sig validated, %i args supplied", __LINE__, num_args );
#endif
    }

    rtype = get_ffi_type( sig[1] );
    switch(sig[1])
    {
      case 'c': Newxc(rvalue, 1, char, char);         break;
      case 'C': Newxc(rvalue, 1, unsigned char, unsigned char);         break;
      case 's': Newxc(rvalue, 1, short, short);         break;
      case 'S': Newxc(rvalue, 1, unsigned short, unsigned short);         break;
      case 'i': Newxc(rvalue, 1, int, int);         break;
      case 'I': Newxc(rvalue, 1, unsigned int, unsigned int);          break;
      case 'l': Newxc(rvalue, 1, long, long);          break;
      case 'L': Newxc(rvalue, 1, unsigned long, unsigned long);         break;
      case 'f': Newxc(rvalue, 1, float, float);        break;
      case 'd': Newxc(rvalue, 1, double, double);         break;
      case 'D': Newxc(rvalue, 1, long double, long double);        break;
      case 'p': Newx(rvalue, 1, void);         break;
      default: croak( "Unrecognised type: %c!", sig[1] );   // should never happen here
    }        
#ifdef CTYPES_TEST_VERBOSE
    warn( "[Ctypes.xs: %i ] Return type found: %c", __LINE__,  sig[1] );
#endif

    if( num_args > 0 ) {
#ifdef CTYPES_TEST_VERBOSE
    warn( "[Ctypes.xs: %i ] Getting types & values of args...", __LINE__ );
#endif
      int i;
      for (i = 0; i < num_args; ++i){
        char type = sig[i+2];
#ifdef CTYPES_TEST_VERBOSE
        warn( "  type %i: %c", i+1, type);
#endif
        if (type == 0)
            croak("Ctypes::call - too many args (%d expected)", i - 2); // should never happen here

        argtypes[i] = get_ffi_type(type);
        // Could pop ST(0) & ST(1) (func pointer & sig) off beforehand to make this neater?
        switch(type)
        {
        case 'c':
          Newxc(argvalues[i], 1, char, char);
          *(char*)argvalues[i] = SvIV(ST(i+2));
          break;
        case 'C':
          Newxc(argvalues[i], 1, unsigned char, unsigned char);
          *(unsigned char*)argvalues[i] = SvIV(ST(i+2));
          break;
        case 's':
          Newxc(argvalues[i], 1, short, short);
          *(short*)argvalues[i] = SvIV(ST(i+2));
          break;
        case 'S':
          Newxc(argvalues[i], 1, unsigned short, unsigned short);
          *(unsigned short*)argvalues[i] = SvIV(ST(i+2));
          break;
        case 'i':
          Newxc(argvalues[i], 1, int, int);
          *(int*)argvalues[i] = SvIV(ST(i+2));
          break;
        case 'I':
          Newxc(argvalues[i], 1, unsigned int, unsigned int);
          *(int*)argvalues[i] = SvIV(ST(i+2));
          break;
        case 'l':
          Newxc(argvalues[i], 1, long, long);
          *(long*)argvalues[i] = SvIV(ST(i+2));
          break;
        case 'L':
          Newxc(argvalues[i], 1, unsigned long, unsigned long);
          *(unsigned long*)argvalues[i] = SvIV(ST(i+2));
         break;
        case 'f':
          Newxc(argvalues[i], 1, float, float);
          *(float*)argvalues[i] = SvNV(ST(i+2));
          break;
        case 'd':
          Newxc(argvalues[i], 1, double, double);
          *(double*)argvalues[i]  = SvNV(ST(i+2));
          break;
        case 'D':
          Newxc(argvalues[i], 1, long double, long double);
          *(long double*)argvalues[i] = SvNV(ST(i+2));
          break;
        case 'p':
          Newx(argvalues[i], 1, void);
          argvalues[i] = SvPV(ST(i+2), len);
          break;
        default: croak( "Unrecognised type: %c!", type );   // should never happen here
        }        
      }
#ifdef CTYPES_TEST_VERBOSE
    } else {
      warn( "[Ctypes.xs: %i ] No argtypes/values to get", __LINE__ );
#endif
    }
// ABI needs to default to 'SYSV' on Linux/Cygwin
// Taking call convs into account is still TODO
    if((status = ffi_prep_cif
         (&cif,
          FFI_DEFAULT_ABI,
          num_args, rtype, argtypes)) != FFI_OK ) {
#ifdef CTYPES_TEST_VERBOSE
    croak( "[Ctypes.xs: %i ] ffi_prep_cif error: %d", __LINE__, status );
#endif

    }
#ifdef CTYPES_TEST_VERBOSE
      warn( "[Ctypes.xs: %i ] cif OK. Calling ffi_call...", __LINE__ );
      warn( "  addr is: %i ", addr );
      warn( "  rvalue is: %p ", rvalue );
      warn( "  argvalues is: %f ", *(double*)argvalues[0] );
#endif

      ffi_call(&cif, (void*)addr, rvalue, argvalues);
#ifdef CTYPES_TEST_VERBOSE
      warn( "ffi_call returned normally with rvalue: %f", *(double*)rvalue );
      warn( "[Ctypes.xs: %i ] Pushing retvals to Perl stack...", __LINE__ );
#endif
      switch (sig[1])
      {
      case 'v': break;
      case 'c': XPUSHs(sv_2mortal(newSViv(*(int*)(rvalue))));   break;
      case 'C': XPUSHs(sv_2mortal(newSViv(*(int*)(rvalue))));   break;
      case 's': XPUSHs(sv_2mortal(newSViv(*(int*)(rvalue))));   break;
      case 'S': XPUSHs(sv_2mortal(newSViv(*(int*)(rvalue))));   break;
      case 'i': XPUSHs(sv_2mortal(newSViv(*(int*)(rvalue))));   break;
      case 'I': XPUSHs(sv_2mortal(newSViv(*(int*)(rvalue))));   break;
      case 'l': XPUSHs(sv_2mortal(newSViv(*(int*)(rvalue))));   break;
      case 'L': XPUSHs(sv_2mortal(newSViv(*(int*)(rvalue))));   break;
      case 'f': XPUSHs(sv_2mortal(newSVnv(*(float*)(rvalue))));    break;
      case 'd': XPUSHs(sv_2mortal(newSVnv(*(double*)(rvalue))));    break;
      case 'D': XPUSHs(sv_2mortal(newSVnv(*(long double*)(rvalue))));    break;
      case 'p': XPUSHs(sv_2mortal(newSVpv(rvalue, 0))); break;

      }
#ifdef CTYPES_TEST_VERBOSE
      warn( "[Ctypes.xs: %i ] Cleaning up...", __LINE__ );
#endif
    int i = 0;
    for( i = 0; i < num_args; i++ ) {
      Safefree(argvalues[i]);
#ifdef CTYPES_TEST_VERBOSE
      warn( "[Ctypes.xs: %i ] Successfully free'd argvalues[%i]", __LINE__, i );
#endif
    }
#ifdef CTYPES_TEST_VERBOSE
      warn( "[Ctypes.xs: %i ] Leaving XS_Ctypes_call...", __LINE__ );
#endif
