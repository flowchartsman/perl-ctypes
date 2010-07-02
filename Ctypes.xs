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

int cmp ( const void* one, const void* two ) {
  int a,b;
  a = *(int*)one;
  b = *(int*)two;
  if( a < b ) return -1;
  if( a == b ) return 0;
  if( a > b ) return 1;
}

typedef struct _perl_cb_data {
  char* sig;
  SV* coderef;
  ffi_cif* cif;
} perl_cb_data;

void _perl_cb_call( ffi_cif* cif, void* retval, void** args, void* udata )
{
    dSP;

    ENTER;
    SAVETMPS;

    debug_warn( "#[%s:%i] Entered _perl_cb_call...", __FILE__, __LINE__ );

    unsigned int i, flags, count;
    debug_warn( "#[%s:%i] Accessing *UDATA...", __FILE__, __LINE__ );
    perl_cb_data* data = (perl_cb_data*)udata;
    char* sig = data->sig;
    debug_warn( "#[%s:%i] Got sig: %s", __FILE__, __LINE__, sig );

    if( cif->nargs > 0 ) {
    debug_warn( "#[%s:%i] Have %i args so pushing to stack...",
                __FILE__, __LINE__, cif->nargs );
      PUSHMARK(SP);
      for( i = 0; i < cif->nargs; i++ ) {
        switch (sig[1])
        {
          case 'v': break;
          case 'c': 
          case 'C': XPUSHs(sv_2mortal(newSViv(*(int*)args[i])));   break;
          case 's': 
          case 'S': XPUSHs(sv_2mortal(newSVpv((char*)args[i], 0)));   break;
          case 'i': XPUSHs(sv_2mortal(newSViv(*(int*)args[i])));   break;
          case 'I': XPUSHs(sv_2mortal(newSVuv(*(unsigned int*)args[i])));   break;
          case 'l': XPUSHs(sv_2mortal(newSViv(*(long*)args[i])));   break;
          case 'L': XPUSHs(sv_2mortal(newSVuv(*(unsigned long*)args[i])));   break;
          case 'f': XPUSHs(sv_2mortal(newSVnv(*(float*)args[i])));    break;
          case 'd': XPUSHs(sv_2mortal(newSVnv(*(double*)args[i])));    break;
          case 'D': XPUSHs(sv_2mortal(newSVnv(*(long double*)args[i])));    break;
          case 'p': XPUSHs(sv_2mortal(newSVpv((void*)args[i], 0))); break;
        }
        SPAGAIN;
      }
      PUTBACK;
    }

    debug_warn( "#[%s:%i] Ready to go! Calling Perl sub...", __FILE__, __LINE__, sig );
    count = call_sv(data->coderef, flags);
    debug_warn( "#[%s:%i] We Have Returned, with %i values", __FILE__, __LINE__, count );

    if( count == 0 && sig[0] != 'v' ) {
        croak( "_perl_cb_call: Received no retval from Perl callback; \
expected %c", sig[0] );
      }
   if( count > 1 && sig[0] != 'p' ) {
       croak( "_perl_cb_call: Received multiple retvals from Perl \
              callback; expected %c", sig[0] );
      }


/*
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv(a, 0)));
    XPUSHs(sv_2mortal(newSViv(b)));
    PUTBACK;

    call_pv("LeftString", G_DISCARD);

    FREETMPS;
    LEAVE; */
}
    
  /* ffi_cif structure:
typedef struct {
  ffi_abi abi;
  unsigned nargs;
  ffi_type **arg_types;
  ffi_type *rtype;
  unsigned bytes;
  unsigned flags;
#ifdef FFI_EXTRA_CIF_FIELDS
  FFI_EXTRA_CIF_FIELDS;
#endif
} ffi_cif;

Forget about varargs perl funcs for now
  */
 
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
          len = sv_len(ST(i+2));
          debug_warn( "#[%s:%i] Got a pointer...", __FILE__, __LINE__ );
          Newx(argvalues[i], 1, void);
          if(SvIOK(ST(i+2))) {
            debug_warn( "#    [%i] SvIOK: assuming 'PTR2IV' value",  __LINE__ );
            *(intptr_t*)argvalues[i] = (intptr_t)INT2PTR(void*, SvIV(ST(i+2)));
          } else {
            debug_warn( "#    [%i] Not SvIOK: assuming 'pack' value",  __LINE__ );
            debug_warn( "#    [%i] sizeof packed array (sv_len): %i",  __LINE__, (int)len );
            debug_warn( "#    [%i] %i items in array (assumed int)",  __LINE__, (int)((int)len/sizeof(int)) );
            *(intptr_t*)argvalues[i] = (intptr_t)SvPVbyte(ST(i+2), len);
#ifdef CTYPES_DEBUG
            int j;
            for( j = 0; j < ((int)len/sizeof(int)); j++ ) {
                debug_warn( "#    argvalues[%i][%i]: %i", i, j, ((int*)*(intptr_t*)argvalues[i])[j] );
            }
#endif
          }
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

    debug_warn( "#[%s:%i] cif OK.", __FILE__, __LINE__ );
    debug_warn( "#  addr is: 0x%x ", (unsigned int)(intptr_t)addr );
    debug_warn( "#  argvalues[3] is: %p", (void*)*(intptr_t*)argvalues[3] );
    debug_warn( "#  num_args: %i", num_args );

    debug_warn( "#[%s:%i] Calling ffi_call...", __FILE__, __LINE__ );
    ffi_call(&cif, FFI_FN(addr), rvalue, argvalues);
    debug_warn( "#ffi_call returned normally with rvalue at 0x%x", (unsigned int)(intptr_t)rvalue );
    debug_warn( "#[Ctypes.xs: %i ] Pushing retvals to Perl stack...", __LINE__ );
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

    debug_warn( "#[Ctypes.xs: %i ] Cleaning up...", __LINE__ );
    free(rvalue);
    int i = 0;
    for( i = 0; i < num_args; i++ ) {
      if(argtypes[i] != &ffi_type_pointer) {
        Safefree(argvalues[i]);
        debug_warn( "#[%s:%i] Successfully free'd argvalues[%i]", __FILE__, __LINE__, i );
      }
    }
    debug_warn( "#[%s:%i] Leaving XS_Ctypes_call...\n\n", __FILE__, __LINE__ );

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
    ffi_cif* perlcall_cif;
    ffi_status status;
    ffi_type *rtype;
    char *rvalue;
    unsigned int args_in_sig, rsize;
    unsigned int num_args = siglen - 1;
    ffi_type *argtypes[num_args];
    void *argvalues[num_args];
    SV* ret;
    HV* stash;
    perl_cb_data* pcb_data;
    void* code;
    ffi_closure* closure;

    debug_warn( "\n#[%s:%i] Entered _make_callback", __FILE__, __LINE__ );
    debug_warn( "#[%s:%i] Allocating for pcb_data...", __FILE__, __LINE__ );
    Newx( pcb_data, 1, perl_cb_data );
    debug_warn( "#[%s:%i] Allocated. Populating...", __FILE__, __LINE__ );
    pcb_data->sig = sig;
    pcb_data->coderef = coderef;
    debug_warn( "#[%s:%i] Populated. Setting rtype...", __FILE__, __LINE__ );
    rtype = get_ffi_type( sig[0] );
    debug_warn( "#[%s:%i] rtype set.", __FILE__, __LINE__ );

    if( num_args > 0 ) {
      int i;
      debug_warn( "#[%s:%i] Getting argtypes...", __FILE__, __LINE__ );
      for( i = 0; i < num_args; i++ ) {
        argtypes[i] = get_ffi_type(sig[i+1]); 
        debug_warn( "#    Got argtype '%c'", sig[i+1] );
      }
    }

    Newx(perlcall_cif, 1, ffi_cif);
    pcb_data->cif = perlcall_cif;

    debug_warn( "#[%s:%i] Prep'ing cif for _perl_cb_call...", __FILE__, __LINE__ ); 
    if((status = ffi_prep_cif
        (perlcall_cif,
         /* Might PerlXS modules use stdcall on win32? How to check? */
         FFI_DEFAULT_ABI,
         num_args, rtype, argtypes)) != FFI_OK ) {
       croak( "Ctypes::_call error: ffi_prep_cif error %d", status );
     }
    debug_warn( "#[%s:%i] Allocating closure...", __FILE__, __LINE__ );
    closure = ffi_closure_alloc( sizeof(ffi_closure), &code );
    debug_warn( "#[%s:%i] Allocated. Prep'ing closure...", __FILE__, __LINE__ ); 
    if((status = ffi_prep_closure_loc
        ( closure, perlcall_cif, &_perl_cb_call, pcb_data, code )) != FFI_OK ) {
      croak( "Ctypes::Callback::new error: ffi_prep_closure_loc error %d",
             status );
        }
    debug_warn( "#[%s:%i] Prep'ed.", __FILE__, __LINE__ );

    // EXTEND(SP, 1);
    unsigned int len = sizeof(intptr_t);
    debug_warn( "#[%s:%i] closure: %p", __FILE__, __LINE__, (void*)closure );
    debug_warn( "    Pushing closure to stack...");
    XPUSHs(sv_2mortal(newSVpv((void*)closure, len))); 
    debug_warn( "#[%s:%i] code: %p", __FILE__, __LINE__, code );
    debug_warn( "    Pushing code to stack...");
    XPUSHs(sv_2mortal(newSViv(PTR2IV(code))));    /* pointer type void */
    debug_warn( "#[%s:%i] pcb_data: %p", __FILE__, __LINE__, (void*)pcb_data );
    debug_warn( "#    Pushing pcb_data to stack...");
    XPUSHs(sv_2mortal(newSVpv((void*)pcb_data, len))); 
    // XSRETURN(3);

void
DESTROY(self)
    SV* self;
PREINIT:
    ffi_closure* closure;
    void* code;
    perl_cb_data* data;
    HV* selfhash;
PPCODE:
    if( !sv_isa(self, "Ctypes::Callback") ) {
      croak( "Callback::DESTROY called on non-Callback object" );
    }

    selfhash = (HV*)SvRV(self);
    closure = (ffi_closure*)SvPV_nolen(*(hv_fetch(selfhash, "_writable", 9, 0 )));
    code = (void*)SvPV_nolen(*(hv_fetch(selfhash, "_executable", 11, 0 )));
    data = (perl_cb_data*)SvPV_nolen(*(hv_fetch(selfhash, "_cb_data", 8, 0 )));

    ffi_closure_free(closure);
    Safefree(data->cif);
    Safefree(data);
