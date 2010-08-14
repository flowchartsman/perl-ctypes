#!perl

BEGIN { unshift @INC, './t' }

use Test::More tests => 5;
use Ctypes;
use Data::Dumper;
use attributes;
my $Debug = 0;

use t_POINT;

my $point = new t_POINT(5, 15);
# isa_ok( $point, qw|POINT Ctypes::Type::Struct|,'t_POINT');

# ok( $point->field_list->[0][0] eq 'x'
#    && $point->field_list->[1][1]->type eq 'i',
#    '$st->_fields_ returns names and type names' );
 is( $$point->x, '5', '$st-><field> returns value' );
 is( $$point->y, '15', '$st-><field> returns value' );
print ref( $point->y ), "\n";
print "\$point->y: ", $point->y, "\n";
print "\$\$point->y: ", $$point->y, "\n";
$$point->y->(20);
is( $$point->y, 20, '$st->field->(20) sets value' );
print "\$point->y->type: ", $point->y->type, "\n";
print "\$point->y->type: ", $point->y->type, "\n";
print "\$\$point->y->type: ", $$point->y->type, "\n";

#eval { 
#  my $struct
#    = Struct({ fields => [ [ 'field', c_int ], [ 'field', c_long ] ] });
#     };
#like( $@, qr/defined more than once/,
#     'Cannot have two fields with the same name' );
#
#$struct = Struct({ fields => [ ['foo',c_int], ['bar',c_double] ] });
#is( $struct->foo->type, 'i' );
#is( $$struct->foo, 0 );


