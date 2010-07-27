/*###########################################################################
## Name:        py_funcs.c
## Purpose:     Utility functions adapted from Python / ctypes source
## Author:      Ryan Jendoubi
## Based on:    Python's ctypes-1.0.6
## Created:     2010-07-27
## Copyright:   (c) 2010 Ryan Jendoubi
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the Artistic License 2.0. For details see
##              http://www.opensource.org/licenses/artistic-license-2.0.php
###########################################################################*/

#ifndef _INC_PY_FUNCS_C
#define _INC_PY_FUNCS_C

SV*
Ct_AVref_GET_ITEM(SV* tuple, int i) {
  if( SvROK(tuple) && SvTYPE(SvRV(tuple)) == SVt_PVAV ) {
    return SvREFCNT_inc((SV*)*(av_fetch((AV*)SvRV(tuple), i, 0)));
  } else {
    return newSV(0);
  }
}

/* Named differently from the Py equivalent to disambiguate from
   Perl array functions which usually return the highest index */
int
Ct_AVref_GET_NUM_ELEMS(SV* avref) {
  if( SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV ) {
    return av_len((AV*)SvRV(avref)) + 1;
  } else {
    return -1;
  }
}

SV*
Ct_CallPerlFunctionSVArgs(SV* callable, ...) {
/*  debug_warn( "\n#[%s:%i] Entered Ct_CallPerlFunctionSVArgs",
              __FILE__, __LINE__ );
  SV *args, *tmp;
  va_list vargs;

  if (callable == NULL)
      return null_error();

  /* count the args */
/*  va_start(vargs, callable);
  args = objargs_mktuple(vargs);
  va_end(vargs);
  if (args == NULL)
      return NULL;
  tmp = PyObject_Call(callable, args, NULL);
  Py_DECREF(args);

  return tmp; */
}

#endif
