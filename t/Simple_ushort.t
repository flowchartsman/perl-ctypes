#!perl

use Test::More tests => 19;
use utf8;
BEGIN { use_ok( Ctypes ) }

my $x = c_ushort;
isa_ok( $x, 'Ctypes::Type::Simple' );
is( $x->typecode, 'H', 'Correct typecode' );
is( $x->sizecode, 'S', 'Correct sizecode' );
is( $x->packcode, 'S', 'Correct packcode' );
is( $x->name, 'c_ushort', 'Correct name' );

my $name = $x->name;
my $MAX = Ctypes::constant('PERL_USHORT_MAX');
my $MIN = Ctypes::constant('PERL_USHORT_MIN');
my $diff = $MAX - $MIN + 1;
my $extra = 100;
my( $input, $like );

subtest "$name will not accept references" => sub {
  plan tests => 3;
  $$x = 95;
  $@ = undef;
  eval{  $$x = [1, 2, 3] };
  is( $$x, 95 );
  is( unpack('b*',${$x->data}), unpack('b*', pack($x->packcode, 95)) );
  like( $@, qr/c_ushort: cannot take references \(got ARRAY.*\)/ );
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

subtest "$name: number overflow" => sub {
  for( ($MIN - $extra)..($MIN - 1) ) {
    next if $_ % 4;
    $$x = $_;
    is( $$x, $_ + $diff );
    is( ${$x->data}, pack($x->packcode, ($_ + $diff) ) );
  }
  for( $MIN..$MAX ) {
    next if $_ % 3;
    $$x = $_;
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  for( ($MAX + 1)..($MAX + $extra) ) {
    next if $_ % 4;
    $$x = $_;
    is( $$x, $_ - $diff );
    is( ${$x->data}, pack($x->packcode, ($_ - $diff) ) );
  }
  done_testing();
};

subtest "$name: character overflow" => sub {
  for( 0..$MAX ) {
    next if $_ % 3;
    $$x = chr($_);
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  for( ($MAX + 1)..($MAX + $extra) ) {
    next if $_ % 4;
    $$x = chr($_);
    is( $$x, ($_ - $diff) );
    is( ${$x->data}, pack($x->packcode, ($_ - $diff) ) );
  }
  done_testing();
};

subtest "$name: characters after first discarded" => sub {
  for( 0..$MAX ) {
    next if $_ % 3;
    $input = chr($_) . 'oubi';
    $$x = $input;
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  for( ($MAX + 1)..($MAX + $extra) ) {
    next if $_ % 4;
    $input = chr($_) . 'oubi';
    $$x = $input;
    is( $$x, ($_ - $diff) );
    is( ${$x->data}, pack($x->packcode, ($_ - $diff) ) );
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
  for( ($MIN - $extra)..($MIN - 1) ) {
    next if $_ % 4;
    undef $@;
    eval{ $$x = $_ };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
  }
  for( $MIN..$MAX ) {
    next if $_ % 3;
    undef $@;
    eval { $$x = $_ };
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
    is( $@, '' );
  }
  $$x = $MAX;
  for( ($MAX + 1)..($MAX + $extra) ) {
    next if $_ % 4;
    undef $@;
    eval { $$x = $_ };
    is( $$x, $MAX );
    is( ${$x->data}, pack($x->packcode, $MAX ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
  }
  done_testing();
};

subtest "$name->strict_input prevents overflow with characters" => sub {
  for( 0..$MAX ) {
    next if $_ % 3;
    $$x = chr($_);
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  $$x = $MAX;
  for( ($MAX + 1)..($MAX + $extra) ) {
    next if $_ % 4;
    undef $@;
    $input = chr($_);
    eval { $$x = $input };
    is( $$x, $MAX );
    is( ${$x->data}, pack($x->packcode, $MAX ) );
    like( $@, qr/$name: character values must be integers 0 <= ord\(x\) <= $MAX \(got $input\)/ );
  }
  done_testing();
};

subtest "$name->strict_input: multi-character error" => sub {
  $$x = 95;
  for( 0..$MAX ) {
    next if $_ % 3;
    undef $@;
    $input = chr($_) . 'oubi';
    eval { $$x = $input };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    $like = $name . ': single characters only \(got ' . $input . '\)';
    # special regex characters cause problems, so escape them...
    substr( $like, ( index($like, 'oubi') - 1 ), 0, '\\' )
      if $input =~ qr{\^|\$|\.|\+|\*|\?|\(|\)|\[|\]|\\};
    like( $@, qr/$like/ );
  }
  for( ($MAX + 1)..($MAX + $extra) ) {
    next if $_ % 3;
    undef $@;
    $input = chr($_) . 'oubi';
    eval { $$x = $input };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    $like = $name . ': single characters only, and must be integers 0 <= ord\(x\) <= ' . $MAX . ' \(got ' . $input . '\)';
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
  for( ($MIN - $extra)..($MIN - 1) ) {
    next if $_ % 4;
    undef $@;
    eval{ $$x = $_ };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
  }
  for( $MIN..$MAX ) {
    next if $_ % 3;
    undef $@;
    eval { $$x = $_ };
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
    is( $@, '' );
  }
  $$x = $MAX;
  for( ($MAX + 1)..($MAX + $extra) ) {
    next if $_ % 4;
    undef $@;
    eval { $$x = $_ };
    is( $$x, $MAX );
    is( ${$x->data}, pack($x->packcode, $MAX ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
  }
  done_testing();
};

subtest "$name: strict_input_all prevents overflow with characters" => sub {
  for( 0..$MAX ) {
    next if $_ % 3;
    undef $@;
    $$x = chr($_);
    is( $$x, $_ );
    is( ${$x->data}, pack($x->packcode, $_ ) );
  }
  $$x = $MAX;
  for( ($MAX + 1)..($MAX + $extra) ) {
    next if $_ % 4;
    undef $@;
    $input = chr($_);
    eval { $$x = $input };
    is( $$x, $MAX );
    is( ${$x->data}, pack($x->packcode, $MAX ) );
    like( $@, qr/$name: character values must be integers 0 <= ord\(x\) <= $MAX \(got $input\)/ );
  }
  done_testing();
};

subtest "$name: strict_input_all: multi-character error" => sub {
  $$x = 95;
  for( 0..$MAX ) {
    next if $_ % 3;
    undef $@;
    $input = chr($_) . 'oubi';
    eval { $$x = $input };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    my $like = $name . ': single characters only \(got ' . $input . '\)';
    # special regex characters cause problems, so escape them...
    substr( $like, ( index($like, 'oubi') - 1 ), 0, '\\' )
      if $input =~ qr{\$|\*|\?};
    like( $@, qr/$like/ );
  }
  for( ($MAX + 1)..($MAX + $extra) ) {
    next if $_ % 3;
    undef $@;
    $input = chr($_) . 'oubi';
    eval { $$x = $input };
    is( $$x, 95 );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    like( $@, qr/$name: single characters only, and must be integers 0 <= ord\(x\) <= $MAX \(got $input\)/ );
  }
  done_testing();
};

