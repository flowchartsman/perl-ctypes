#!perl

use Test::More tests => 19;
use utf8;
BEGIN { use_ok( Ctypes ) }

my $x = c_ulong;
isa_ok( $x, 'Ctypes::Type::Simple' );
is( $x->typecode, 'L', 'Correct typecode' );
is( $x->sizecode, 'l', 'Correct sizecode' );
is( $x->packcode, 'L', 'Correct packcode' );
is( $x->name, 'c_ulong', 'Correct name' );

my $range = \&Ctypes::Util::create_range;
my $name = $x->name;
my $MAX = Ctypes::constant('PERL_ULONG_MAX');
my $MIN = Ctypes::constant('PERL_ULONG_MIN');
my $cover = 100;
my $weight = 1;
my $want_int = 1;
my $diff = $MAX - $MIN + 1;
my $extra = 50;
my( $input, $like );

subtest "$name will not accept references" => sub {
  plan tests => 3;
  $$x = 95;
  $@ = undef;
  eval{  $$x = [1, 2, 3] };
  is( $$x, 95 );
  is( unpack('b*',${$x->data}), unpack('b*', pack($x->packcode, 95)) );
  like( $@, qr/$name: cannot take references \(got ARRAY.*\)/ );
};

subtest "$name drops numbers after decimal point" => sub {
  plan tests => 6;
  $$x = 95.2;
  is( $$x, 95 );
  is( ${$x->data}, pack($x->packcode, 95 ) );
  $$x = 95.5;
  is( $$x, 95 );
  is( ${$x->data}, pack($x->packcode, 95 ) );
  $$x = 95.8;
  is( $$x, 95 );
  is( ${$x->data}, pack($x->packcode, 95 ) );
};

# Exceeding range on _signed_ variables is undefined in the standard,
# so these tests can't really be any better.
subtest "$name: number overflow" => sub {
  for( $range->( $MIN - $extra, $MIN - 1 ) ) {
    $$x = $_;
    isnt( $$x, $_ );
    ok( $$x >= $MIN );
  }
  for( $range->( $MIN, $MAX, $cover, $weight, $want_int ) ) {
    $$x = $_;
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  for( $range->( $MAX + 1, $MAX + $extra ) ) {
    $$x = $_;
    isnt( $$x, $_ );
    ok( $$x <= $MAX );
  }
  done_testing();
};

subtest "$name: character overflow" => sub {
  for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
    $$x = chr($_);
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  for( $range->( $MAX + 1, $MAX + $extra) ) {
    $$x = chr($_);
    isnt( $$x, $_ );
    ok( $$x <= $MAX );
  }
  done_testing();
};

subtest "$name: characters after first discarded" => sub {
  for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
    $input = chr($_) . 'oubi';
    $$x = $input;
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  done_testing();
};

$x->strict_input(1);

subtest "$name->strict_input prevents dropping decimal places" => sub {
  plan tests => 9;
  $$x = 95;
  undef $@;
  eval { $$x = 100.2 };
  is( $$x, 95 );
  is( ${$x->data}, pack($x->packcode, 95 ) );
  like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.2\)/ );
  undef $@;
  eval { $$x = 100.5 };
  is( $$x, 95 );
  is( ${$x->data}, pack($x->packcode, 95 ) );
  like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.5\)/ );
  undef $@;
  eval { $$x = 100.8 };
  is( $$x, 95 );
  is( ${$x->data}, pack($x->packcode, 95 ) );
  like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.8\)/ );
};

subtest "$name->strict_input prevents numeric overflow" => sub {
  $$x = 95;
  for( $range->( $MIN - $extra, $MIN - 1 ) ) {
    undef $@;
    eval{ $$x = $_ };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
  }
  for( $range->( $MIN, $MAX, $cover, $weight, $want_int ) ) {
    undef $@;
    eval { $$x = $_ };
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
    is( $@, '' );
  }
  $$x = $MAX;
  for( $range->( $MAX + 1, $MAX + $extra ) ) {
    undef $@;
    eval { $$x = $_ };
    is( $$x, $MAX );
    is( ${$x->data}, pack($x->packcode, $MAX ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
  }
  done_testing();
};

subtest "$name->strict_input prevents overflow with characters" => sub {
  for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
    $$x = chr($_);
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  $$x = $MAX;
  for( $range->( $MAX + 1, $MAX + $extra ) ) {
    undef $@;
    $input = chr($_);
    eval { $$x = $input };
    is( $$x, $MAX );
    is( ${$x->data}, pack($x->packcode, $MAX ) );
    like( $@, qr/$name: character values must be integers $MIN <= ord\(x\) <= $MAX \(got .*\)/ );
  }
  done_testing();
};

subtest "$name->strict_input: multi-character error" => sub {
  $$x = 95;
  for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
    undef $@;
    $input = chr($_) . 'oubi';
    eval { $$x = $input };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    $like = $name . ': single characters only';
    # special regex characters cause problems, so escape them...
    substr( $like, ( index($like, 'oubi') - 1 ), 0, '\\' )
      if $input =~ qr{\^|\$|\.|\+|\*|\?|\(|\)|\[|\]|\\};
    like( $@, qr/$like/ );
  }
  for( $range->( $MAX + 1, $MAX + $extra ) ) {
    undef $@;
    $input = chr($_) . 'oubi';
    eval { $$x = $input };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    $like = $name . ': single characters only, and must be integers ' . $MIN . ' <= ord\(x\) <= ' . $MAX;
    substr( $like, ( index($like, 'oubi') - 1 ), 0, '\\' )
      if $input =~ qr{\^|\$|\.|\+|\*|\?|\(|\)|\[|\]|\\};
    like( $@, qr/$like/ );
  }
  done_testing();
};

$x->strict_input(0);
Ctypes::Type::strict_input_all(1);

subtest "$name: strict_input_all prevents dropping decimal places" => sub {
  plan tests => 9;
  $$x = 95;
  undef $@;
  eval { $$x = 100.2 };
  is( $$x, 95 );
  is( ${$x->data}, pack($x->packcode, 95 ) );
  like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.2\)/ );
  undef $@;
  eval { $$x = 100.5 };
  is( $$x, 95 );
  is( ${$x->data}, pack($x->packcode, 95 ) );
  like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.5\)/ );
  undef $@;
  eval { $$x = 100.8 };
  is( $$x, 95 );
  is( ${$x->data}, pack($x->packcode, 95 ) );
  like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.8\)/ );
};

subtest "$name: strict_input_all prevents numeric overflow" => sub {
  $$x = 95;
  for( $range->( $MIN - $extra, $MIN - 1 ) ) {
    undef $@;
    eval{ $$x = $_ };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
  }
  for( $range->( $MIN, $MAX, $cover, $weight, $want_int ) ) {
    undef $@;
    eval { $$x = $_ };
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
    is( $@, '' );
  }
  $$x = $MAX;
  for( $range->( $MAX + 1, $MAX + $extra ) ) {
    undef $@;
    eval { $$x = $_ };
    is( $$x, $MAX );
    is( ${$x->data}, pack($x->packcode, $MAX ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
  }
  done_testing();
};

subtest "$name: strict_input_all prevents overflow with characters" => sub {
  for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
    $$x = chr($_);
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  $$x = $MAX;
  for( $range->( $MAX + 1, $MAX + $extra ) ) {
    undef $@;
    $input = chr($_);
    eval { $$x = $input };
    is( $$x, $MAX );
    is( ${$x->data}, pack($x->packcode, $MAX ) );
    like( $@, qr/$name: character values must be integers $MIN <= ord\(x\) <= $MAX \(got .*\)/ );
  }
  done_testing();
};

subtest "$name: strict_input_all: multi-character error" => sub {
  $$x = 95;
  for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
    undef $@;
    $input = chr($_) . 'oubi';
    eval { $$x = $input };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    $like = $name . ': single characters only';
    # special regex characters cause problems, so escape them...
    substr( $like, ( index($like, 'oubi') - 1 ), 0, '\\' )
      if $input =~ qr{\^|\$|\.|\+|\*|\?|\(|\)|\[|\]|\\};
    like( $@, qr/$like/ );
  }
  for( $range->( $MAX + 1, $MAX + $extra ) ) {
    undef $@;
    $input = chr($_) . 'oubi';
    eval { $$x = $input };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    $like = $name . ': single characters only, and must be integers ' . $MIN . ' <= ord\(x\) <= ' . $MAX;
    substr( $like, ( index($like, 'oubi') - 1 ), 0, '\\' )
      if $input =~ qr{\^|\$|\.|\+|\*|\?|\(|\)|\[|\]|\\};
    like( $@, qr/$like/ );
  }
  done_testing();
};
  
