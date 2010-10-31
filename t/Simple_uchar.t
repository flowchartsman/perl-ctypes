#!perl

use Test::More tests => 13;
use utf8;
BEGIN { use_ok( Ctypes ) }

my $c = c_uchar;
isa_ok( $c, 'Ctypes::Type::Simple' );
is( $c->typecode, 'C', 'Correct typecode' );
is( $c->sizecode, 'C', 'Correct sizecode' );
is( $c->packcode, 'C', 'Correct packcode' );
is( $c->name, 'c_uchar', 'Correct name' );

subtest 'c_uchar will not accept references' => sub {
  plan tests => 3;
  $$c = 100;
  $@ = undef;
  eval{  $$c = [1, 2, 3] };
  is( $$c, chr(100) );
  is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 100)) );
  like( $@, qr/c_uchar: cannot take references \(got ARRAY.*\)/ );
};

subtest 'c_uchar: number overflow' => sub {
  plan tests => 1536;
  for(-256..-1 ) {
    $$c = $_;
    is( $$c, chr($_ + 256) );
    is( ${$c->data}, pack($c->packcode, ($_ + 256) ) );
  }
  for(0..255) {
    $$c = $_;
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
  }
  for(256..511) {
    $$c = $_;
    is( $$c, chr($_ - 256) );
    is( ${$c->data}, pack($c->packcode, ($_ - 256) ) );
  }
};

subtest 'c_uchar: character overflow' => sub {
  plan tests => 1024;
  for(0..255) {
    $$c = chr($_);
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
  }
  for(256..511) {
    $$c = chr($_);
    is( $$c, chr($_ - 256) );
    is( ${$c->data}, pack($c->packcode, ($_ - 256) ) );
  }
};

$c->strict_input(1);

subtest 'c_uchar->strict_input prevents numeric overflow' => sub {
  plan tests => 2304;
  $$c = 'P';
  for(-256..-1 ) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P')) );
    like( $@, qr/c_uchar: numeric values must be integers 0 <= x <= 255 \(got $_\)/ );
  }
  for(0..255) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
    is( $@, '' );
  }
  $$c = 'P';
  for(256..511 ) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P')) );
    like( $@, qr/c_uchar: numeric values must be integers 0 <= x <= 255 \(got $_\)/ );
  }
};

subtest 'c_uchar->strict_input prevents overflow of characters' => sub {
plan tests => 1280;
  for(0..255) {
    $$c = chr($_);
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_) );
  }
  $$c = 'P';
  for(256..511) {
    $@ = undef;
    eval { $$c = chr($_) };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P') ) );
    my $like = chr($_);
    like( $@, qr/c_uchar: character values must be 0 <= ord\(x\) <= 255 \(got $like\)/ );
  }
};

$c->strict_input(0);
Ctypes::Type::strict_input_all(1);

subtest 'c_uchar: strict_input_all prevents numeric overflow' => sub {
  plan tests => 2304;
  $$c = 'P';
  for(-256..-1 ) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P')) );
    like( $@, qr/c_uchar: numeric values must be integers 0 <= x <= 255 \(got $_\)/ );
  }
  for(0..255) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
    is( $@, '' );
  }
  $$c = 'P';
  for(256..511 ) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P')) );
    like( $@, qr/c_uchar: numeric values must be integers 0 <= x <= 255 \(got $_\)/ );
  }
};

subtest 'c_uchar: strict_input_all prevents overflow of characters' => sub {
plan tests => 1280;
  for(0..255) {
    $$c = chr($_);
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_) );
  }
  $$c = 'P';
  for(256..511) {
    $@ = undef;
    eval { $$c = chr($_) };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P') ) );
    my $like = chr($_);
    like( $@, qr/c_uchar: character values must be 0 <= ord\(x\) <= 255 \(got $like\)/ );
  }
};

