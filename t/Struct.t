#!perl

BEGIN { unshift @INC, './t' }

use Test::More tests => 89;
use Ctypes;
use Ctypes::Type::Struct;
use Data::Dumper;
use t_POINT;

my $struct = Struct([
  f1 => c_char('P'),
  f2 => c_int(10),
  f3 => c_long(90000),
]);

note( 'Simple construction (arrayref)' );

isa_ok( $struct, 'Ctypes::Type::Struct' );
is( $struct->name, 'Struct' );
is( $struct->{f1}, 'P' ); #3
is( $struct->{f2}, 10 );
is( $struct->{f3}, 90000 );
my $size = Ctypes::sizeof('c') + Ctypes::sizeof('i')
           + Ctypes::sizeof('l');
is( $struct->size, $size );

my $alignedstruct = Struct({
  fields => [
    o1 => c_char('Q'),
    o2 => c_int(20),
    o3 => c_long(180000),
  ],
  align => 4,
});

note( 'Ordered construction (arrayref)' );

isa_ok( $alignedstruct, 'Ctypes::Type::Struct' );
is( $alignedstruct->name, 'Struct' );
is( $alignedstruct->{o1}, 'Q' );
is( $alignedstruct->{o2}, 20 );
is( $alignedstruct->{o3}, 180000 );
$size = 0;
my $delta = 0;
for(qw|c i l|) {
  $delta = Ctypes::sizeof($_);
  $delta += abs( $delta - 4 ) % 4 if $delta % 4;
  $size += $delta;
}
is( $alignedstruct->size, $size );
is( $alignedstruct->align, 4 );
$alignedstruct->align(8);
is( $alignedstruct->align, 8 );
eval { $alignedstruct->align(7) };
is( $alignedstruct->align, 8 );
like( $@, qr/Invalid argument for _alignment method: 7/,
  '->align validation ok' );

my $point = t_POINT->new( 30, 40 );
subtest 'Positional parameterised initialisation' => sub {
  plan tests => 6;
  isa_ok( $point, 't_POINT' );
  is( $point->name, 't_POINT_Struct' );
  is( $point->{x}, 30 );
  is( $point->{y}, 40 );
  is( $point->[0], 30 );
  is( $point->[1], 40 );
};

my $point_2 = new t_POINT([ y => 30, x => 40 ]);
my $point_3 = new t_POINT([ y => 50 ]);

note( 'Named parameter initialisation' );

isa_ok( $point_2, 't_POINT' );
isa_ok( $point_2, 'Ctypes::Type::Struct' );
is( $point_2->{x}, 40 );
is( $point_2->{y}, 30 );
isa_ok( $point_3, 't_POINT' );
isa_ok( $point_3, 'Ctypes::Type::Struct' );
is( $point_3->{y}, 50 );
is( $point_3->{x}, 0 );

note( 'Data access' );

is( $struct->{f2}, 10 );
is( $struct->fields->{f2}->name, 'c_int' );
$struct->{f2} = 30;
is( $struct->{f2}, 30 );
$struct->values->{f2} = 50;
is( $struct->{f2}, 50 );
is( $struct->[1], 50 );
$struct->[1] = 10;
is( $struct->[1], 10 );
$struct->values->[1] = 30;
is( $struct->[1], 30 );

my $data = pack('c',80) . pack('i',30) . pack('l',90000);
is( ${$struct->data}, $data, '->data looks alright' );
my $twentyfive = pack('i',25);
my $dataref = $struct->data;
substr( ${$dataref}, 1, length($twentyfive) ) = $twentyfive;
is( $struct->[1], 25, 'Members call up for fresh data' );

note( 'Attribute access' );

is( $struct->name, 'Struct' );
is( $struct->typecode, 'p' );
is( $struct->align, 0 );
is( $struct->size, 9 );
is( $struct->fields->{f2}, '<Field type=c_int, ofs=1, size=4>' );
is( $alignedstruct->fields->{o2}, '<Field type=c_int, ofs=4, size=4>' );
is( $struct->fields->[1]->info, '<Field type=c_int, ofs=1, size=4>' );
is( $alignedstruct->fields->[1]->info, '<Field type=c_int, ofs=4, size=4>' );
is( $struct->fields->{f2}->index, 1  );
is( $alignedstruct->fields->{o2}->index, 4 );
is( $struct->fields->[1]->index, 1  );
is( $alignedstruct->fields->[1]->index, 4 );
is( $struct->fields->{f1}->index, 0  );
is( $struct->fields->{f2}->index, 1  );
is( $struct->fields->{f3}->index, 5  );
is( $struct->fields->{f1}->name, 'c_char'  );
is( $struct->fields->{f2}->name, 'c_int'  );
is( $struct->fields->{f3}->name, 'c_long'  );
is( $struct->fields->{f1}->size, 1 );
is( $struct->fields->{f2}->size, 4 );
is( $struct->fields->{f3}->size, 4 );
is( $struct->fields->{f1}->typecode, 'c', "typecode field f1 - c unsigned char from pack" );
is( $struct->fields->{f2}->typecode, 'i' );
is( $struct->fields->{f3}->typecode, 'l' );
is( $struct->fields->{f1}->owner, $struct );
is( $struct->fields->{f2}->owner, $struct );
is( $struct->fields->{f3}->owner, $struct );
is( $struct->fields->[0]->index, 0  );
is( $struct->fields->[2]->index, 5  );
is( $struct->fields->[0]->name, 'c_char'  );
is( $struct->fields->[1]->name, 'c_int'  );
is( $struct->fields->[2]->name, 'c_long'  );
is( $struct->fields->[0]->size, 1 );
is( $struct->fields->[1]->size, 4 );
is( $struct->fields->[2]->size, 4 );
is( $struct->fields->[0]->typecode, 'c', "typecode field 0 - c unsigned char from pack" );
is( $struct->fields->[1]->typecode, 'i' );
is( $struct->fields->[2]->typecode, 'l' );
is( $struct->fields->[0]->owner, $struct );
is( $struct->fields->[1]->owner, $struct );
is( $struct->fields->[2]->owner, $struct );

note( 'Arrays in Structs' );

my $grades = Array( 49, 80, 55, 75, 89, 31, 45, 65, 40, 71 );
my $class = Struct({ fields => [
  teacher => 'P',
  grades  => $grades,
] });

my $total;
for( @{ $$class->{grades} } ) { $total += $_ };
my $average = $total /  $$class->{grades}->scalar;
is( $average, 60, "Mr Peterson's class could do better" );
is( $$class->{grades}[0], 49 );
is( $$class->{grades}->scalar, 10 );

note( 'Structs in structs' );
  
my $flowerbed = Struct([
  roses => 3,
  heather => 5,
  weeds => 2,
]);

my $garden = Struct({ fields => [
  fence => 30,
  flowerbed => $flowerbed,
  lawn => 20,
] });

is( $garden->{flowerbed}->fields->{roses},
    '<Field type=c_short, ofs=0, size=2>',
    '$garden->{flowerbed}->fields->{roses} gives field (how nice...)' );
is( $$garden->{flowerbed}->{roses},
    '3','$$garden->{flowerbed}->fields->{roses} gives 3' );
is( $garden->{flowerbed}->{roses},
    '3','$garden->{flowerbed}->{roses} also gives 3' );

my $home = Struct({ fields => [
  house => 40,
  driveway => 20,
  garden => $garden,
] });

is( $home->{garden}->{flowerbed}->fields->{heather},
    '<Field type=c_short, ofs=2, size=2>',
    '$home->{garden}->{flowerbed}->fields->{heather} gives field info' );
is( $$home->{garden}->{flowerbed}->{heather},
    '5', '$$home->{garden}->{flowerbed}->{heather} gives 5' );
$home->{garden}->{flowerbed}->{heather} = 500;
is( $garden->{flowerbed}->{heather}, 500, "That's a quare load o' heather - garden updated via \$home" );
is( $$garden->[1]->[1], 500 );

note( 'Pointers' );

my $ptr = Pointer( Array( 5, 4, 3, 2, 1 ) );
my $arr = Array( 10, 20, 30, 40, 50 );
print "FOOOOOOOOOOOOOOOOOOOOB!\n";
my $stct = Struct([ pointer => $ptr,
                    array   => $arr, ]);
$total = 0;
$total += $_ for( @{ $$stct->{array} } );
is( $total, 150 );
 $total += $_ for( @{ $$stct->{pointer}->deref } );
is( $total, 165 );
$$stct->{array}->[0] = 60;
is( $stct->fields->[1], '<Field type=short_Array, ofs=4, size=10>' );
is( $stct->fields->[1]->[0], 60 );
