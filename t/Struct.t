#!perl

BEGIN { unshift @INC, './t' }

use Test::More tests => 5;
use Ctypes;
use Data::Dumper;
use attributes;
my $Debug = 0;

use t_POINT;

my $point = new t_POINT(5, 15);
isa_ok( $point, qw|POINT Ctypes::Type::Struct|,'t_POINT');
my $struct;
eval { 
  $struct
    = Struct({ fields => [ [ 'field', c_int ], [ 'field', c_long ] ] });
     };
like( $@, qr/defined more than once/,
     'Cannot have two fields with the same name' );

ok( $point->field_list->[0][0] eq 'x'
  && $point->field_list->[1][1]->type eq 'i',
  '$st->_fields_ returns names and type names' );
 is( $$point->x, '5', '$st-><field> returns value' );
 is( $$point->y, '15', '$st-><field> returns value' );
$point->y->(20);
is( $$point->y, 20, '$st->field->(20) sets value' );
$struct = Struct({ fields => [ ['foo',c_int], ['bar',c_double] ] });
my $int = c_int(4);
$int->allow_overflow(0);
$struct->foo->($int);
eval{ $struct->foo->(20000000000000000000000000) };
is( $$struct->foo, 4, 'Simple types maintain attributes' );
$struct->foo->(7);
is( $$int, 7, 'Modify members without squashing' );

$struct->bar->(14);
my $data = pack('i',7) . pack('d',14);
is( ${$struct->_data}, $data, '_data looks alright' );
my $twentyfive = pack('i',25);
my $dataref = $struct->_data;
substr( ${$dataref}, 0, length($twentyfive) ) = $twentyfive;
is( $$int, 25, 'Data modifications percolate down' );

subtest 'Multiple indirection' => sub {
  plan tests => 5;
  
  my $flowerbed = Struct({ fields => [
    [ roses => 3 ],
    [ heather => 5 ],
    [ weeds => 2 ],
  ] });
  
  my $garden = Struct({ fields => [
    [ fence => 30 ],
    [ flowerbed => $flowerbed ],
    [ lawn => 20 ],
  ] });
  
  #print '$garden->flowerbed: ',$garden->flowerbed, "\n";
  #print '$$garden->flowerbed: ', $$garden->flowerbed, "\n\n";
  
  #print '$garden->flowerbed->contents: ',$garden->flowerbed->contents, "\n";
  #print '$$garden->flowerbed->contents: ',$$garden->flowerbed->contents, "\n\n";
  
  #print '$garden->flowerbed->roses: ',$garden->flowerbed->roses, "\n";
  #print '$$garden->flowerbed->roses: ',$$garden->flowerbed->roses, "\n\n";
  
  #print '$garden->flowerbed->contents->roses: ',$garden->flowerbed->contents->roses, "\n";
  #print '$$garden->flowerbed->contents->roses: ', $$garden->flowerbed->contents->roses, "\n\n";
  
  is( $garden->flowerbed->contents->roses,
      '<Field type=c_short, ofs=0, size=2>',
      '$st->field->contents->x gives field' );
  is( $$garden->flowerbed->contents->roses,
      '3','$$st->field->contents->x gives value' );
  
  my $home = Struct({ fields => [
    [ house => 40 ],
    [ driveway => 20 ],
    [ garden => $garden ],
  ] });
  
  # print $home->garden->contents->flowerbed->contents->heather, "\n";
  # print $$home->garden->contents->flowerbed->contents->heather, "\n";
  
  is( $home->garden->contents->flowerbed->contents->heather,
      '<Field type=c_short, ofs=2, size=2>',
      '$st->field->contents->x gives field' );
  is( $$home->garden->contents->flowerbed->contents->heather,
      '5', '$$st->field->contents->x gives value' );
  $home->garden->contents->flowerbed->contents->heather->(500);
  is( $$garden->heather, 500, "That's a quare load o' heather" );
};

