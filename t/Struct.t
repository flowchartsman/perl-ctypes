#!perl

BEGIN { unshift @INC, './t' }

use Test::More tests => 1;
use Ctypes;
use Data::Dumper;
use t_POINT;
my $Debug = 0;

my $point = new t_POINT( 30, 40 );
subtest 'Positional parameterised initialisation' => sub {
  plan tests => 3;
  isa_ok( $point, 't_POINT' );
  is( $$point->{x}, 30 );
  is( $$point->{y}, 40 );
};

my $point_2 = new t_POINT([ y => 30, x => 40 ]);
my $point_3 = new t_POINT([ y => 50 ]);
subtest 'Named parameter initialisation' => sub {
  plan tests => 8;
  isa_ok( $point_2, 't_POINT' );
  isa_ok( $point_2, 'Ctypes::Type::Struct' );
  is( $$point_2->{x}, 40 );
  is( $$point_2->{y}, 30 );
  isa_ok( $point_3, 't_POINT' );
  isa_ok( $point_3, 'Ctypes::Type::Struct' );
  is( $$point_3->{y}, 50 );
  is( $$point_3->{x}, 0 );
};

my $struct = Struct([
  f1 => c_char('P'),
  f2 => c_int(10),
  f3 => c_long(90000),
]);
subtest 'Simple construction (arrayref)' => sub {
  plan tests => 5;
  isa_ok( $struct, 'Ctypes::Type::Struct' );
  is( chr( $$struct->{f1} ), 'P' );
  is( $$struct->{f2}, 10 );
  is( $$struct->{f3}, 90000 );
  my $size = Ctypes::sizeof('c') + Ctypes::sizeof('i')
             + Ctypes::sizeof('l');
  is( $struct->size, $size );
};

my $alignedstruct = Struct({
  fields => [
    o1 => c_char('Q'),
    o2 => c_int(20),
    o3 => c_long(180000),
  ],
  align => 4,
});
subtest 'Ordered construction (arrayref)' => sub {
  plan tests => 5;
  isa_ok( $alignedstruct, 'Ctypes::Type::Struct' );
  is( chr($$alignedstruct->{o1}), 'Q' );
  is( $$alignedstruct->{o2}, 20 );
  is( $$alignedstruct->{o3}, 180000 );
  my( $size, $delta );
  for(qw|c i l|) {
    $delta = Ctypes::sizeof($_);
    $delta += abs( $delta - 4 ) % 4 if $delta % 4;
    $size += $delta;
  }
  is( $alignedstruct->size, $size );
};

subtest 'Data access' => sub {
  plan tests => 6;
  is( $$struct->{f2}, 10 );
  $$struct->{f2} = 30;
  is( $$struct->{f2}, 30 );
  $struct->fields->{f2} = 50;
  is( $$struct->{f2}, 50 );
  is( $$struct->{f2}->name, 'c_int' );
  is( $$struct->[1], 50 );
  $$struct->[1] = 10;
  is( $$struct->[1], 10 );
  $struct->fields->[1] = 30;
  is( $struct->fields->[1], 30 );
};

subtest 'Attribute access' => sub {
  plan tests => 4;
  is( $struct->name, 'Struct' );
  is( $struct->typecode, 'p' );
  is( $struct->align, 0 );
  is( $struct->size, 9 );
  # $struct->fields->f1->info ? <Field type=c_int, ofs=0, size=4>
};

#  my $data = pack('i',7) . pack('d',14);
#  is( ${$struct->data}, $data, '_data looks alright' );
#  my $twentyfive = pack('i',25);
#  my $dataref = $struct->data;
#  substr( ${$dataref}, 0, length($twentyfive) ) = $twentyfive;
#  is( $$int, 25, 'Data modifications percolate down' );
#  
#  # Nesting is nice
#  subtest 'Arrays in structs' => sub {
#    plan tests => 1;
#  
#    my $grades = Array( 49, 80, 55, 75, 89, 31, 45, 65, 40, 71 );
#    my $class = Struct({ fields => [
#      [ teacher => 'P' ],
#      [ grades  => $grades ],
#    ] });
#  
#    my $total;
#    for( @{$$class->grades} ) { $total += $_ };
#    my $average = $total /  scalar @{$$class->grades};
#    is( $average, 60, "Mr Peterson's could do better" );
#  };
#  
#  subtest 'Structs in structs' => sub {
#    plan tests => 5;
#    
#    my $flowerbed = Struct({ fields => [
#      [ roses => 3 ],
#      [ heather => 5 ],
#      [ weeds => 2 ],
#    ] });
#    
#    my $garden = Struct({ fields => [
#      [ fence => 30 ],
#      [ flowerbed => $flowerbed ],
#      [ lawn => 20 ],
#    ] });
#    
#    #print '$garden->flowerbed: ',$garden->flowerbed, "\n";
#    #print '$$garden->flowerbed: ', $$garden->flowerbed, "\n\n";
#    
#    #print '$garden->flowerbed->contents: ',$garden->flowerbed->contents, "\n";
#    #print '$$garden->flowerbed->contents: ',$$garden->flowerbed->contents, "\n\n";
#    
#    #print '$garden->flowerbed->roses: ',$garden->flowerbed->roses, "\n";
#    #print '$$garden->flowerbed->roses: ',$$garden->flowerbed->roses, "\n\n";
#    
#    #print '$garden->flowerbed->contents->roses: ',$garden->flowerbed->contents->roses, "\n";
#    #print '$$garden->flowerbed->contents->roses: ', $$garden->flowerbed->contents->roses, "\n\n";
#    
#    is( $garden->flowerbed->contents->roses,
#        '<Field type=c_short, ofs=0, size=2>',
#        '$garden->flowerbed->contents->roses gives field (how nice...)' );
#    is( $$garden->flowerbed->contents->roses,
#        '3','$$garden->flowerbed->contents->roses gives 3' );
#    
#    my $home = Struct({ fields => [
#      [ house => 40 ],
#      [ driveway => 20 ],
#      [ garden => $garden ],
#    ] });
#    
#    # print $home->garden->contents->flowerbed->contents->heather, "\n";
#    # print $$home->garden->contents->flowerbed->contents->heather, "\n";
#    
#    is( $home->garden->contents->flowerbed->contents->heather,
#        '<Field type=c_short, ofs=2, size=2>',
#        '$home->garden->contents->flowerbed->contents->heather gives field' );
#    is( $$home->garden->contents->flowerbed->contents->heather,
#        '5', '$$home->garden->contents->flowerbed->contents->heather gives 5' );
#    $home->garden->contents->flowerbed->contents->heather->(500);
#    is( $$garden->heather, 500, "That's a quare load o' heather - garden updated via \$home" );
#  };
#  
