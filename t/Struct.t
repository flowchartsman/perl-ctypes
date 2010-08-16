#!perl

BEGIN { unshift @INC, './t' }

use Test::More tests => 12;
use Ctypes;
use Data::Dumper;
my $Debug = 0;

use t_POINT;

my $point = new t_POINT(5, 15);

isa_ok( $point, 'Ctypes::Type::Struct', 't_POINT' );
my $struct;
eval { 
  $struct
    = Struct({ fields => [ [ 'field', c_int ], [ 'field', c_long ] ] });
     };
like( $@, qr/defined more than once/,
     'Cannot have two fields with the same name' );

# Getting
ok( $point->field_list->[0][0] eq 'x'
  && $point->field_list->[1][1]->typecode eq 'i',
  '$st->field_list returns names and type names' );
 is( $$point->x, '5', '$st-><field> returns value' );
 is( $$point->y, '15', '$st-><field> returns value' );

# Setting
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

# {_data}
$struct->bar->(14);
my $data = pack('i',7) . pack('d',14);
is( ${$struct->data}, $data, '_data looks alright' );
my $twentyfive = pack('i',25);
my $dataref = $struct->data;
substr( ${$dataref}, 0, length($twentyfive) ) = $twentyfive;
is( $$int, 25, 'Data modifications percolate down' );

# Nesting is nice
subtest 'Arrays in structs' => sub {
  plan tests => 1;

  my $grades = Array( 49, 80, 55, 75, 89, 31, 45, 65, 40, 71 );
  my $class = Struct({ fields => [
    [ teacher => 'P' ],
    [ grades  => $grades ],
  ] });

  my $total;
  for( @{$$class->grades} ) { $total += $_ };
  my $average = $total /  scalar @{$$class->grades};
  is( $average, 60, "Mr Peterson's could do better" );
};

subtest 'Structs in structs' => sub {
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
      '$garden->flowerbed->contents->roses gives field (how nice...)' );
  is( $$garden->flowerbed->contents->roses,
      '3','$$garden->flowerbed->contents->roses gives 3' );
  
  my $home = Struct({ fields => [
    [ house => 40 ],
    [ driveway => 20 ],
    [ garden => $garden ],
  ] });
  
  # print $home->garden->contents->flowerbed->contents->heather, "\n";
  # print $$home->garden->contents->flowerbed->contents->heather, "\n";
  
  is( $home->garden->contents->flowerbed->contents->heather,
      '<Field type=c_short, ofs=2, size=2>',
      '$home->garden->contents->flowerbed->contents->heather gives field' );
  is( $$home->garden->contents->flowerbed->contents->heather,
      '5', '$$home->garden->contents->flowerbed->contents->heather gives 5' );
  $home->garden->contents->flowerbed->contents->heather->(500);
  is( $$garden->heather, 500, "That's a quare load o' heather - garden updated via \$home" );
};

