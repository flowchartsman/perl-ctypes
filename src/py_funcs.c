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

int
Ct_IsCoderef(SV* var) {
  if( SvROK(this_converter)
      && (SvTYPE(SvRV(this_converter)) == SVt_PVCV)
    )
    return 1;
  else
    return 0;
}

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
Ct_SVargs_mkAV(va_list va) {
  int i, n = 0;
  va_list countva;
  SV* tmp;
  AV* result;
/* this is set by Python's configure; replicate in Makefile.PL? */
#ifdef VA_LIST_IS_ARRAY
  Copy(va, countva, 1, va_list);
#else
#ifdef __va_copy
  __va_copy(countva, va);
#else
  countva = va;
#endif
#endif

  while(((SV*)va_arg(countva, SV*)) != NULL)
    ++n;
  result = newAV();
  if( result != NULL && n > 0 ) {
    for( i = 0; i < n; ++i ) {
      tmp = (SV*)va_arg(va, SV*);
      av_push(result,tmp);
      SvREFCNT_inc(tmp);  /* XXX is this necessary? */
    }
  }
  return result;
}

SV*
Ct_CallPerlFunction(SV* callable, AV* args) {
  if( Ct_IsCoderef(callable) ) {
    SV *result, *tmp;
    int n, count;
    dSP;

    EXTEND(SP,n);

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    n = av_len(args);
    for( int i = 0; i <= n; ++i ) {
      PUSHs(sv_2mortal(newSVsv(av_fetch(args,i,0))));
    }
    PUTBACK;
    
    count = call_sv(callable, G_ARRAY);

    if( count == 0 ) {
      result = NULL;
    } else if ( count == 1 ) {
      SPAGAIN;
      result = newSVsv(POPs);
    } else {
      SPAGAIN;
      AV* ary = newAV();
      if( arg != NULL ) {
        SV** stored;
        int fail = 0;
        for( int i = 0; i <= n; ++i ) {
          tmp = POPs;
          stored = av_store(ary,i,tmp) /* XXX need to REFCNT_inc here?? */
          if( stored == NULL ) {
            fail = 1;
            SvREFCNT_dec(tmp);
          }
        }
        if( !fail ) {
          result = newRV_noinc((SV*)ary);
        } else {
          result = NULL;
        }
      } else {
        result == NULL;
      }
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return result;
  }
  croak("Ct_CallPerlFunction: arg 1 not a coderef");
  return NULL;
}


SV*
Ct_CallPerlFunctionSVArgs(SV* callable, ...) {
  debug_warn( "\n#[%s:%i] Entered Ct_CallPerlFunctionSVArgs",
              __FILE__, __LINE__ );
  AV* args;
  SV* tmp;
  va_list vargs;

  /* count the args */
  va_start(vargs, callable);
  args = Ct_SVargs_mkAV(vargs);
  va_end(vargs);
  if (args == NULL)
   /* SvREFCNT_dec(callable); Py does this here but I'm not sure XXX */
      return NULL;
  tmp = Ct_CallPerlFunction(callable, args);
  SvREFCNT_dec(args);

  return tmp;
}

#endif
