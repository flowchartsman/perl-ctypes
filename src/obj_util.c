/*###########################################################################
## Name:        obj_utils.c
## Purpose:     Utility functions for working with Ctypes objects, to make
##              Ctypes.xs prettier to read
## Author:      Ryan Jendoubi
## Based on:    Python's ctypes-1.0.6
## Created:     2010-07-27
## Copyright:   (c) 2010 Ryan Jendoubi
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the Artistic License 2.0. For details see
##              http://www.opensource.org/licenses/artistic-license-2.0.php
###########################################################################*/

#ifndef _INC_OBJ_UTILS_C
#define _INC_OBJ_UTILS_C

SV*
Ct_HVObj_GET_ATTR_KEY(SV* obj, const char* key) {
debug_warn("# In Ct_HVObj_GET_ATTR_KEY...");
debug_warn("#    key is %s", key);
  SV **tmp, *res = NULL;
  int klen = strlen(key);
  if( sv_isobject(obj)
      && (SvTYPE(SvRV(obj)) == SVt_PVHV)
      && hv_exists((HV*)SvRV(obj), key, klen) ) {
    debug_warn("#    Obj checks out, getting %s attribute...", key);
    tmp = hv_fetch((HV*)SvRV(obj), key, klen, 0);
    if( tmp != NULL )
      res = SvREFCNT_inc(*tmp);
    else
      debug_warn("Eek! Couldn't find that attribute!");
  } else {
      debug_warn("Object wasn't what you thought!");
  }
  return res;
}

int
Ct_Obj_IsDeriv(SV* var, const char* type) {
debug_warn("# In Ct_Obj_IsDeriv...");
debug_warn("#    type is %s", type);
  if( sv_isobject(var)
         && ( sv_isa(var, type)
              || sv_derived_from(var, type)
            )
    ) {
    debug_warn("#    returning True!");
    return 1;
  }
  else {
    debug_warn("#    returning False!");
    return 0;
  }
}

int
Ct_IsCoderef(SV* arg) {
  if( SvROK(arg)
      && (SvTYPE(SvRV(arg)) == SVt_PVCV)
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

AV*
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
  if( !Ct_IsCoderef(callable) )
    croak("Ct_CallPerlFunction: arg 1 not a coderef");
  
  SV *result, *tmp, **fetched;
  int i, n, count;
  dSP;

  EXTEND(SP,n);
  ENTER;
  SAVETMPS;

  PUSHMARK(SP);
  n = av_len(args);
  for( i = 0; i <= n; ++i ) {
    fetched = av_fetch(args,i,0);
    if( fetched != NULL )
      PUSHs(sv_2mortal(newSVsv(*fetched)));
    else
      croak("Ct_CallPerlFunction:%i error: couldn't get arg from AV",
            __LINE__);
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
    if( ary != NULL ) {
      SV** stored;
      int i, fail = 0;
      for( i = 0; i <= n; ++i ) {
        tmp = POPs;
        stored = av_store(ary,i,tmp); /* XXX need to REFCNT_inc here?? */
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

#endif  /* _INC_OBJ_UTILS_C */