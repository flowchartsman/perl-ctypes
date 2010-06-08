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
static void validate_signature (char *sig)
{
    STRLEN i;
    STRLEN len = strlen(sig);

    if (len < 2)
        croak("Invalid function signature: %s (too short)", sig);

    if (*sig != 'c' && *sig != 's')
        croak("Invalid function signature: '%c' (should be 'c' or 's')", *sig);

    if (strchr("cCsSiIlLfdpv", sig[1]) == NULL)
        croak("Invalid return type: '%c' (should be one of \"cCsSiIlLfdpv\")", sig[1]);

    i = strspn(sig+2, "cCsSiIlLfdp");
    if (i != len-2)
        croak("Invalid argument type (arg %d): '%c' (should be one of \"cCsSiIlLfdp\")",
              i+1, sig[i+2]);
}

/* `Libffi' assumes that you have a pointer to the function you wish to
		call and that you know the number and types of arguments to pass it, as
		well as the return type of the function.
		-- We Ptypes::call() can work this out before invoking ffi_call()?	*/
		
MODULE = Ctypes		PACKAGE = Ctypes

# INCLUDE: const-xs.inc

SV*
call( addr, sig, ... )
    int addr;
    void (*)() func;
    char *sig;   // sig = <callconv><rettype><argtypes...>
  PROTOTYPE: $$;$
  INIT:
    ffi_cif cif;
    ffi_status cif_status;
    unsigned int nargs;
    ffi_type *argtypes[items - 2];
    void *argvalues[items - 2];
    void *rvalue;
    ffi_type *rtype;
  PPCODE:
    
    validate_signature(sig);
    
    switch (sig[1])   // Get return type
    {
    case 'v': rtype = &ffi_type_void;         break;
    case 'c': rtype = &ffi_type_schar;        break;
    case 'C': rtype = &ffi_type_uchar;        break;
    case 's': rtype = &ffi_type_sshort;       break;
    case 'S': rtype = &ffi_type_ushort;       break;
    case 'i': rtype = &ffi_type_sint;         break;
    case 'I': rtype = &ffi_type_uint;         break;
    case 'l': rtype = &ffi_type_slong;        break;
    case 'L': rtype = &ffi_type_ulong;        break;
    case 'f': rtype = &ffi_type_float;        break;
    case 'd': rtype = &ffi_type_double;       break;
    case 'D': rtype = &ffi_type_longdouble;   break;
    case 'p': rtype = &ffi_type_pointer;      break;
    }
    
    int i;
    for (i = 2; i < items; ++i){    // Get number of args & their values
      STRLEN len;
      char type = sig[i];

      if (type == 0)
          croak("FFI::call - too many args (%d expected)", i - 2);
      
      nargs = 0;
      void *anSV;
      switch(type)
      {
      case 'c': argtypes[nargs] = &ffi_type_schar;      argvalues[nargs] = newSViv(SvIV(ST(i)));         break;
      case 'C': argtypes[nargs] = &ffi_type_uchar;      argvalues[nargs] = newSViv(SvIV(ST(i)));         break;
      case 's': argtypes[nargs] = &ffi_type_sshort;     argvalues[nargs] = newSViv(SvIV(ST(i)));         break;
      case 'S': argtypes[nargs] = &ffi_type_ushort;     argvalues[nargs] = newSViv(SvIV(ST(i)));         break;
      case 'i': argtypes[nargs] = &ffi_type_sint;       argvalues[nargs] = newSViv(SvIV(ST(i)));         break;
      case 'I': argtypes[nargs] = &ffi_type_uint;       argvalues[nargs] = newSViv(SvIV(ST(i)));         break;
      case 'l': argtypes[nargs] = &ffi_type_slong;      argvalues[nargs] = newSViv(SvIV(ST(i)));         break;
      case 'L': argtypes[nargs] = &ffi_type_ulong;      argvalues[nargs] = newSViv(SvIV(ST(i)));         break;
      case 'f': argtypes[nargs] = &ffi_type_float;      argvalues[nargs] = newSVnv(SvNV(ST(i)));         break;
      case 'd': argtypes[nargs] = &ffi_type_double;     argvalues[nargs] = newSVnv(SvNV(ST(i)));         break;
      case 'D': argtypes[nargs] = &ffi_type_longdouble; argvalues[nargs] = newSVnv(SvNV(ST(i)));         break;
      case 'p': argtypes[nargs] = &ffi_type_pointer;    argvalues[nargs] = newSVpv(SvPV(ST(i), len), len);    break;
      }
    }

    if( ffi_prep_cif(&cif, FFI_DEFAULT_ABI, nargs, rtype, argtypes) == FFI_OK ) {
      ffi_call(&cif, addr, &rvalue, argvalues);
      switch (sig[1])
      {
      case 'v': break;
      case 'c': XPUSHs(newSViv(*(int*)(rvalue)));   break;
      case 'C': XPUSHs(newSViv(*(int*)(rvalue)));   break;
      case 's': XPUSHs(newSViv(*(int*)(rvalue)));   break;
      case 'S': XPUSHs(newSViv(*(int*)(rvalue)));   break;
      case 'i': XPUSHs(newSViv(*(int*)(rvalue)));   break;
      case 'I': XPUSHs(newSViv(*(int*)(rvalue)));   break;
      case 'l': XPUSHs(newSViv(*(int*)(rvalue)));   break;
      case 'L': XPUSHs(newSViv(*(int*)(rvalue)));   break;
      case 'f': XPUSHs(newSVnv(*(float*)(rvalue)));    break;
      case 'd': XPUSHs(newSVnv(*(double*)(rvalue)));    break;
      case 'D': XPUSHs(newSVnv(*(long double*)(rvalue)));    break;
      case 'p': XPUSHs(newSVpv(rvalue, 0)); break;
      }
    }
