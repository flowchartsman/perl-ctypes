#!perl

use Test::More tests => 13;
use utf8;
BEGIN { use_ok( Ctypes ) }

my $b = c_byte;
isa_ok( $b, 'Ctypes::Type::Simple' );
is( $b->typecode, 'b', 'Correct typecode' );

subtest 'c_byte accpeted value "10"' => sub {
  plan tests => 2;
  $$b = 10;
  is( $$b, 10 );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 10)) );
};

subtest 'c_byte accepted value "255"' => sub {
  plan tests => 2;
  $$b = 255;
  is( $$b, 255 );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 255)) );
};

subtest 'c_byte overflowed value "256" to "0"' => sub {
  plan tests => 2;
  $$b = 256;
  is( $$b, 0 );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 256)) );
};

subtest 'c_byte overflowed value "-56" to "200"' => sub {
  plan tests => 2;
  $$b = -56;
  is( $$b, 200 );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 200)) );
};

subtest 'c_byte accepted value "Y"' => sub {
  plan tests => 2;
  $$b = 'Y';
  is( $$b, 'Y' );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 89)) );
};

subtest 'c_byte accepted value "Y"' => sub {
  plan tests => 2;
  $$b = "\xA1";
  is( ord($$b), 161 );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 161)) );
};

subtest 'c_byte accepted value "Y"' => sub {
  plan tests => 2;
  $$b = "\x80";
  is( ord($$b), 128 );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 128)) );
};

subtest 'c_byte overflowed unicode "ā" to 1' => sub {
  plan tests => 2;
  binmode STDOUT, ":utf8";
  $$b = 'ā';
  is( $$b, chr(1) );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 257)) );
};

$b->strict_input(1);
$$b = 200;

subtest 'c_byte->strict_input prevents overflow' => sub {
  plan tests => 3;
  $@ = undef;
  eval{  $$b = 256 };
  is( $$b, 200 );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 200)) );
  like( $@, qr/c_byte: numeric values must be integers 0 < x < 255 \(got 256\)/ );
};

$b->strict_input(0);
Ctypes::Type::strict_input_all(1);

subtest 'Ctypes::Type->strict_input_all prevents overflow' => sub {
  plan tests => 3;
  $@ = undef;
  eval{  $$b = 256 };
  is( $$b, 200 );
  is( unpack('b*',${$b->data}), unpack('b*', pack('c*', 200)) );
  like( $@, qr/c_byte: numeric values must be integers 0 < x < 255 \(got 256\)/ );
};
