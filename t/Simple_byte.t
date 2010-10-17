#!perl

use Test::More tests => 13;
use utf8;
BEGIN { use_ok( Ctypes ) }

my $b = c_byte;
isa_ok( $b, 'Ctypes::Type::Simple' );
is( $b->typecode, 'b', 'Correct typecode' );
is( $b->sizecode, 'c', 'Correct sizecode' );
is( $b->packcode, 'c', 'Correct packcode' );
is( $b->name, 'c_byte', 'Correct name' );

subtest 'c_byte: number overflow' => sub {
  plan tests => 1024;
  for(-256..-129 ) {
    $$b = $_;
    is( $$b, $_ + 256 );
    is( ${$b->data}, pack($b->packcode, ($_ + 256) ) );
  }
  for(-128..127) {
    $$b = $_;
    is( $$b, $_ );
    is( ${$b->data}, pack($b->packcode, $_ ) );
  }
  for(128..255) {
    $$b = $_;
    is( $$b, $_ - 256 );
    is( ${$b->data}, pack($b->packcode, ($_ - 256) ) );
  }
};

subtest 'c_byte: character overflow' => sub {
  plan tests => 516;
  for(0..127) {
    $$b = chr($_);
    is( $$b, chr($_) );
    is( ${$b->data}, pack($b->packcode, $_) );
  }
  for(128..257) {
    $$b = chr($_);
    is( $$b, chr($_ - 256) );
    is( ${$b->data}, pack($b->packcode, ($_ - 256) ) );
  }
};

$$b = 100;

subtest 'c_byte will not accept references' => sub {
  plan tests => 3;
  $@ = undef;
  eval{  $$b = [1, 2, 3] };
  is( $$b, 100 );
  is( unpack('b*',${$b->data}), unpack('b*', pack($b->packcode, 100)) );
  like( $@, qr/c_byte: cannot take references \(got ARRAY.*\)/ );
};

$b->strict_input(1);

subtest 'c_byte->strict_input prevents numeric overflow' => sub {
  plan tests => 1536;
  for(-256..-129 ) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, 100 );
    is( ${$b->data}, pack($b->packcode, 100) );
    like( $@, qr/c_byte: numeric values must be integers -128 <= x <= 127 \(got $_\)/ );
  }
  for(-128..127) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, $_ );
    is( ${$b->data}, pack($b->packcode, $_ ) );
    is( $@, '' );
  }
  for(128..255 ) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, 127 );
    is( ${$b->data}, pack($b->packcode, 127) );
    like( $@, qr/c_byte: numeric values must be integers -128 <= x <= 127 \(got $_\)/ );
  }
};

subtest 'c_byte->strict_input prevents overflow of characters' => sub {
  plan tests => 646;
  for(0..127) {
    $$b = chr($_);
    is( $$b, chr($_) );
    is( ${$b->data}, pack($b->packcode, $_) );
  }
  for(128..257) {
    $@ = undef;
    eval { $$b = chr($_) };
    is( $$b, chr(127) );
    is( ${$b->data}, pack($b->packcode, 127 ) );
    my $like = chr($_);
    like( $@, qr/c_byte: character values must be 0 <= ord\(x\) <= 127 \(got $like\)/ );
  }
};

$b->strict_input(0);
Ctypes::Type::strict_input_all(1);
$$b = 100;

subtest 'c_byte: strict_input_all prevents numeric overflow' => sub {
  plan tests => 1536;
  for(-256..-129 ) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, 100 );
    is( ${$b->data}, pack($b->packcode, 100) );
    like( $@, qr/c_byte: numeric values must be integers -128 <= x <= 127 \(got $_\)/ );
  }
  for(-128..127) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, $_ );
    is( ${$b->data}, pack($b->packcode, $_ ) );
    is( $@, '' );
  }
  for(128..255 ) {
    undef $@;
    eval { $$b = $_ };
    is( $$b, 127 );
    is( ${$b->data}, pack($b->packcode, 127) );
    like( $@, qr/c_byte: numeric values must be integers -128 <= x <= 127 \(got $_\)/ );
  }
};

subtest 'c_byte: strict_input_all prevents overflow of characters' => sub {
  plan tests => 646;
  for(0..127) {
    $$b = chr($_);
    is( $$b, chr($_) );
    is( ${$b->data}, pack($b->packcode, $_) );
  }
  for(128..257) {
    $@ = undef;
    eval { $$b = chr($_) };
    is( $$b, chr(127) );
    is( ${$b->data}, pack($b->packcode, 127 ) );
    my $like = chr($_);
    like( $@, qr/c_byte: character values must be 0 <= ord\(x\) <= 127 \(got $like\)/ );
  }
};

