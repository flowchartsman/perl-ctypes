package Ctypes::Type;
# always loaded and all c types are exported.
use strict;
use warnings;
use Carp;
require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT_OK = qw|&_types &strict_input_all|;
# our $VERSION = 0.003;
# This should be customizable, should it?
use constant USE_PERLTYPES => 0; # full python ctypes types,
				 # or the simplier perl pack-style types
use Ctypes;
use Ctypes::Type::Simple;
use Ctypes::Type::Array;
use Ctypes::Type::Pointer;
use Ctypes::Type::Struct;
use Scalar::Util qw|looks_like_number|;
use B qw|svref_2object|;
use Encode;
my $Debug = 1;
use utf8;

=head1 NAME

Ctypes::Type - Abstract base class for Ctypes Data Type objects

=cut

#  our $_perltypes =
#  {
#    v =>  "c_void",
#    c =>  "c_byte",
#    C =>  "c_char",
#    s =>  "c_short",
#    S =>  "c_ushort",
#    i =>  "c_int",
#    I =>  "c_uint",
#    l =>  "c_long",
#    L =>  "c_ulong",
#    f =>  "c_float",
#    d =>  "c_double",
#    D =>  "c_longdouble",
#    p =>  "c_void_p",
#  };

our $_perltypes =
{
  v => {
         name     => 'c_void',
       }, # end of type 'v'
  b => {
         name     => 'c_byte',
       }, # end of type 'b'
  C =>  {
          name => 'c_char',
        }, # end of type 'C'
  c =>  {
          name => 'c_byte',
        }, # same as b, but compatible to pack-style c
  s =>  { name => 'c_short' },
  S =>  { name => 'c_ushort', sizecode => 's' },
  i =>  { name => 'c_int' },
  I =>  { name => 'c_uint', sizecode => 'i' },
  l =>  { name => 'c_long' },
  L =>  { name => 'c_ulong', sizecode => 'l' },
  f =>  { name => 'c_float' },
  d =>  { name => 'c_double' },
  D =>  { name => 'c_longdouble' },
  p =>  { name => 'c_void_p' },
};

# c_char c_wchar c_byte c_ubyte c_short c_ushort c_int c_uint c_long c_ulong
# c_longlong c_ulonglong c_float c_double c_longdouble c_char_p c_wchar_p
# c_size_t c_ssize_t c_bool c_void_p

# implemented as aliases:
# c_int8 c_int16 c_int32 c_int64 c_uint8 c_uint16 c_uint32 c_uint64

our $_pytypes =
{
  b => { # -128 <= int <= 127, c?
         name     => 'c_byte',
         sizecode => 'c',
         packcode => 'c',
         typecode => 'b',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'b';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           # my $MIN = $Ctypes::Type::_types->{$tc}->{MIN};
           # my $MAX = $Ctypes::Type::_types->{$tc}->{MAX};
           print "In hook_in c_byte($arg)\n" if $Debug;
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must " .
                         "be integers -128 <= x <= 127";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < -128 or $arg > 127 ) {
               $valid = "$name: numeric values must " .
                        "be integers -128 <= x <= 127";
             }
           } else {
             if( length($arg) == 1 ) {
               print "    1 char long, good\n" if $Debug;
               $arg = ord($arg);
               if( $arg < 0 or $arg > 127 ) {
                 $valid = "$name: character values must " .
                          "be integers 0 <= ord(x) <= 127";
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > 127 ) {
                 $valid .= ", and must be integers 0 <= ord(x) <= 127";
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
         hook_out => sub {
           print "In hook_out\n" if $Debug;
           my ($val, $obj) = (shift, shift);
           print "    INPUT WAS ", $obj->{_input}, "\n" if $Debug;
           return Ctypes::Type::is_a_number($obj->{_input}) ? $val : chr($val);
         }, # end of hook_out
       }, # end of type 'c_byte'
  B => { # 0 < int < 256, C?
         name     => 'c_ubyte',
         packcode => 'C',
         sizecode => 'c',
         typecode => 'B',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'B';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           # my $MIN = $Ctypes::Type::_types->{$tc}->{MIN};
           # my $MAX = $Ctypes::Type::_types->{$tc}->{MAX};
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must " .
                         "be integers 0 <= x <= 255";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < 0 or $arg > 255 ) {
               $valid = "$name: numeric values must " .
                        "be integers 0 <= x <= 255";
             }
           } else {
             if( length($arg) == 1 ) {
               print "1 char long!\n" if $Debug;
               $arg = ord($arg);
               if( $arg < 0 or $arg > 255 ) {
                 $valid = "$name: character values must " .
                          "be integers 0 <= ord(x) <= 255";
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > 255 ) {
                 $valid .= ", and must be integers 0 <= ord(x) <= 255";
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
         hook_out => sub {
           print "In hook_out\n" if $Debug;
           my ($val, $obj) = (shift, shift);
           print "    INPUT WAS ", $obj->{_input}, "\n" if $Debug;
           return Ctypes::Type::is_a_number($obj->{_input}) ? $val : chr($val);
         }, # end of hook_out
       }, # end of type 'c_ubyte'
  X => { name => 'c_bstr' },        # a?
  c => { # single character, c signed, possibly a multi-char (?)
         name => 'c_char',
         sizecode => 'c',
         typecode => 'c',
         packcode => 'c',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'c';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           # my $MIN = $Ctypes::Type::_types->{$tc}->{MIN};
           # my $MAX = $Ctypes::Type::_types->{$tc}->{MAX};
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must " .
                         "be integers -128 <= x <= 127";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < -128 or $arg > 127 ) {
               $valid = "$name: numeric values must " .
                        "be integers -128 <= x <= 127";
             }
           } else {
             print "Didn't look_like_number!\n" if $Debug;
             if( length($arg) == 1 ) {
               print "1 char long, great!\n" if $Debug;
               $arg = ord($arg);
               if( $arg < 0 or $arg > 127 ) {
                 $valid = "$name: character values must " .
                          "be integers 0 <= ord(x) <= 127";
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > 127 ) {
                 $valid .= ", and must be integers 0 <= ord(x) <= 127";
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
         hook_out => sub { return chr(shift) },
       }, # end of type 'c_char'
  C => { # C?
         name => 'c_uchar',
         typecode => 'C',
         sizecode => 'C',
         packcode => 'C',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'C';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           # my $MIN = $Ctypes::Type::_types->{$tc}->{MIN};
           # my $MAX = $Ctypes::Type::_types->{$tc}->{MAX};
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must " .
                         "be integers 0 <= x <= 255";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < 0 or $arg > 255 ) {
               $valid = "$name: numeric values must " .
                        "be integers 0 <= x <= 255";
             }
           } else {
             print "Didn't look_like_number!\n" if $Debug;
             if( length($arg) == 1 ) {
               print "1 char long, great!\n" if $Debug;
               $arg = ord($arg);
               if( $arg < 0 or $arg > 255 ) {
                 $valid = "$name: character values must " .
                          "be integers 0 <= ord(x) <= 255";
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > 255 ) {
                 $valid .= ", and must be integers 0 <= ord(x) <= 255";
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
         hook_out => sub { return chr(shift) },
       },
  s => { name => 'c_char_p' },      # null terminated string, A?
  w => { name => 'c_wchar' },       # U
  z => { name => 'c_wchar_p' },     # U*
  h => { # s
         name     => 'c_short',
         sizecode => 's',
         packcode => 's',
         typecode => 'h',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'h';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           my $MIN = Ctypes::constant('PERL_SHORT_MIN');
           my $MAX = Ctypes::constant('PERL_SHORT_MAX');
           print "In hook_in\n" if $Debug;
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < $MIN or $arg > $MAX ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX"
                 if not defined $valid;
             }
           } else {
             if( length($arg) == 1 ) {
               print "    1 char long, good\n" if $Debug;
               $arg = ord($arg);
               if( $arg < 0 or $arg > $MAX ) {
                 $valid = "$name: character values must be integers " .
                          "0 <= ord(x) <= $MAX";
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > $MAX ) {
                 $valid .= ", and must be integers " .
                          "0 <= ord(x) <= $MAX";
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
       }, # end of type 'c_short'
  H => { # S
         name => 'c_ushort',
         sizecode => 'S',
         packcode => 'S',
         typecode => 'H',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'H';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           my $MIN = Ctypes::constant('PERL_USHORT_MIN');
           my $MAX = Ctypes::constant('PERL_USHORT_MAX');
           print "In hook_in\n" if $Debug;
           print "Arg is $arg\n" if $Debug;
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < $MIN or $arg > $MAX ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX"
                 if not defined $valid;
             }
           } else {
             if( length($arg) == 1 ) {
               print "    1 char long, good\n" if $Debug;
               $arg = ord($arg);
               print "      arg is now $arg\n" if $Debug;
               if( $arg < 0 or $arg > $MAX ) {
                 $valid = "$name: character values must be integers " .
                          "0 <= ord(x) <= $MAX";
               } else {
                 print "    Arg is within range\n" if $Debug;
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > $MAX ) {
                 $valid .= ", and must be integers " .
                          "0 <= ord(x) <= $MAX";
               } else {
                 print "    Arg is within range\n" if $Debug;
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
       },  # end of c_ushort
  i => { # Alias to c_long where equal; i
         name     => 'c_int',
         sizecode => 'i',
         packcode => 'i',
         typecode => 'i',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'i';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           my $MIN  = Ctypes::constant('PERL_INT_MIN');
           my $MAX  = Ctypes::constant('PERL_INT_MAX');
           print "In hook_in c_int($arg)\n" if $Debug;
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < $MIN or $arg > $MAX ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX"
                 if not defined $valid;
             }
           } else {
             if( length($arg) == 1 ) {
               print "    1 char long, good\n" if $Debug;
               $arg = ord($arg);
               if( $arg < 0 or $arg > $MAX ) {
                 $valid = "$name: character values must be integers " .
                          "0 <= ord(x) <= $MAX";
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > $MAX ) {
                 $valid .= ", and must be integers " .
                          "0 <= ord(x) <= $MAX";
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
       }, # end of type 'c_int'
  I => { # Alias to c_ulong where equal; I
         name     => 'c_uint',
         packcode => 'I',
         sizecode => 'i',
         typecode => 'I',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'I';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           my $MIN  = Ctypes::constant('PERL_UINT_MIN');
           my $MAX  = Ctypes::constant('PERL_UINT_MAX');
           print "In hook_in\n" if $Debug;
           print "Arg is $arg\n" if $Debug;
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < $MIN or $arg > $MAX ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX"
                 if not defined $valid;
             }
           } else {
             if( length($arg) == 1 ) {
               print "    1 char long, good\n" if $Debug;
               $arg = ord($arg);
               print "      arg is now $arg\n" if $Debug;
               if( $arg < 0 or $arg > $MAX ) {
                 $valid = "$name: character values must be integers " .
                          "0 <= ord(x) <= $MAX";
               } else {
                 print "    Arg is within range\n" if $Debug;
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > $MAX ) {
                 $valid .= ", and must be integers " .
                          "0 <= ord(x) <= $MAX";
               } else {
                 print "    Arg is within range\n" if $Debug;
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
       }, # end of type 'c_uint'
  l => { # l
         name     => 'c_long',
         packcode => 'l',
         sizecode => 'l',
         typecode => 'l',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'l';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           my $MIN  = Ctypes::constant('PERL_LONG_MIN');
           my $MAX  = Ctypes::constant('PERL_LONG_MAX');
           print "In hook_in\n" if $Debug;
           print "Arg is $arg\n" if $Debug;
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < $MIN or $arg > $MAX ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX"
                 if not defined $valid;
             }
           } else {
             if( length($arg) == 1 ) {
               print "    1 char long, good\n" if $Debug;
               $arg = ord($arg);
               print "      arg is now $arg\n";
               if( $arg < 0 or $arg > $MAX ) {
                 $valid = "$name: character values must be integers " .
                          "0 <= ord(x) <= $MAX";
               } else {
                 print "    Arg is within range\n" if $Debug;
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > $MAX ) {
                 $valid .= ", and must be integers " .
                          "0 <= ord(x) <= $MAX";
               } else {
                 print "    Arg is within range\n" if $Debug;
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
       }, # end of type 'c_long'
  L => { # L
         name     => 'c_ulong',
         packcode => 'L',
         sizecode => 'l',
         typecode => 'L',
         hook_in  => sub {
           my $arg = shift;
           my $valid = undef;
           my $tc = 'L';
           my $name = $Ctypes::Type::_types->{$tc}->{name};
           my $MIN  = Ctypes::constant('PERL_ULONG_MIN');
           my $MAX  = Ctypes::constant('PERL_ULONG_MAX');
           print "In hook_in\n" if $Debug;
           print "Arg is $arg\n" if $Debug;
           return ( "$name: cannot take references", undef )
             if ref($arg);
           if( Ctypes::Type::is_a_number($arg) ) {
             if( $arg !~ /^[+-]?\d+$/ ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX";
               $arg = sprintf("%u",$arg);
             }
             if( $arg < $MIN or $arg > $MAX ) {
               $valid = "$name: numeric values must be integers " .
                        "$MIN <= x <= $MAX"
                 if not defined $valid;
             }
           } else {
             if( length($arg) == 1 ) {
               print "    1 char long, good\n" if $Debug;
               $arg = ord($arg);
               print "      arg is now $arg\n" if $Debug;
               if( $arg < 0 or $arg > $MAX ) {
                 $valid = "$name: character values must be integers " .
                          "0 <= ord(x) <= $MAX";
               } else {
                 print "    Arg is within range\n" if $Debug;
               }
             } else {
               $valid = "$name: single characters only";
               $arg = ord(substr($arg, 0, 1));
               if( $arg < 0 or $arg > $MAX ) {
                 $valid .= ", and must be integers " .
                          "0 <= ord(x) <= $MAX";
               } else {
                 print "    Arg is within range\n" if $Debug;
               }
             }
           }
           return ($valid, $arg);
         }, # end of hook_in
       }, # end of type 'c_ulong'
  f => { name => 'c_float' },       # f
  d => { name => 'c_double' },      # d
  g => { name => 'c_longdouble' },  # Alias to c_double where equal, D
  q => { name => 'c_longlong' },    # q
  Q => { name => 'c_ulonglong' },   # Q
  v => { name => 'c_bool' },        # ?
  O => {                # i???
         name     => 'c_void',
         sizecode => 'v',
         packcode => 'a',
         typecode => 'v',
         hook_in  => sub {
           my $valid = undef;
           if( exists $_[0] ) {
             $valid = "c_void: void types cannot take values";
           }
           return ( $valid, "\0" );
         }, # end of hook_in
       }, # end of type 'v'
};

our $_types = USE_PERLTYPES ? $_perltypes : $_pytypes;
sub _types () { return $_types; }
sub strict_input_all;

=head1 SYNOPSIS

    use Ctypes;

    my $int = c_int(10);

    $$int = 15;                          # Note the double sigil
    $$int += 3;
    print $int->size;                    # sizeof(int) in C
    print $int->name;                    # 'c_int'

    my $array = Array( 7, 6, 5, 4, 3 );  #Create array (of c_ushort)
    my $dblarray = Array( c_double, [ 2, 1, 0, -1, -2 ] );
    $$dblarray[2] = $$int;               # Again, note sigils
    print $dblarray->size;               # sizeof(type) * #members

    # Create int-type pointer to double-type array
    my $intp = Pointer( c_int, $dblarray );
    print $$intp[2];                     # 1073741824 on my system

=head1 ABSTRACT

Ctypes::Type is the base class for classes representing the
simple C types, as well as L<Arrays|Ctypes::Type::Array>,
L<Pointers|Ctypes::Type::Pointer>, L<Structs|Ctypes::Type::Struct>
and L<Unions|Ctypes::Type::Union> (although there are functions for
all of them in the main L<Ctypes> namespace, so you can normally
just C<use Ctypes;>).

Common methods are documented here. See the relevant documentation
for the above packages for more detailed information.

=head1 Base types

Base types:

    c_char c_wchar c_byte c_ubyte c_short c_ushort c_int c_uint c_long c_ulong
    c_longlong c_ulonglong c_float c_double c_longdouble c_char_p c_wchar_p
    c_size_t c_ssize_t c_bool c_void_p

Implemented as aliases:

   c_int8 c_int16 c_int32 c_int64 c_uint8 c_uint16 c_uint32 c_uint64

=cut

# Ctypes::Type::_new: Abstract base class for all Ctypes objects
# CLASS [ HASHREF ]
sub _new {
  my $class = ref($_[0]) || $_[0];
  my $init = $_[1] if @_ > 1;
  my $self = {
    _data       =>  "\0",          # raw (binary) memory block
    _needsfree  =>  0,             # does object own its data? (not used yet, 0.002)
    _owner      =>  undef,         # ref to object that owns this one
    _size       =>  0,             # size of memory block in bytes
    _length     =>  1,             # ? number of fields of this object ???
    _index      =>  undef,         # index of this object into the base
                                   # object's _object list
    _objects    =>  undef,         # objects this object holds
    _value      =>  undef,         # 'a small default buffer'
    _address    =>  undef,
    _datasafe   =>  1,             # Can object trust & return its _value
                                   # or must it update its _data?
    _name       => undef,
    _typecode   => undef,
  };
  for(keys(%{$init})) { $self->{$_} = $init->{$_}; };
  return bless $self, $class;
}

# Pod for these functions is on down below

# can't be relied upon to be lvalue as compound types will override
sub _datasafe {
  $_[0]->{_datasafe} = $_[1] if defined $_[1]; return $_[0]->{_datasafe};
}

sub _needsfree : lvalue {
  $_[0]->{_needsfree} = $_[1] if defined $_[1]; $_[0]->{_needsfree};
}

#
# Create global c_<type> functions, classes, and reverse lookup by name => tc
#
my %_defined;
for my $k (keys %$_types) {
  my $name = $_types->{$k}->{name};
  my $func;
  unless ($_defined{$name}) {
    no strict 'refs';
    $func = sub { Ctypes::Type::Simple->new($k, @_); };
    *{"Ctypes::$name"} = $func;
    # eval { qq(package $name; use base "Ctypes::Type::Simple::$name";) };
    $_defined{$name} = $k;
  }
}
our @_allnames = keys %_defined;

=head1 METHODS

Apart from its value or values, each Ctypes::Type object holds various pieces of
information about itself, which you can access via the methods below. Some are
only I<get methods> (read-only), but some could be misused to greatly confuse
the object internals, so you shouldn't assign to them lightly.

=over

=item data

Returning a I<reference> to the object's data field, where its value is
held in L<pack|perlfunc/"pack">ed form. This was originally designed
for internal use, so the semantics are likely to change in future, as
handing out direct access to the data field isn't a good default for
such an innocuously named method.

=cut

#
# Hello! Currently classes implement their own data() methods.
# Looking into commonalities and whether they can be abstracted
# in some way is still TODO.
#

=item index

Returns the offset of the object into its 'owner' object, if it
has one (i.e. an Array, Struct or Union).

=cut

sub index {
  return $_[0]->{_index};
}

sub _set_index {
  $_[0]->{_index} = $_[1] if defined $_[1]; return $_[0]->{_index};
}

=item name

Accessor returning the 'name' of the Type instance ('c_int', 'c_double',
etc.).

B<Note> The use of the C<name> attribute is currently quite
inconsistent. It's used in places it shouldn't be. There should be some
kind of C<Ctypes::are_like()> function to do a deep equivalence check
for data types. At that time C<name> will become simpler. Until then
though, the following rules apply:

Since all basic types are currently Ctypes::Type::Simple objects,
the C<name> attribute is how you find out what kind of type you
actually have.

For compound data types, the name will tell you something about the
object's contents.

For Arrays, C<name> is the lowercased C<name> of the type of object
contained in the array, minus any leading 'c_', plus the suffix '_Array',
e.g. 'int_Array'.

For Pointers, C<name> is the lowercased C<name> of the type of object
being pointed to, minus any leading 'c_', plus the suffix '_Pointer',
e.g. 'int_array_Pointer'.

In the case of Structs, the preceeding convention could get out of hand
(even quicker than it does with the others), so C<name> consists of the
typecodes of the Struct's constituent types, in order, concatenated
together, plus the suffix '_Struct'. So a Struct of three unsigned ints
and two signed doubles would have the name 'iiiDD_Struct' (of course,
this can't be relied upon for checking equivalence, as all compound
Types have the typecode 'p').

=cut

sub name   { return $_[0]->{_name}  }
sub _set_name { die unless scalar @_ == 2; return $_[0]->{_name} = $_[1] }

=item owner

Return the object's 'owner' object, i.e. the Array, Struct or Union
of which it is currently part. Returns undef if the object isn't
inside any others.

=cut

sub owner { return $_[0]->{_owner} }
sub _set_owner {
  $_[0]->{_owner} = $_[1] if defined $_[1]; return $_[0]->{_owner};
}

=item size

Accessor returning the size in bytes on your system of the C type
represented by the Type object. For example, a c_int object might
have size 4, and an Array of five of them would have size 20.

=cut

sub size   { return $_[0]->{_size}  }
sub _set_size { return $_[0]->{_size} = $_[1] }

=item typecode

Accessor returning the 'typecode' of the Type instance. A typecode
is a 1-character string used internally for representing different
C types, which might be useful for various things.

=cut

sub typecode { return $_[0]->{_typecode} }

=back

=head1 CLASS FUNCTIONS

=over

=item strict_input_all

This class method can cease all toleration of incorrect input
for all Type objects. Sets/returns 1 or 0. See the
L<strict_input/Ctypes::Type::Simple/strict_input> object method
for how to do this to individual objects

=back

=cut

{
  my $strict_input_all = 0;
  sub strict_input_all {
    # ??? This could be improved; could still be called as a class method
    # with an object instead of a 1 or 0 and user would not be notified
    my $arg = shift;
    if( @_ or ( defined($arg) and $arg != 1 and $arg != 0 ) ) {
      croak("Usage: strict_input_all(x) (1 or 0)");
    }
    $strict_input_all = $arg if defined $arg;
    return $strict_input_all;
  }
}

=head1 SEE ALSO

L<Ctypes::Type::Simple>
L<Ctypes::Type::Array>
L<Ctypes::Type::Struct>

=cut

1;
__END__
