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

//#include "const-c.inc"
#ifdef CTYPES_DEBUG
#define debug_warn( ... ) warn( __VA_ARGS__ )
#else
#define debug_warn( ... )
#endif

// Copied verbatim from FFI.xs on 21/05/2010: http://cpansearch.perl.org/src/GAAL/FFI-1.04/FFI.xs
static int validate_signature (char *sig)
{
    STRLEN i;
    STRLEN len = strlen(sig);
    int args_in_sig;

    if (len < 2)
        croak("Invalid function signature: %s (too short)", sig);

    if (sig[0] != 'c' && *sig != 's')
        croak("Invalid function signature: '%c' (should be 'c' or 's')", sig[0]);

    if (strchr("cCsSiIlLfdDpv", sig[1]) == NULL)
        croak("Invalid return type: '%c' (should be one of \"cCsSiIlLfdDpv\")", sig[1]);

    i = strspn(sig+2, "cCsSiIlLfdDp");
    args_in_sig = len - 2;
    if (i != args_in_sig)
        croak("Invalid argument type (arg %d): '%c' (should be one of \"cCsSiIlLfdDp\")",
              i+1, sig[i+2]);
    return args_in_sig;
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

# INCLUDE: const-xs.inc

#define strictchar char

void
_call( addr, sig, ... )
    void* addr;
    strictchar* sig;
  # PROTOTYPE: $$;@
  PPCODE:
    ffi_cif cif;
    ffi_status status;
    unsigned int nargs;
    ffi_type *rtype;
    char *rvalue;
    STRLEN len;
    int args_in_sig, rsize;
    int num_args = items - 2;
    ffi_type *argtypes[num_args];
    void *argvalues[num_args];
 
    debug_warn( "\n#[Ctypes.xs: %i ] XS_Ctypes_call( 0x%x, \"%s\", ...)", __LINE__, (unsigned int)addr, sig );
    debug_warn( "#Module compiled with -DCTYPES_DEBUG for detailed output from XS" );
#ifndef PERL_ARGS_ASSERT_CROAK_XS_USAGE
    if( num_args < 0 ) {
      croak( "Ctypes::_call error: Not enough arguments" );
    }
#endif

    args_in_sig = validate_signature(sig);
    if( args_in_sig != num_args ) {
      croak( "Ctypes::_call error: specified %i arguments but supplied %i", 
	     __LINE__, args_in_sig, num_args );
    } else {
       debug_warn( "#[Ctypes.xs: %i ] Sig validated, %i args supplied", 
	     __LINE__, num_args );
    }

    rtype = get_ffi_type( sig[1] );
    debug_warn( "#[Ctypes.xs: %i ] Return type found: %c", __LINE__,  sig[1] );
    rsize = FFI_SIZEOF_ARG;
    if (sig[1] == 'd') rsize = sizeof(double);
    if (sig[1] == 'D') rsize = sizeof(long double);
    rvalue = (char*)malloc(rsize);

    if( num_args > 0 ) {
      int i;
      debug_warn( "#[Ctypes.xs: %i ] Getting types & values of args...", __LINE__ );
      for (i = 0; i < num_args; ++i){
        char type = sig[i+2];
        debug_warn( "#  type %i: %c", i+1, type);
        if (type == 0)
	  croak("Ctypes::_call error: too many args (%d expected)", i - 2); /* should never happen here */

        argtypes[i] = get_ffi_type(type);
        /* Could pop ST(0) & ST(1) (func pointer & sig) off beforehand to make this neater? */
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
        /* should never happen here */
        default: croak( "Ctypes::_call error: Unrecognised type '%c'", type );
        }        
      }
    } else {
      debug_warn( "#[Ctypes.xs: %i ] No argtypes/values to get", __LINE__ );
    }
    if((status = ffi_prep_cif
         (&cif,
	  /* x86-64 uses for 'c' UNIX64 resp. WIN64, which is f not c */
          sig[0] == 's' ? FFI_STDCALL : FFI_DEFAULT_ABI,
          num_args, rtype, argtypes)) != FFI_OK ) {
      croak( "Ctypes::_call error: ffi_prep_cif error %d", status );
    }

    debug_warn( "#[Ctypes.xs: %i ] cif OK. Calling ffi_call...", __LINE__ );
    debug_warn( "#  addr is: 0x%x ", (unsigned int)addr );
    debug_warn( "#  argvalues is: %f", *(double*)argvalues[0] );

    ffi_call(&cif, FFI_FN(addr), rvalue, argvalues);
    debug_warn( "#ffi_call returned normally with rvalue at 0x%x", (unsigned int)rvalue );
    debug_warn( "#[Ctypes.xs: %i ] Pushing retvals to Perl stack...", __LINE__ );
    switch (sig[1])
    {
      case 'v': break;
      case 'c': 
      case 'C': XPUSHs(sv_2mortal(newSViv(*(int*)rvalue)));   break;
      case 's': 
      case 'S': XPUSHs(sv_2mortal(newSVpv(*(char *)rvalue, 0)));   break;
      case 'i': XPUSHs(sv_2mortal(newSViv(*(int*)rvalue)));   break;
      case 'I': XPUSHs(sv_2mortal(newSVuv(*(unsigned int*)rvalue)));   break;
      case 'l': XPUSHs(sv_2mortal(newSViv(*(long*)rvalue)));   break;
      case 'L': XPUSHs(sv_2mortal(newSVuv(*(unsigned long*)rvalue)));   break;
      case 'f': XPUSHs(sv_2mortal(newSVnv(*(float*)rvalue)));    break;
      case 'd': XPUSHs(sv_2mortal(newSVnv(*(double*)rvalue)));    break;
      case 'D': XPUSHs(sv_2mortal(newSVnv(*(long double*)rvalue)));    break;
      case 'p': XPUSHs(sv_2mortal(newSVpv((void*)rvalue, 0))); break;
    }

    debug_warn( "#[Ctypes.xs: %i ] Cleaning up...", __LINE__ );
    free(rvalue);
    int i = 0;
    for( i = 0; i < num_args; i++ ) {
      Safefree(argvalues[i]);
      debug_warn( "#[Ctypes.xs: %i ] Successfully free'd argvalues[%i]", __LINE__, i );
    }
    debug_warn( "#[Ctypes.xs: %i ] Leaving XS_Ctypes_call...\n\n", __LINE__ );

int 
sizeof(type)
    char type;
CODE:
  switch (type) {
  case 'v': RETVAL = 0;           break;
  case 'c':
  case 'C': RETVAL = 1;           break;
  case 's':
  case 'S': RETVAL = 2;           break;
  case 'i': 
  case 'I': RETVAL = sizeof(int); break;
  case 'l': 
  case 'L': RETVAL = sizeof(long);  break;
  case 'f': RETVAL = sizeof(float); break;
  case 'd': RETVAL = sizeof(double);     break;
  case 'D': RETVAL = sizeof(long double);break;
  case 'p': RETVAL = sizeof(void*);      break;
  default: croak( "Unrecognised type: %c", type );
  }
