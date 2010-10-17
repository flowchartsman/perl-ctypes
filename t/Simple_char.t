#!perl

use Test::More tests => 19;
use utf8;
#  BEGIN { use_ok( Ctypes ) }
use Ctypes;
our $loc; # localise this and assign $_ to it in loops
          # to test number / string assignment correctly

my $c = c_char;
isa_ok( $c, 'Ctypes::Type::Simple' );
is( $c->typecode, 'c', 'Correct typecode' );
is( $c->sizecode, 'c', 'Correct sizecode' );
is( $c->packcode, 'c', 'Correct packcode' );
is( $c->name, 'c_char', 'Correct name' );

$$c = 100;

subtest 'c_char will not accept references' => sub {
  plan tests => 3;
  $@ = undef;
  eval{  $$c = [1, 2, 3] };
  is( $$c, chr(100) );
  is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 100)) );
  like( $@, qr/c_char: cannot take references \(got ARRAY.*\)/ );
};

#  subtest 'c_char accpeted value "10"' => sub {
#    plan tests => 2;
#    $$c = 10;
#    is( $$c, 10 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 10)) );
#  };
#  
#  subtest 'c_char accepted value "255"' => sub {
#    plan tests => 2;
#    $$c = 255;
#    is( $$c, 255 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 255)) );
#  };
#  
#  subtest 'c_char overflowed value "256" to "0"' => sub {
#    plan tests => 2;
#    $$c = 256;
#    is( $$c, 0 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 256)) );
#  };
#  
#  subtest 'c_char overflowed value "-56" to "200"' => sub {
#    plan tests => 2;
#    $$c = -56;
#    is( $$c, 200 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 200)) );
#  };
#  
#  subtest 'c_char accepted value "\xA1"' => sub {
#    plan tests => 2;
#    $$c = "\xA1";
#    is( ord($$c), 161 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 161)) );
#  };
#  
#  subtest 'c_char accepted value "\x80"' => sub {
#    plan tests => 2;
#    $$c = "\x80";
#    is( ord($$c), 128 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 128)) );
#  };
#  
#  subtest 'c_char overflowed unicode "ā" to 1' => sub {
#    plan tests => 2;
#    binmode STDOUT, ":utf8";
#    $$c = 'ā';
#    is( $$c, chr(1) );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, ord('ā'))) );
#  };
#  
#  $$c = 200;
#  
#  
#  $c->strict_input(1);
#  
#  subtest 'c_char->strict_input prevents overflow of numerics' => sub {
#    plan tests => 3;
#    $@ = undef;
#    eval{  $$c = 256 };
#    is( $$c, 200 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 200)) );
#    like( $@, qr/c_char: numeric values must be integers 0 <= x <= 255 \(got 256\)/ );
#  };
#  
#  subtest 'c_char->strict_input prevents overflow of characters' => sub {
#    plan tests => 3;
#    $@ = undef;
#    eval{  $$c = 'ā' };
#    is( $$c, 200 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 200)) );
#    like( $@, qr/c_char: character values must be 0 <= ord\(x\) <= 255 \(got ā\)/ );
#  };
#  
#  $c->strict_input(0);
#  Ctypes::Type::strict_input_all(1);
#  
#  subtest 'Ctypes::Type->strict_input_all prevents overflow of numerics' => sub {
#    plan tests => 3;
#    $@ = undef;
#    eval{  $$c = 256 };
#    is( $$c, 200 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 200)) );
#    like( $@, qr/c_char: numeric values must be integers 0 <= x <= 255 \(got 256\)/ );
#  };
#  
#  subtest 'c_char->strict_input prevents overflow of characters' => sub {
#    plan tests => 3;
#    $@ = undef;
#    eval{  $$c = 'ā' };
#    is( $$c, 200 );
#    is( unpack('b*',${$c->data}), unpack('b*', pack($c->packcode, 200)) );
#    like( $@, qr/c_char: character values must be 0 <= ord\(x\) <= 255 \(got ā\)/ );
#  };
