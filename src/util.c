/*###########################################################################
## Name:        util.c
## Purpose:     Miscellaneous utility functions for Ctypes.xs
## Author:      Ryan Jendoubi
## Based on:    FFI.pm; C::DynaLib
## Created:     2010-07-27
## Copyright:   (c) 2010 Ryan Jendoubi
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the Artistic License 2.0. For details see
##              http://www.opensource.org/licenses/artistic-license-2.0.php
###########################################################################*/

#ifndef _INC_UTIL_C
#define _INC_UTIL_C

// Copied verbatim from FFI.xs on 21/05/2010: http://cpansearch.perl.org/src/GAAL/FFI-1.04/FFI.xs
static int
validate_signature (char *sig)
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


ffi_type*
get_ffi_type(char type)
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

#endif
