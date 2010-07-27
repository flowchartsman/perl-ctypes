/*###########################################################################
## Name:        Ctypes.h
## Purpose:     Struct definitions and function declarations for Ctypes
## Author:      Ryan Jendoubi
## Based on:    C::DynaLib; Python's ctypes module
## Created:     2010-07-27
## Copyright:   (c) 2010 Ryan Jendoubi
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the Artistic License 2.0. For details see
##              http://www.opensource.org/licenses/artistic-license-2.0.php
###########################################################################*/

#ifndef _INC_CTYPES_H
#define _INC_CTYPES_H

#ifdef CTYPES_DEBUG
#define debug_warn( ... ) warn( __VA_ARGS__ )
#else
#define debug_warn( ... )
#endif

typedef struct _cb_data_t {
  char* sig;
  SV* coderef;
  ffi_cif* cif;
  ffi_closure* closure; 
} cb_data_t;

/* from Py's callproc.c, for _CallProc */
union result {
        char c;
        char b;
        short h;
        int i;
        long l;
/*
#ifdef HAVE_LONG_LONG
        PY_LONG_LONG q;
#endif
*/
        double d;
        float f;
        void *p;
};

struct argument {
        ffi_type* ffi_type;
        SV* keep;
        union result value;
};

#endif /* _INC_CTYPES_H */
