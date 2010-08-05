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
#include "src/obj_util.c"
#include "src/util.c"

//#include "const-c.inc"

int
ConvArg(SV* obj, char type_got, char type_expected,
        ffi_type **argtypes, void **argvalues, int index)
{
  debug_warn("#[%s:%i] In ConvArg...", __FILE__, __LINE__);
  debug_warn("#    Type expected: %c",type_expected);
  debug_warn("#    Type got: %c", type_got);
  SV* arg;
  char type;
  if( type_expected )
    type = type_expected;
  else if( type_got )
    type = type_got;
  else if( SvPOK(obj) )
    type = 's';
  else if( SvNOK(obj) )
    type = 'd';
  else if( SvIOK(obj) )
    type = 'i';
  else
    croak("ConvArg error: No type information for SV object");

  debug_warn( "#  type %i: %c", index+1, type);
  argtypes[index] = get_ffi_type(type);

  if( type_got )
    arg = Ct_HVObj_GET_ATTR_KEY(obj, "_as_param_");

  else  /* no intrinsic type info: obj is (should be) simple scalar */
    arg = obj;

  switch(type)
  {
  case 'c':
    Newxc(argvalues[index], 1, char, char);
    *(char*)argvalues[index] = type_got
      ? *(char*)SvPVX(arg)
      : SvIV(arg); 
    break;
  case 'C':
    Newxc(argvalues[index], 1, unsigned char, unsigned char);
    *(unsigned char*)argvalues[index] = type_got
      ? *(unsigned char*)SvPVX(arg)
      : SvIV(arg);
    break;
  case 's':
    Newxc(argvalues[index], 1, short, short);
    *(short*)argvalues[index] = type_got
      ? *(short*)SvPVX(arg)
      : SvIV(arg);
    break;
  case 'S':
    Newxc(argvalues[index], 1, unsigned short, unsigned short);
    *(unsigned short*)argvalues[index] = type_got
      ? *(unsigned short*)SvPVX(arg)
      : SvIV(arg);
    break;
  case 'i':
    Newxc(argvalues[index], 1, int, int);
    *(int*)argvalues[index] = type_got
      ? *(int*)SvPVX(arg)
      : SvIV(arg);
    break;
  case 'I':
    Newxc(argvalues[index], 1, unsigned int, unsigned int);
    *(unsigned int*)argvalues[index] = type_got
      ? *(unsigned int*)SvPVX(arg)
      : SvIV(arg);
    break;
  case 'l':
    Newxc(argvalues[index], 1, long, long);
    *(long*)argvalues[index] = type_got
      ? *(long*)SvPVX(arg)
      : SvIV(arg);
    break;
  case 'L':
    Newxc(argvalues[index], 1, unsigned long, unsigned long);
    *(unsigned long*)argvalues[index] = type_got
      ? *(unsigned long*)SvPVX(arg)
      : SvIV(arg);
   break;
  case 'f':
    Newxc(argvalues[index], 1, float, float);
    *(float*)argvalues[index] = type_got
      ? *(float*)SvPVX(arg)
      : SvNV(arg);
    break;
  case 'd':
    Newxc(argvalues[index], 1, double, double);
    *(double*)argvalues[index] = type_got
      ? *(double*)SvPVX(arg)
      : SvNV(arg);
    break;
  case 'D':
    Newxc(argvalues[index], 1, long double, long double);
    *(long double*)argvalues[index] = type_got
      ? *(long double*)SvPVX(arg)
      : SvNV(arg);
    break;
  case 'p':
    Newx(argvalues[index], 1, void);
    STRLEN len = sv_len(arg);
    if(SvIOK(arg)) {
      debug_warn( "#    [%s:%i] Pointer: SvIOK: assuming 'PTR2IV' value",
                   __func__, __LINE__ );
      *(intptr_t*)argvalues[index] = type_got
        ? (intptr_t)INT2PTR(void*, *(intptr_t*)SvPVX(arg))
        : (intptr_t)INT2PTR(void*, SvIV(arg));
    } else {
      debug_warn( "#    [%s:%i] Pointer: Not SvIOK: assuming 'pack' value",
                   __func__, __LINE__ );
      *(intptr_t*)argvalues[index] = type_got
        ? (intptr_t)*(intptr_t*)SvPVX(arg)
        : (intptr_t)SvPVX(arg);
    }
    break;
  /* should never happen here */
  default: croak( "ConvArg error: Unrecognised type '%c' (line %i)",
             type, __LINE__ );
  }
  return 0;
}

void
_perl_cb_call( ffi_cif* cif, void* retval, void** args, void* udata )
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
 
    debug_warn( "\n#[Ctypes.xs: %i ] XS_Ctypes_call_raw( 0x%x, \"%s\", ...)", __LINE__, (unsigned int)(intptr_t)addr, sig );
    debug_warn( "#Module compiled with -DCTYPES_DEBUG for detailed output from XS" );
#ifndef PERL_ARGS_ASSERT_CROAK_XS_USAGE
    if( num_args < 0 ) {
      croak( "Ctypes::_call error: Not enough arguments" );
    }
#endif

    args_in_sig = validate_signature(sig);
    if( args_in_sig != num_args ) {
      croak( "Ctypes::_call_raw error: specified %i arguments but supplied %i", 
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
	  croak("Ctypes::_call_raw error: too many args (%d expected)", i - 2); /* should never happen here */

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


MODULE = Ctypes		PACKAGE = Ctypes::Function

void
_call(self, ...)
    SV* self;
  PROTOTYPE: DISABLE
  PPCODE:
    ffi_cif cif;
    ffi_status status;
    ffi_type *rtype;
    char *rvalue, rtypechar;
    STRLEN len;
    unsigned int num_argtypes, rsize;
    unsigned int num_args = items - 1;
    ffi_type *argtypes[num_args];
    void *argvalues[num_args];
    SV *self_argtypesRV, *rtypeSV;
    AV *self_argtypes;
    STRLEN tc_len = 1;

    debug_warn( "\n#[%s:%i] XS_Ctypes_Function__call( %i args )",
                __FILE__, __LINE__, num_args );
    debug_warn( "#Module compiled with -DCTYPES_DEBUG for detailed output from XS" );
#ifndef PERL_ARGS_ASSERT_CROAK_XS_USAGE
    if( num_args < 0 ) {
      croak( "Ctypes::_call error: Not enough arguments" );
    }
#endif

    if( !(Ct_Obj_IsDeriv(self,"Ctypes::Function"))) 
      croak("Ctypes::_call: $self must be a Ctypes::Function or derivative");

    rtypeSV = Ct_HVObj_GET_ATTR_KEY(self, "restype");
    if( Ct_Obj_IsDeriv(rtypeSV,"Ctypes::Type") ) {
      rtypechar =
        (char)*SvPV_nolen(Ct_HVObj_GET_ATTR_KEY(rtypeSV,"_typecode_"));
      rtype = get_ffi_type( rtypechar );
    } else {
      rtypechar = (char)*SvPV_nolen(rtypeSV);
      rtype = get_ffi_type( rtypechar );
    }
    debug_warn( "#[Ctypes.xs:%i] Return type found: %c", __LINE__,  rtypechar );
    rsize = FFI_SIZEOF_ARG;
    if (rtypechar == 'd') rsize = sizeof(double);
    if (rtypechar == 'D') rsize = sizeof(long double);
    rvalue = (char*)malloc(rsize);
 
    if( num_args > 0 ) {
      debug_warn( "#[%s:%i] Getting types & values of args...",
        __FILE__, __LINE__ );

      int i, err;
      char type_expected;
      char type_got;
      char type;

      /* get $self->argtypes and make sure they make sense */
      self_argtypesRV = Ct_HVObj_GET_ATTR_KEY(self, "argtypes");
      if( self_argtypesRV == NULL ) {
        self_argtypes == NULL;
      } else {
        if( !( SvROK(self_argtypesRV)
               && SvTYPE(SvRV(self_argtypesRV)) == SVt_PVAV) )
          croak("Ctypes::_call error: argtypes must be array reference");
        else
          self_argtypes = (AV*)SvRV(self_argtypesRV);
        if( av_len(self_argtypes) == -1 ) {
          /* could this equally be SvREFCNT_dec(self_argtypes)? */ 
          SvREFCNT_dec(self_argtypesRV);
          self_argtypes == NULL;
        }
      }
      debug_warn("    num_args is %i", num_args);
      for (i = 0; i < num_args; ++i) {
        debug_warn("    i is %i", i);
        SV* this_arg = ST(i+1);
        SV *this_argtype, **fetched_argtype;
        if( self_argtypes ) {
          fetched_argtype = av_fetch(self_argtypes, i, 0);
          if( fetched_argtype != NULL ) {
            this_argtype = *fetched_argtype;
            type_expected = Ct_Obj_IsDeriv(this_argtype, "Ctypes::Type")
              ? (char)*SvPV(Ct_HVObj_GET_ATTR_KEY(this_argtype,"_typecode_"),tc_len)
              : (char)*SvPV(this_argtype,tc_len);
          } else {
            croak("Ctypes::_call:%i error: Couldn't get argtype from array",
                  __LINE__);
          }
        } else {
          this_argtype = NULL;
          type_expected = '\0';
        }

        if( SvROK(this_arg) 
            && !sv_isobject(this_arg) ) {
          SV* tmp = SvRV(this_arg);
          this_arg = tmp;
        }

        debug_warn("    Checking type_got...");
        type_got = Ct_Obj_IsDeriv(this_arg, "Ctypes::Type")
          ? (char)*SvPV(Ct_HVObj_GET_ATTR_KEY(this_arg,"_typecode_"),tc_len)

          : '\0';

        debug_warn("    type_got: %c", type_got);

        /* err not used yet, ConvArg croaks a lot */
        debug_warn("    calling ConvArg...");
        err = ConvArg( this_arg,
                 type_got,
                 type_expected,
                 argtypes,
                 argvalues,
                 i);
      }

      if( av_len(self_argtypes) > -1 ) /* if not, has been dec'd already */
        SvREFCNT_dec(self_argtypesRV);

    } else {
      debug_warn( "#[Ctypes.xs: %i ] No argtypes/values to get", __LINE__ );
    }

    char abi =  *SvPV((Ct_HVObj_GET_ATTR_KEY(self,"abi")),tc_len);
    void* addr = INT2PTR(void*,(int)SvIV(Ct_HVObj_GET_ATTR_KEY(self,"func")));

    if((status = ffi_prep_cif
         (&cif,
	  /* x86-64 uses for 'c' UNIX64 resp. WIN64, which is f not c */
           abi == 's' ? FFI_STDCALL : FFI_DEFAULT_ABI,
          num_args, rtype, argtypes)) != FFI_OK ) {
      croak( "Ctypes::_call error: ffi_prep_cif error %d", status );
    }

    debug_warn( "#[%s:%i] cif OK.", __FILE__, __LINE__ );

    debug_warn( "#[%s:%i] Calling ffi_call...", __FILE__, __LINE__ );
    ffi_call(&cif, FFI_FN(addr), rvalue, argvalues);
    debug_warn( "#    ffi_call returned!");
    debug_warn( "#[%s:%i] Pushing retvals to Perl stack...", __FILE__, __LINE__ );
    switch (rtypechar)
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


MODULE = Ctypes		PACKAGE = Ctypes

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
_valid_for_type(arg_sv,type)
  SV* arg_sv;
  char type;
CODE:
  void* arg_p;
  NV arg_nv;
  short i;
  RETVAL = 0;
  debug_warn("#[%s:%i] Entered _valid_for_type with type %c",
    __FILE__, __LINE__, type);
  if( !SvOK(arg_sv) || !type ) { XSRETURN_UNDEF; }
  switch (type) {
    case 'v': break;
    case 'c':
    case 'C':
    /* We want the real value, not implicit conversion */
      if( !SvPOKp(arg_sv) ) break;
    /* ??? What about UTF8? */
      if( sv_len(arg_sv) != 1 ) break;
      RETVAL = 1; break;
    case 's':
    case 'S':
      if( !SvNOKp(arg_sv) && !SvIOK(arg_sv) ) break;
      RETVAL = 1; break;
    case 'i':
      if( !SvNOKp(arg_sv) && !SvIOK(arg_sv) ) break;
      arg_nv = SvNV(arg_sv);
      debug_warn("arg_nv: %f", arg_nv);
      if( arg_nv < PERL_INT_MIN || arg_nv > PERL_INT_MAX ) {
        RETVAL = -1; break;
      }
      RETVAL = 1; break;
    case 'I':
      if( !SvNOKp(arg_sv) && !SvIOK(arg_sv) ) break;
      arg_nv = SvNV(arg_sv);
      if( arg_nv < PERL_UINT_MIN || arg_nv > PERL_UINT_MAX ) {
        RETVAL = -1; break;
      }
      RETVAL = 1; break;
    case 'l':
    /* ??? Are Longs always guaranteed to be IV rather than NV? */
      if( !SvNOKp(arg_sv) && !SvIOK(arg_sv) ) break;
      arg_nv = SvNV(arg_sv);
      if( arg_nv < PERL_LONG_MIN || arg_nv > PERL_LONG_MAX ) {
        RETVAL = -1; break;
      }
      RETVAL = 1; break;
    case 'L':
      if( !SvNOKp(arg_sv) && !SvIOK(arg_sv) ) break;
      arg_nv = SvNV(arg_sv);
      if( arg_nv < PERL_ULONG_MIN || arg_nv > PERL_ULONG_MAX ) {
        RETVAL = -1; break;
      }
      RETVAL = 1; break;
    case 'f':
      if( !SvNOKp(arg_sv) && !SvIOK(arg_sv) ) break;
    /* ??? Is NV, usually double, alright to use here?
       Also, any Perl vars to use instead of stdlib ones? */
      arg_nv = SvNV(arg_sv);
      if( arg_nv < FLT_MIN || arg_nv > FLT_MAX ) {
        RETVAL = -1; break;
      }
      RETVAL = 1; break;
    case 'd':
      if( !SvNOKp(arg_sv) && !SvIOK(arg_sv) ) break;
      arg_nv = SvNV(arg_sv);
      if( arg_nv < DBL_MIN || arg_nv > DBL_MAX ) {
        RETVAL = -1; break;
      }
      RETVAL = 1; break;
#ifdef HAS_LONG_DOUBLE
    case 'D':
      if( !SvNOKp(arg_sv) && !SvIOK(arg_sv) ) break;
      arg_nv = SvNV(arg_sv);
      if( arg_nv < LDBL_MIN || arg_nv > LDBL_MAX ) {
        RETVAL = -1; break;
      }
      RETVAL = 1; break;
#endif
    case 'p':
    /* Pointers can be just about anything
       ??? Could this be improved? */
      if( !SvPOK(arg_sv) && !SvNOK(arg_sv) && !SvIOK(arg_sv) )
        RETVAL = 0; break;
      RETVAL = 1; break;
    default: croak( "Invalid type: %c", type );
  }
OUTPUT:
  RETVAL

SV*
_cast(arg_sv,type)
  SV* arg_sv;
  char type;
CODE:
  void *retval = NULL;
#ifdef HAS_LONG_DOUBLE
  Newxc(retval, 1, long double, long double);
#else
  Newxc(retval, 1, double, double);
#endif
  if(retval == NULL) croak("Ctypes::_cast: Out of memory!");
  STRLEN len = 1; 
  RETVAL = NULL;
  switch (type) {
    case 'c':
      if(SvPOK(arg_sv)) {
        retval = SvPV(arg_sv, len);
      } else {
        *(signed char*) retval = (signed char)SvNV(arg_sv);
      }
      if(*(signed char*)retval)
        RETVAL = newSVpv((signed char*)retval, len);
      break;
    case 'C':
      if(SvPOK(arg_sv)) {
        retval = SvPV(arg_sv, len);
      } else {
        *(unsigned char*) retval = (unsigned char)SvNV(arg_sv);
      }
      if(*(unsigned char*)retval)
        RETVAL = newSVpv((unsigned char*)retval, len);
      break;
    case 's':
      if(SvIOK(arg_sv)) {
        *(short int*) retval = (short int)SvIV(arg_sv);
      } else if(SvNOK(arg_sv)) {
        *(short int*) retval = (short int)SvNV(arg_sv);
      } else if(SvPOK(arg_sv)) {
        *(short int*) retval = (short int)*SvPV_nolen(arg_sv);
      }
      if(*(short int*)retval) {
        RETVAL = newSViv(*(short int*)retval);
      }
      break;
    case 'S':
      if(SvIOK(arg_sv)) {
        *(unsigned short*) retval = (unsigned short)SvIV(arg_sv);
      } else if(SvNOK(arg_sv)) {
        *(unsigned short*) retval = (unsigned short)SvNV(arg_sv);
      } else if(SvPOK(arg_sv)) {
        *(unsigned short*) retval = (unsigned short)*SvPV_nolen(arg_sv);
      }
      if(*(unsigned short*)retval) {
        RETVAL = newSViv(*(unsigned short*)retval);
      }
      break;
    case 'i':
      if(SvIOK(arg_sv)) {
        *(int*) retval = (int)SvIV(arg_sv);
      } else if(SvNOK(arg_sv)) {
        *(int*) retval = (int)SvNV(arg_sv);
      } else if(SvPOK(arg_sv)) {
        *(int*)retval = (int)*(SvPV_nolen(arg_sv));
      }
      if(*(int*)retval) {
        RETVAL = newSViv(*(int*)retval);
      }
      break;
    case 'I':
      if(SvIOK(arg_sv)) {
        *(unsigned int*) retval = (unsigned int)SvIV(arg_sv);
      } else if(SvNOK(arg_sv)) {
        *(unsigned int*) retval = (unsigned int)SvNV(arg_sv);
      } else if(SvPOK(arg_sv)) {
        *(unsigned int*) retval = (unsigned int)*SvPV_nolen(arg_sv);
      }
      if(*(unsigned int*)retval) {
        RETVAL = newSViv(*(unsigned int*)retval);
      }
      break;
    case 'l':
      if(SvIOK(arg_sv)) {
        *(long*) retval = (long)SvIV(arg_sv);
      } else if(SvNOK(arg_sv)) {
        *(long*) retval = (long)SvNV(arg_sv);
      } else if(SvPOK(arg_sv)) {
        *(long*) retval = (long)*SvPV_nolen(arg_sv);
      }
      if(*(long*)retval) {
        if(LONGSIZE <= IVSIZE)
          RETVAL = newSViv(*(long*)retval);
        else
          RETVAL = newSVnv(*(long*)retval);
      }
      break;
    case 'L':
      if(SvIOK(arg_sv)) {
        *(unsigned long*) retval = (unsigned long)SvIV(arg_sv);
      } else if(SvNOK(arg_sv)) {
        *(unsigned long*) retval = (unsigned long)SvNV(arg_sv);
      } else if(SvPOK(arg_sv)) {
        *(unsigned long*) retval = (unsigned long)*SvPV_nolen(arg_sv);
      }
      if(*(unsigned long*)retval) {
        if(LONGSIZE <= IVSIZE)
          RETVAL = newSViv(*(long*)retval);
        else
          RETVAL = newSVnv(*(long*)retval);
      }
      break;
    case 'f':
      if(SvIOK(arg_sv)) {
        *(float*) retval = (float)SvIV(arg_sv);
      } else if(SvNOK(arg_sv)) {
        *(float*) retval = (float)SvNV(arg_sv);
      } else if(SvPOK(arg_sv)) {
        *(float*) retval = (float)*SvPV_nolen(arg_sv);
      }
      if(*(float*)retval) {
        RETVAL = newSVnv(*(float*)retval);
      }
      break;
    case 'd':
      if(SvIOK(arg_sv)) {
        *(double*) retval = (double)SvIV(arg_sv);
      } else if(SvNOK(arg_sv)) {
        *(double*) retval = (double)SvNV(arg_sv);
      } else if(SvPOK(arg_sv)) {
        *(double*) retval = (double)*SvPV_nolen(arg_sv);
      }
      if(*(double*)retval) {
        RETVAL = newSVnv(*(double*)retval);
      }
      break;
#ifdef HAS_LONG_DOUBLE
    case 'D':
      if(SvIOK(arg_sv)) {
        *(long double*) retval = (long double)SvIV(arg_sv);
      } else if(SvNOK(arg_sv)) {
        *(long double*) retval = (long double)SvNV(arg_sv);
      } else if(SvPOK(arg_sv)) {
        *(long double*) retval = (long double)*SvPV_nolen(arg_sv);
      }
      if(*(long double*)retval) {
        RETVAL = newSVnv(*(long double*)retval);
      }
      break;
#endif
    case 'p':
      if(SvIOK(arg_sv)) {
      debug_warn("#[%s:%i] _cast: Pointer SvIOK, assuming 'PTR2IV' value",
        __FILE__, __LINE__ );
        *(intptr_t*)retval = (intptr_t)INT2PTR(void*, SvIV(arg_sv));
      } else {
      debug_warn("#[%s:%i] _case: Pointer not SvIOK, assuming 'pack' value",
        __FILE__,  __LINE__ );
        *(intptr_t*)retval = (intptr_t)SvPVX(arg_sv);
      }
      if(retval) {
          RETVAL = newSViv(PTR2IV(*(intptr_t*)retval));
      }
      break;
    default: croak( "Unimplemented / Invalid type: %c", type );
  }
  Safefree(retval);
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
