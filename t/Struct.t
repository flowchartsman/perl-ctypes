#!perl

use Test::More tests => 0;
use Ctypes;

use "ct_POINT.pm";
use "ct_RECT.pm";
use "ct_SQUARE.pm";   # isa RECT with extra restrictions & field 'foo'

my $point = ct_POINT(5, 15);
isa_ok( $point, qw|POINT Ctypes::Type::Struct|,
        'point is a POINT and a Struct');

# From Python docs:

# _fields_
#   A sequence defining the structure fields. The items must be
#   2-tuples or 3-tuples. The first item is the name of the field,
#   the second item specifies the type of the field; it can be
#   any ctypes data type.

is( $point->_fields_, 
    [ [ 'x', 'Ctypes::Type::Simple' ], [ 'y', 'Ctypes::Type::Simple' ] ],
    '$st->_fields_ returns names and type names' );
is( $point->y, 15, '$st-><field> returns value' );
is( ct_POINT->x,
    { name => x, type => 'l', size => 4, ofs => 0 },
    'Class methods return field info' );

#   Integer type fields like c_int, a third optional item can be
#   given. It must be a small positive integer defining the bit
#   width of the field.

# TODO Don't know how to do this yet
# my $struct = Struct( [ 'field', c_int, 8 ] );

#   Field names must be unique within one structure or union. This
#   is not checked, only one field can be accessed when names are repeated.
### Can check this for dynamically made Structs though:

my $struct = Struct( [ 'field', c_int ], [ 'field', c_long ] );
# Should carp a warning
is( $stuct, undef, 'Cannot have two fields with the same name' );

### ??? What about sub-subclasses?
# Will be seen to be replacing the accessor for the ancestor class I guess

#   It is possible to define the _fields_ class variable after
#   the class statement that defines the Structure subclass,
#   this allows to create data types that directly or indirectly
#   reference themselves:
#      class List(Structure):
#          pass
#      List._fields_ = [("pnext", POINTER(List)),
#                        ...
#                      ]
#   The _fields_ class variable must, however, be defined before the
#   type is first used (an instance is created, sizeof() is called
#   on it, and so on). Later assignments to the _fields_ class variable
#   will raise an AttributeError.
### ??? Does this apply to Perl?

package Flower;
our @ISA = 'Ctypes::Type::Struct';

package main;

my $flower = Flower( 'r', 20 );
is( $flower, undef, 'Cannot instantiate Struct class without fields' );

Flower::_fields_ = [['colour',c_char],['height',c_ushort]];
$flower = Flower( 'r', 20 );
isa_ok( $flower,
        qw|Flower Ctypes::Type::Struct|,
        'Flower Struct created after defining fields' );

#   Structure and union subclass constructors accept both positional
#   and named arguments. Positional arguments are used to initialize
#   the fields in the same order as they appear in the _fields_
#   definition, named arguments are used to initialize the fields with
#   the corresponding name or create new attributes for names not
#   present in _fields_.

my $flower2 = Flower( { height => 30, loveliness => 10 } );
isa_ok( $flower, qw|Flower Ctypes::Type::Struct|, 'flower2 created' );
is( $flower2->loveliness, 10, 'Create new attributes with named arguments' );

# What happens with too many positional args?
my $flower3 = undef;
eval { $flower3 = Flower( 'p', 8, 5 ); }
is( $flower3, undef, "Can't instantiate with too many args" );
like( $@, qr/too many arguments/i, 'Warned about extraneous args' );

#   It is possible to defined sub-subclasses of structure types, they
#   inherit the fields of the base class plus the _fields_ defined in
#   the sub-subclass, if any.

package Daffodil;
our @ISA = 'Flower';
our $_fields_ = [ ['trumpetsize', c_ushort ] ];

package main;

my $daffodil = Daffodil( 'y', 28, 15  );
is( $daffodil->trumpetsize, 15, "That's a respectable trumpet" );
is( $daffyfields->_fields_, 
    [ { name => colour, type => 'c', size => 1, ofs => 0 },
      { name => height, type => 'S', size => 2, ofs => 0 },
      { name => trumpetsize, type => 'S', size => 2, ofs => 0 }, ]
    '$st->_fields_ returns names and type names' );

#   It is possible to defined sub-subclasses of structures, they inherit
#   the fields of the base class. If the subclass definition has a
#   separate _fields_ variable, the fields specified in this are
#   appended to the fields of the base class.

# _pack_
#   An optional small integer that allows to override the alignment
#   of structure fields in the instance. _pack_ must already be defined
#   when _fields_ is assigned, otherwise it will have no effect.

### Don't understand the following feature; not sure it applies to our
### dynamic implementation:

# _anonymous_
#
#   An optional sequence that lists the names of unnamed (anonymou 
#   s) fields. _anonymous_ must be already defined when _fields_ is as
#   signed, otherwise it will have no effect.
#
#   The fields listed in this variable must be structure or union 
#   type fields. ctypes will create descriptors in the structure t
#   ype that allows to access the nested fields directly, without 
#   the need to create the structure or union field.
#
#   Here is an example type (Windows):
#
#   class _U(Union):
#       _fields_ = [("lptdesc", POINTER(TYPEDESC)),
#                   ("lpadesc", POINTER(ARRAYDESC)),
#                   ("hreftype", HREFTYPE)]
#
#   class TYPEDESC(Structure):
#       _anonymous_ = ("u",)
#       _fields_ = [("u", _U),
#                   ("vt", VARTYPE)]
#
#   The TYPEDESC structure describes a COM data type, the vt field
#   specifies which one of the union fields is valid. Since the u 
#   field is defined as anonymous field, it is now possible to acc
#   ess the members directly off the TYPEDESC instance. td.lptdesc
#   and td.u.lptdesc are equivalent, but the former is faster sin
#   ce it does not need to create a temporary union instance:
#
#   td = TYPEDESC()
#   td.vt = VT_PTR
#   td.lptdesc = POINTER(some_type)
#   td.u.lptdesc = POINTER(some_type)
#
