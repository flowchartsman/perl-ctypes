#!perl

use Test::More tests => 13;
use utf8;
BEGIN { use_ok( Ctypes ) }

my $b = c_ubyte;
isa_ok( $b, 'Ctypes::Type::Simple' );
is( $b->packcode, 'C', 'Correct packcode' );
is( $b->sizecode, 'c', 'Correct sizecode' );
is( $b->typecode, 'B', 'Correct typecode' );
is( $b->name, 'c_ubyte', 'Correct name' );

subtest 'c_ubyte: number overflow' => sub {
  plan tests => 1536;
  for(-256..-1 ) {
    $$b = $_;
    is( $$b, $_ + 256 );
    is( ${$b->data}, pack($b->packcode, ($_ + 256) ) );
  }
  for(0..255) {
    $$b = $_;
    is( $$b, $_ );
    is( ${$b->data}, pack($b->packcode, $_ ) );
  }
  for(256..511) {
    $$b = $_;
    is( $$b, $_ - 256 );
    is( ${$b->data}, pack($b->packcode, ($_ - 256) ) );
  }
};

subtest 'c_ubyte: character overflow' => sub {
  plan tests => 1024;
  for(0..255) {
    $$b = chr($_);
    is( $$b, chr($_) );
    is( ${$b->data}, pack($b->packcode, $_) );
  }
  for(256..511) {
    $$b = chr($_);
    is( $$b, chr($_ - 256) );
    is( ${$b->data}, pack($b->packcode, ($_ - 256) ) );
  }
};

$$b = 100;

subtest 'c_ubyte will not accept references' => sub {
  plan tests => 3;
  $@ = undef;
  eval{  $$b = [1, 2, 3] };
  is( $$b, 100 );
  is( unpack('b*',${$b->data}), unpack('b*', pack($b->packcode, 100)) );
  like( $@, qr/c_ubyte: cannot take references \(got ARRAY.*\)/ );
};

$b->strict_input(1);

subtest 'c_ubyte->strict_input prevents numeric overflow' => sub {
  plan tests => 2304;
  for(-256..-1 ) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, 100 );
    is( ${$b->data}, pack($b->packcode, 100) );
    like( $@, qr/c_ubyte: numeric values must be integers 0 <= x <= 255 \(got $_\)/ );
  }
  for(0..255) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, $_ );
    is( ${$b->data}, pack($b->packcode, $_ ) );
    is( $@, '' );
  }
  for(256..511) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, 255 );
    is( ${$b->data}, pack($b->packcode, 255) );
    like( $@, qr/c_ubyte: numeric values must be integers 0 <= x <= 255 \(got $_\)/ );
  }
};

subtest 'c_ubyte->strict_input prevents overflow of characters' => sub {
  plan tests => 1280;
  for(0..255) {
    $$b = chr($_);
    is( $$b, chr($_) );
    is( ${$b->data}, pack($b->packcode, $_) );
  }
  for(256..511) {
    $@ = undef;
    eval { $$b = chr($_) };
    is( $$b, chr(255) );
    is( ${$b->data}, pack($b->packcode, 255 ) );
    my $like = chr($_);
    like( $@, qr/c_ubyte: character values must be 0 <= ord\(x\) <= 255 \(got $like\)/ );
  }
};

$b->strict_input(0);
Ctypes::Type::strict_input_all(1);
$$b = 100;

subtest 'c_ubyte: strict_input_all prevents numeric overflow' => sub {
  plan tests => 2304;
  for(-256..-1 ) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, 100 );
    is( ${$b->data}, pack($b->packcode, 100) );
    like( $@, qr/c_ubyte: numeric values must be integers 0 <= x <= 255 \(got $_\)/ );
  }
  for(0..255) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, $_ );
    is( ${$b->data}, pack($b->packcode, $_ ) );
    is( $@, '' );
  }
  for(256..511) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, 255 );
    is( ${$b->data}, pack($b->packcode, 255) );
    like( $@, qr/c_ubyte: numeric values must be integers 0 <= x <= 255 \(got $_\)/ );
  }
};

subtest 'c_ubyte: strict_input_all prevents overflow of characters' => sub {
  plan tests => 1280;
  for(0..255) {
    $$b = chr($_);
    is( $$b, chr($_) );
    is( ${$b->data}, pack($b->packcode, $_) );
  }
  for(256..511) {
    $@ = undef;
    eval { $$b = chr($_) };
    is( $$b, chr(255) );
    is( ${$b->data}, pack($b->packcode, 255 ) );
    my $like = chr($_);
    like( $@, qr/c_ubyte: character values must be 0 <= ord\(x\) <= 255 \(got $like\)/ );
  }
};

