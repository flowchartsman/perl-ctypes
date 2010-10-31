#!perl

use Test::More tests => 13;
use utf8;
BEGIN { use_ok( Ctypes ) }

my $c = c_char;
isa_ok( $c, 'Ctypes::Type::Simple' );
is( $c->typecode, 'c', 'Correct typecode' );
is( $c->sizecode, 'c', 'Correct sizecode' );
is( $c->packcode, 'c', 'Correct packcode' );
is( $c->name, 'c_char', 'Correct name' );

subtest 'c_char will not accept references' => sub {
  plan tests => 3;
  $$c = 100;
  $@ = undef;
  eval{  $$c = [1, 2, 3] };
  is( $$c, chr(100) );
  is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 100)) );
  like( $@, qr/c_char: cannot take references \(got ARRAY.*\)/ );
};

subtest 'c_char: number overflow' => sub {
  plan tests => 1024;
  for(-256..-129 ) {
    $$c = $_;
    is( $$c, chr($_ + 256) );
    is( ${$c->data}, pack($c->packcode, ($_ + 256) ) );
  }
  for(-128..-1 ) {
    $$c = $_;
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
  }
  for(0..127) {
    $$c = $_;
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
  }
  for(128..255) {
    $$c = $_;
    is( $$c, chr($_ - 256) );
    is( ${$c->data}, pack($c->packcode, ($_ - 256) ) );
  }
};

subtest 'c_char: character overflow' => sub {
  plan tests => 516;
  for(0..127) {
    $$c = chr($_);
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
  }
  for(128..257) {
    $$c = chr($_);
    is( $$c, chr($_ - 256) );
    is( ${$c->data}, pack($c->packcode, ($_ - 256) ) );
  }
};

$c->strict_input(1);

subtest 'c_char->strict_input prevents numeric overflow' => sub {
  plan tests => 1536;
  $$c = 'P';
  for(-256..-129 ) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P')) );
    like( $@, qr/c_char: numeric values must be integers -128 <= x <= 127 \(got $_\)/ );
  }
  for(-128..-1) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
    is( $@, '' );
  }
  for(0..127) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
    is( $@, '' );
  }
  $$c = 'P';
  for(128..255 ) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P')) );
    like( $@, qr/c_char: numeric values must be integers -128 <= x <= 127 \(got $_\)/ );
  }
};

subtest 'c_byte->strict_input prevents overflow of characters' => sub {
  plan tests => 646;
  for(0..127) {
    $$c = chr($_);
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_) );
  }
  $$c = 'P';
  for(128..257) {
    $@ = undef;
    eval { $$c = chr($_) };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P') ) );
    my $like = chr($_);
    like( $@, qr/c_char: character values must be 0 <= ord\(x\) <= 127 \(got $like\)/ );
  }
};

$c->strict_input(0);
Ctypes::Type::strict_input_all(1);

subtest 'c_char: strict_input_all prevents numeric overflow' => sub {
  plan tests => 1536;
  $$c = 'P';
  for(-256..-129 ) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P')) );
    like( $@, qr/c_char: numeric values must be integers -128 <= x <= 127 \(got $_\)/ );
  }
  for(-128..-1) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
    is( $@, '' );
  }
  for(0..127) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_ ) );
    is( $@, '' );
  }
  $$c = 'P';
  for(128..255 ) {
    undef $@;
    eval { $$c = $_ };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P')) );
    like( $@, qr/c_char: numeric values must be integers -128 <= x <= 127 \(got $_\)/ );
  }
};

subtest 'c_byte: strict_input_all prevents overflow of characters' => sub {
  plan tests => 646;
  for(0..127) {
    $$c = chr($_);
    is( $$c, chr($_) );
    is( ${$c->data}, pack($c->packcode, $_) );
  }
  $$c = 'P';
  for(128..257) {
    $@ = undef;
    eval { $$c = chr($_) };
    is( $$c, 'P' );
    is( ${$c->data}, pack($c->packcode, ord('P') ) );
    my $like = chr($_);
    like( $@, qr/c_char: character values must be 0 <= ord\(x\) <= 127 \(got $like\)/ );
  }
};

