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
#include "limits.h"
#include "Ctypes.h"
#include "src/py_funcs.c"
#include "src/util.c"

//#include "const-c.inc"
#ifdef CTYPES_DEBUG
#define debug_warn( ... ) warn( __VA_ARGS__ )
#else
#define debug_warn( ... )
#endif


void _perl_cb_call( ffi_cif* cif, void* retval, void** args, void* udata )
{
    dSP;
    debug_warn( "\n#[%s:%i] Entered _perl_cb_call...", __FILE__, __LINE__ );

    unsigned int i;
    int flags = G_SCALAR;
    unsigned int count = 0;
    char type;
    STRLEN len;
    cb_data_t* data = (cb_data_t*)udata;
    char* sig = data->sig;

    if( sig[0] == 'v' ) { flags = G_VOID; }

    if( cif->nargs > 0 ) {
      debug_warn( "#[%s:%i] Have %i args so pushing to stack...",
                __FILE__, __LINE__, cif->nargs );
      ENTER;
      SAVETMPS;

      PUSHMARK(SP);
      for( i = 0; i < cif->nargs; i++ ) {
        type = sig[i+1]; /* sig[0] = return type */
        switch (type)
        {
          case 'v': break;
          case 'c': 
          case 'C': XPUSHs(sv_2mortal(newSViv(*(int*)*(void**)args[i])));   break;
          case 's': 
          case 'S': XPUSHs(sv_2mortal(newSVpv((char*)*(void**)args[i], 0)));   break;
          case 'i':
              debug_warn( "#    Have type %c, pushing %i to stack...",
                          type, *(int*)*(void**)args[i] );
              XPUSHs(sv_2mortal(newSViv(*(int*)*(void**)args[i])));   break;
          case 'I': XPUSHs(sv_2mortal(newSVuv(*(unsigned int*)*(void**)args[i])));   break;
          case 'l': XPUSHs(sv_2mortal(newSViv(*(long*)*(void**)args[i])));   break;
          case 'L': XPUSHs(sv_2mortal(newSVuv(*(unsigned long*)*(void**)args[i])));   break;
          case 'f': XPUSHs(sv_2mortal(newSVnv(*(float*)*(void**)args[i])));    break;
          case 'd': XPUSHs(sv_2mortal(newSVnv(*(double*)*(void**)args[i])));    break;
          case 'D': XPUSHs(sv_2mortal(newSVnv(*(long double*)*(void**)args[i])));    break;
          case 'p':
              debug_warn( "#    Have type %c, pushing to stack...",
                          type );
              XPUSHs(sv_2mortal(newSVpv((char*)*(void**)args[i], 0))); break;
        }
      }
    PUTBACK;
    }

    debug_warn( "#[%s:%i] Calling Perl sub...", __FILE__, __LINE__, sig );
    count = call_sv(data->coderef, G_SCALAR);
    debug_warn( "#[%s:%i] Returned from Perl sub with %i values", __FILE__, __LINE__, count );

    SPAGAIN;

    if( sig[0] != 'v' ) {
      if( count != 1 ) {
        croak( "_perl_cb_call:%i: Expected single %c from Perl callback",
               __LINE__, sig[0] );
      }
      if( count > 1 && sig[0] != 'p' ) {
       croak( "_perl_cb_call:%i: Received multiple values from Perl \
callback; expected %c", __LINE__, sig[0] );
      }
      type = sig[0];
      switch(type)
      {
      case 'c':
        *(char*)retval = POPi;
        break;
      case 'C':
          *(unsigned char*)retval = POPi;
          break;
        case 's':
          *(short*)retval = POPi;
          break;
        case 'S':
          *(unsigned short*)retval = POPi;
          break;
        case 'i':
          *(int*)retval = POPi;
          debug_warn( "#[%s:%i] retval is %i!", __FILE__, __LINE__, *(int*)retval );
          break;
        case 'I':
          *(int*)retval = POPi;
          break;
        case 'l':
          *(long*)retval = POPl;
          break;
        case 'L':
          *(unsigned long*)retval = POPl;
         break;
        case 'f':
          *(float*)retval = POPn;
          break;
        case 'd':
          *(double*)retval  = POPn;
          break;
        case 'D':
          *(long double*)retval = POPn;
          break;
        case 'p':
          croak( "_perl_cb_call: Returning pointers from Perl subs not yet implemented!" );
        /*  len = sv_len(SP[0]);
          debug_warn( "#_perl_cb_call: Got a pointer..." );
          if(SvIOK(SP[0])) {
            debug_warn( "#    [%i] SvIOK: assuming 'PTR2IV' value",  __LINE__ );
            char* thing = POPpx;
            *(intptr_t*)retval = (intptr_t)INT2PTR(void*, SvIV(ST(i+2)));
          } else {
            debug_warn( "#    [%i] Not SvIOK: assuming 'pack' value",  __LINE__ );
            debug_warn( "#    [%i] sizeof packed array (sv_len): %i",  __LINE__, (int)len );
            debug_warn( "#    [%i] %i items in array (assumed int)",  __LINE__, (int)((int)len/sizeof(int)) );
            *(intptr_t*)retval = (intptr_t)SvPVbyte(ST(i+2), len);
#ifdef CTYPES_DEBUG
            int j;
            for( j = 0; j < ((int)len/sizeof(int)); j++ ) {
                debug_warn( "#    argvalues[%i][%i]: %i", i, j, ((int*)*(intptr_t*)retval)[j] );
            }
#endif
          } */
          break;
        /* should never happen here */
        default: croak( "_perl_cb_call error: Unrecognised type '%c'", type );
        }        
    }

    PUTBACK;
    FREETMPS;
    LEAVE;
}
    
MODULE = Ctypes		PACKAGE = Ctypes

# INCLUDE: const-xs.inc

#define strictchar char

void
_call( addr, sig, ... )
    void* addr;
    strictchar* sig;
  PROTOTYPE: DISABLE
  PPCODE:
    /* PROTOTYPE: $$;@ ? */
    ffi_cif cif;
    ffi_status status;
    ffi_type *rtype;
    char *rvalue;
    STRLEN len;
    unsigned int args_in_sig, rsize;
    unsigned int num_args = items - 2;
    ffi_type *argtypes[num_args];
    void *argvalues[num_args];
 
    debug_warn( "\n#[Ctypes.xs: %i ] XS_Ctypes_call( 0x%x, \"%s\", ...)", __LINE__, (unsigned int)(intptr_t)addr, sig );
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
      char type;
      debug_warn( "#[Ctypes.xs: %i ] Getting types & values of args...", __LINE__ );
      for (i = 0; i < num_args; ++i){
        type = sig[i+2];
        debug_warn( "#  type %i: %c", i+1, type);
        if (type == 0)
	  croak("Ctypes::_call error: too many args (%d expected)", i - 2); /* should never happen here */

        argtypes[i] = get_ffi_type(type);
        /* Could pop ST(0) & ST(1) (func pointer & sig) off beforehand to make this neater? */
        SV* thisSV = ST(i+2);
        if(SvROK(thisSV)) {
          thisSV = SvRV(ST(i+2));
        }
        switch(type)
        {
        case 'c':
          Newxc(argvalues[i], 1, char, char);
          *(char*)argvalues[i] = SvIV(thisSV);
          break;
        case 'C':
          Newxc(argvalues[i], 1, unsigned char, unsigned char);
          *(unsigned char*)argvalues[i] = SvIV(thisSV);
          break;
        case 's':
          Newxc(argvalues[i], 1, short, short);
          *(short*)argvalues[i] = SvIV(thisSV);
          break;
        case 'S':
          Newxc(argvalues[i], 1, unsigned short, unsigned short);
          *(unsigned short*)argvalues[i] = SvIV(thisSV);
          break;
        case 'i':
          Newxc(argvalues[i], 1, int, int);
          *(int*)argvalues[i] = SvIV(thisSV);
          break;
        case 'I':
          Newxc(argvalues[i], 1, unsigned int, unsigned int);
          *(int*)argvalues[i] = SvIV(thisSV);
          break;
        case 'l':
          Newxc(argvalues[i], 1, long, long);
          *(long*)argvalues[i] = SvIV(thisSV);
          break;
        case 'L':
          Newxc(argvalues[i], 1, unsigned long, unsigned long);
          *(unsigned long*)argvalues[i] = SvIV(thisSV);
         break;
        case 'f':
          Newxc(argvalues[i], 1, float, float);
          *(float*)argvalues[i] = SvNV(thisSV);
          break;
        case 'd':
          Newxc(argvalues[i], 1, double, double);
          *(double*)argvalues[i]  = SvNV(thisSV);
          break;
        case 'D':
          Newxc(argvalues[i], 1, long double, long double);
          *(long double*)argvalues[i] = SvNV(thisSV);
          break;
        case 'p':
          len = sv_len(thisSV);
          Newx(argvalues[i], 1, void);
          if(SvIOK(thisSV)) {
            debug_warn( "#    [%i] Pointer: SvIOK: assuming 'PTR2IV' value",  __LINE__ );
            *(intptr_t*)argvalues[i] = (intptr_t)INT2PTR(void*, SvIV(thisSV));
          } else {
            debug_warn( "#    [%i] Pointer: Not SvIOK: assuming 'pack' value",  __LINE__ );
            *(intptr_t*)argvalues[i] = (intptr_t)SvPVX(thisSV);
          }
          break;
        /* should never happen here */
        default: croak( "Ctypes::_call error: Unrecognised type '%c' (line %i)",
                         type, __LINE__ );
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

    debug_warn( "#[%s:%i] cif OK.", __FILE__, __LINE__ );

    debug_warn( "#[%s:%i] Calling ffi_call...", __FILE__, __LINE__ );
    ffi_call(&cif, FFI_FN(addr), rvalue, argvalues);
    debug_warn( "#ffi_call returned normally with rvalue at 0x%x", (unsigned int)(intptr_t)rvalue );
    debug_warn( "#[%s:%i] Pushing retvals to Perl stack...", __FILE__, __LINE__ );
    switch (sig[1])
    {
      case 'v': break;
      case 'c': 
      case 'C': XPUSHs(sv_2mortal(newSViv(*(int*)rvalue)));   break;
      case 's': 
      case 'S': XPUSHs(sv_2mortal(newSVpv((char *)rvalue, 0)));   break;
      case 'i': XPUSHs(sv_2mortal(newSViv(*(int*)rvalue)));   break;
      case 'I': XPUSHs(sv_2mortal(newSVuv(*(unsigned int*)rvalue)));   break;
      case 'l': XPUSHs(sv_2mortal(newSViv(*(long*)rvalue)));   break;
      case 'L': XPUSHs(sv_2mortal(newSVuv(*(unsigned long*)rvalue)));   break;
      case 'f': XPUSHs(sv_2mortal(newSVnv(*(float*)rvalue)));    break;
      case 'd': XPUSHs(sv_2mortal(newSVnv(*(double*)rvalue)));    break;
      case 'D': XPUSHs(sv_2mortal(newSVnv(*(long double*)rvalue)));    break;
      case 'p': XPUSHs(sv_2mortal(newSVpv((void*)rvalue, 0))); break;
    }

    debug_warn( "#[%s:%i] Cleaning up...", __FILE__, __LINE__ );
    free(rvalue);
    int i = 0;
    for( i = 0; i < num_args; i++ ) {
      Safefree(argvalues[i]);
      debug_warn( "#    Successfully free'd argvalues[%i]", i );
    }
    debug_warn( "#[%s:%i] Leaving XS_Ctypes_call...\n\n", __FILE__, __LINE__ );

SV*
_CallProc( pProc, argtuple, pIunk, iid, flags, converters, restype, checker )
    SV* pProc;
    SV* argtuple;
    SV* pIunk;
    int flags;
    SV* converters;
    SV* restype;
    SV* checker;
  PROTOTYPE: \$\@\$\$\$\$\$\$
  CODE:
    /* pProc *should* be type PPROC */
    /* pIunk should be type IUnknown, Win32 only */
    /* iid should be type GUID, Win32 only */
    /* Note: "converters" is called "argtypes" in the Py func,
       but this is a misnomer */
    int i, n, argcount, converter_count;
    void* resbuf;
    struct argument *args, *pa;
    ffi_type **atypes;
    ffi_type *rtype;
    void **avalues;
    SV* retval = NULL;
    AV* callargs = NULL;

    /* First thought to convert argtuple SV* ref -> AV*,
       but it'll be easier following the Py code for now not to

    if (SvROK(argtuple) && SvTYPE(SvRV(argtuple))==SVt_PVAV)
        callargs = (AV*)SvRV(argtuple);
    else
        croak("[%s:%s] is not an array reference", __FILE__, __LINE__);
         ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]}, \"$var\") */

    n = argcount = av_len(callargs) + 1;
#ifdef MS_WIN32
    /* an optional COM object this pointer */
    /* XXX The Win32 conditional stuff in Perl space isn't written yet! */
    if (pIunk)
      ++argcount;
#endif
    Newxz(args, argcount, struct argument);
    if(!args)
      croak("[%s:%i] _CallProc: Out of memory!", __FILE__, __LINE__);

    converter_count = converters ? Ct_AVref_GET_NUM_ELEMS(converters) : 0;
    if( converter_count == -1 )
      croak("[%s:%i] _CallProc: convertors must be an array reference!",
            __FILE__, __LINE__);
#ifdef MS_WIN32
    if(pIunk) {
      args[0].ffi_type = &ffi_type_pointer;
      /* XXX this definitely needs looked at
         Not sure how pIunk has been defined in Perl space */
      args[0].value.p = INT2PTR(pIunk);
      pa = &args[1];
    } else
#endif
        pa = &args[0];

    /* Convert the arguments */
    for( i = 0; i < n; ++i, ++pa) {
      SV* this_converter;
      SV* arg;
      int err;

      arg = Ct_AVref_GET_ITEM(argtuple, i); /* REM to decref later! */
      if( !SvOK(arg) )
        croak("[%s:%i] _CallProc: argtuple must be an array reference!",
              __FILE__, __LINE__);
      /* For cdecl functions, we allow more actual arguments
         than the length of the argtypes tuple.
         This is checked in _ctypes::CFuncPtr_Call  */
      if(converters && converter_count > i) {
        SV* v;
        /* REM to decref later! */
        this_converter = Ct_AVref_GET_ITEM(converters, i);
        if( !SvOK(this_converter)
            || !( SvROK(this_converter)
                  && SvTYPE(SvRV(this_converter)) == SVt_PVCV 
                )
          )
          croak("[%s:%i] _CallProc: converter %i invalid!",
                __FILE__, __LINE__, i);
        v = Ct_CallPerlFunctionSVArgs(this_converter, arg, NULL);


        /* XXX XXX */
      }
    }


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
OUTPUT:
  RETVAL

int
valid_type_value(arg,type)
  SV* arg;
  char type;
CODE:
  double max;
  short i;
  if( !SvOK(arg) ) { XSRETURN_UNDEF; }
  switch (type) {
    case 'c':
    case 'C':
      if( !SvPOK(arg) ) { RETVAL = 0; break; }
      if( sv_len(arg) != 1 ) { RETVAL = 0; break; }
      RETVAL = 1; break;
    case 's':
    case 'S':
      if( !SvPOK(arg) ) { RETVAL = 0; break; }
      RETVAL = 1; break;
    case 'i':
      if( SvPOK(arg) ) { RETVAL = 0; break; }
      if( !SvIOK(arg) ) { RETVAL = 0; break; }
   /*   signed int max = 1;
      for(i=1;i<(sizeof(signed int) * 8 - 1);i++) {
        max = max << 1; max | 1;
      }  */
      /* max = 1 << (sizeof(signed int) * 8 - 1); */
      double thearg = SvNV(arg);
      if( thearg < INT_MIN || thearg > INT_MAX ) { RETVAL = -1; break; }
      /* if( thearg > max ) { RETVAL = 0; break; } */
      RETVAL = 1; break;
    case 'I':
      if( SvNOK(arg) ) { RETVAL = 0; break; }
      if( !SvIOK(arg) ) { RETVAL = 0; break; }
      max = 1 << (sizeof(unsigned int) * 8); 
      if( (unsigned int)SvIV(arg) > max ) { RETVAL = 0; break; }
      RETVAL = 1; break;
    case 'l':
      if( SvNOK(arg) ) { RETVAL = 0; }
      if( !SvIOK(arg) ) { RETVAL = 0; break; }
      max = 1 << (sizeof(signed long) * 8 - 1);
      if( (signed long)SvIV(arg) > max ) { RETVAL = 0; break; }
      RETVAL = 1; break;
    case 'L':
      if( SvNOK(arg) ) { RETVAL = 0; break; }
      if( !SvIOK(arg) ) { RETVAL = 0; break; }
      max = 1 << (sizeof(unsigned long) * 8 - 1);
      if( (unsigned long)SvIV(arg) > max ) { RETVAL = 0; break; }
      RETVAL = 1; break;
    case 'f':
      if( !SvNOK(arg) ) { RETVAL = 0; break; }
      max = 1 << (sizeof(float) * 8 - 1);
      if( (float)SvNV(arg) > max ) { RETVAL = 0; break; }
      RETVAL = 1; break;
    case 'd':
      if( !SvNOK(arg) ) { RETVAL = 0; break; }
      max = 1 << (sizeof(double) * 8 - 1);
      if( (double)SvNV(arg) > max ) { RETVAL = 0; break; }
      RETVAL = 1; break;
    case 'D':
      if( !SvNOK(arg) ) { RETVAL = 0; break; }
      max = 1 << (sizeof(long double) * 8 - 1);
      if( (long double)SvNV(arg) > max ) { RETVAL = 0; break; }
      RETVAL = 1; break;
    case 'p':
      if( !SvPOK(arg) ) { RETVAL = 0; break; }
      RETVAL = 1; break;
    default: croak( "Invalid type: %c", type );
  }
OUTPUT:
  RETVAL

SV*
_cast_value(arg_sv,type)
  SV* arg_sv;
  char type;
CODE:
  /* XXX almost wholly unimplemented! Only 'i' works */
  void *rvalue, *argvalue;
  NV num_arg;
  RETVAL = 0;
  switch (type) {
    case 'c':
    case 'C':
      RETVAL = newSViv((char)*(int*)argvalue);
      break;
    case 's':
    case 'S':
      RETVAL = newSVpv((char*)argvalue, 0);
      break;
    case 'i':
      if(SvIOK(arg_sv) || SvNOK(arg_sv)) {
        signed int retval;
        num_arg = SvNV(arg_sv);
        retval = (int)num_arg;
        RETVAL = newSViv(retval);
        break;
      } else if(SvPOK(arg_sv)) {
        RETVAL = newSViv((int)(SvPV_nolen(arg_sv))[0]);
        break;
      }
      RETVAL = -1;
      break;
    case 'I':
    case 'l':
    case 'L':
    case 'f':
    case 'd':
#ifdef HAS_LONG_DOUBLE
    case 'D':
#endif
    case 'p':
    default: croak( "Unimplemented / Invalid type: %c", type );
  }
OUTPUT:
  RETVAL

MODULE=Ctypes	PACKAGE=Ctypes::Callback

void
_make_callback( coderef, sig, ... )
    STRLEN siglen = 0;
    SV* coderef = newSVsv(ST(0));
    char* sig = (char*)SvPV(ST(1), siglen);
  PPCODE:
    /* It should be remembered that unlike Ctypes::_call above,
       sig here won't include an abi (since it refers to a Perl
       function), so offsets for arg types will always be +1, not +2 */
    ffi_status status = FFI_BAD_TYPEDEF;
    ffi_type *rtype;
    char *rvalue;
    unsigned int args_in_sig, rsize;
    unsigned int num_args = siglen - 1;
    ffi_type** argtypes;
    cb_data_t* cb_data;
    void* code;
    ffi_cif* cb_cif;
    ffi_closure* closure;

    debug_warn( "\n#[%s:%i] Entered _make_callback", __FILE__, __LINE__ );
    
    debug_warn( "#[%s:%i] Allocating memory for  closure...", __FILE__, __LINE__ );
    closure = ffi_closure_alloc( sizeof(ffi_closure), &code );

    Newx( cb_data, 1, cb_data_t );
    Newx(cb_data->cif, 1, ffi_cif);
    Newx(argtypes, num_args, ffi_type*);

    debug_warn( "#[%s:%i] Setting rtype '%c'", __FILE__, __LINE__, sig[0] );
    rtype = get_ffi_type( sig[0] );

    if( num_args > 0 ) {
      int i;
      for( i = 0; i < num_args; i++ ) {
        argtypes[i] = get_ffi_type(sig[i+1]); 
        debug_warn( "#    Got argtype '%c'", sig[i+1] );
      }
    }

    debug_warn( "#[%s:%i] Prep'ing cif for _perl_cb_call...", __FILE__, __LINE__ ); 
    if((status = ffi_prep_cif
        (cb_data->cif,
         /* Might Perl XS libs use stdcall on win32? How to check? */
         FFI_DEFAULT_ABI,
         num_args, rtype, argtypes)) != FFI_OK ) {
       croak( "Ctypes::_call error: ffi_prep_cif error %d", status );
     }

    debug_warn( "#[%s:%i] Prep'ing closure...", __FILE__, __LINE__ ); 
    if((status = ffi_prep_closure_loc
        ( closure, cb_data->cif, &_perl_cb_call, cb_data, code )) != FFI_OK ) {
        croak( "Ctypes::Callback::new error: ffi_prep_closure_loc error %d",
            status );
        }

    cb_data->sig = sig;
    cb_data->coderef = coderef;
    cb_data->closure = closure;

    unsigned int len = sizeof(intptr_t);
    XPUSHs(sv_2mortal(newSViv(PTR2IV(code))));    /* pointer type void */
    XPUSHs(sv_2mortal(newSViv(PTR2IV(cb_data)))); 

void
DESTROY(self)
    SV* self;
PREINIT:
    cb_data_t* data;
    HV* selfhash;
    SV** svValue;
    int intFromPerl;
PPCODE:
    if( !sv_isa(self, "Ctypes::Callback") ) {
      croak( "Callback::DESTROY called on non-Callback object" );
    }

    svValue = hv_fetch((HV*)SvRV(self), "_cb_data", 8, 0 );
    if(!svValue) { croak("No _cb_data ptr from Perl"); }
    intFromPerl = SvIV(*svValue);
    data = INT2PTR(cb_data_t*, intFromPerl);

    ffi_closure_free(data->closure);
    Safefree(data->cif->arg_types);
    Safefree(data->cif);
    Safefree(data);
