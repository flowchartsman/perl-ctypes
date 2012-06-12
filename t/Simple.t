#!perl

use Test::More;
use Carp;
BEGIN { use_ok( Ctypes ) }


#
# Takes a hash of properties of Simple types
# and tests them.
#
sub SimpleTest {
  my $typehash = shift;
  croak( "One at a time please" ) if @_;

  ok( defined $typehash, "OK!" );

  # Required arguments

  croak( "instantiator required" ) unless defined $typehash->{instantiator};
  my $instantiator = $typehash->{instantiator};

  croak( "packcode required" ) unless defined $typehash->{packcode};
  my $packcode = $typehash->{packcode};

  croak( "sizecode required" ) unless defined $typehash->{sizecode};
  my $sizecode = $typehash->{sizecode};

  croak( "typecode required" ) unless defined $typehash->{typecode};
  my $typecode = $typehash->{typecode};

  croak( "name required" ) unless defined $typehash->{name};
  my $name = $typehash->{name};

  croak( "MAX required" ) unless defined $typehash->{MAX};
  my $MAX = $typehash->{MAX};

  croak( "MIN required" ) unless defined $typehash->{MIN};
  my $MIN = $typehash->{MIN};

  # Optional arguments

  my $extra = $typehash->{extra} or 100;
  my $weight = $typehash->{weight} or 1;
  my $cover = $typehash->{cover} or 100;
  my $want_int = $typehash->{want_int} or 1;


  # Is the type signed or unsigned?
  # (Matters for overflow)

  my( $is_signed, $is_unsigned );
  $is_signed = 1 if exists $typehash->{is_signed};
  $is_unsigned = 1 if exists $typehash->{is_unsigned};
  croak( "Types cannot be both signed and unsigned" )
    if $is_signed && $is_unsigned;

  # What does this type return?

  my( $ret_input, $ret_char, $ret_num,
      $is_float, $is_integer );

  $ret_input = 1 if exists $typehash->{ret_input};
  $ret_char = 1 if exists $typehash->{ret_char};
  $ret_num = 1 if exists $typehash->{ret_num};

  my $ret_total =
    $ret_input ? 1 : 0 +
    $ret_char  ? 1 : 0 +
    $ret_num   ? 1 : 0;

  croak( "Only one default return type (numeric, character, or as-input)" )
    if $ret_total > 1;

  $ret_num = 1 if $ret_total < 1;
  diag "ret_num: $ret_num" if $Ctypes::Type::Simple::Debug;
  diag "ret_char: $ret_char" if $Ctypes::Type::Simple::Debug;
  diag "ret_input: $ret_input" if $Ctypes::Type::Simple::Debug;

  $is_integer = 1 if exists $typehash->{is_integer};
  $is_float = 1 if exists $typehash->{is_float};
  croak( "Types cannot be both integer and float" )
    if $is_integer && $is_float;

  $is_integer = 1 unless $is_float;
  diag "is integer: $is_integer\n" if $Ctypes::Type::Simple::Debug;
  diag "is float: $is_float\n" if $Ctypes::Type::Simple::Debug;

  my $get_return = sub {
    my $input = shift;
    if( $ret_input ) {
      if( Ctypes::Type::is_a_number($input) ){
        if( $is_integer ) {
          return int( $input );
        } else {
          return $input;
        }
      } else {
        return substr($input, 0, 1);
      }
    }
    if( $ret_char ) {
      if( Ctypes::Type::is_a_number($input) ){
        return chr($input);
      } else {
        diag "O HAI\n" if $Ctypes::Type::Simple::Debug;
        return substr($input, 0, 1);
      }
    }
    if( $ret_num ) {
      if( Ctypes::Type::is_a_number($input) ) {
        return $input;
      } else {
        return ord( substr($input, 0, 1) );
      }
    }
  };


  my $x;
  my $diff = $MAX - $MIN + 1;
  my ( $input, $like );
  my $range = \&Ctypes::Util::create_range;

  {
    no strict 'refs';
    $x = &$instantiator;  # 'c_int()', etc
  }

  $x->strict_input(0);
  Ctypes::Type::strict_input_all(0);

  isa_ok( $x, 'Ctypes::Type::Simple' );
  is( $x->typecode, $typecode, 'Correct typecode' );
  is( $x->sizecode, $sizecode, 'Correct sizecode' );
  is( $x->packcode, $packcode, 'Correct packcode' );
  is( $x->name, $name, 'Correct name' );

  subtest "$name will not accept references" => sub {
    plan tests => 3;
    $input = 95;
    $$x = $input;
    eval{  $$x = [1, 2, 3] };
    is( $$x, $get_return->($input) );
    is( unpack('b*',${$x->data}), unpack('b*', pack($x->packcode, $input)) );
    like( $@, qr/$name: cannot take references \(got ARRAY.*\)/ );
  };

  subtest "$name drops numbers after decimal point" => sub {
    plan tests => 4;
    $input = 95.2;
    $$x = $input;
    is( $$x, $get_return->($input) );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    $input = 95.8;
    $$x = $input;
    is( $$x, $get_return->($input) );
    is( ${$x->data}, pack($x->packcode, 95 ) );
  };

  # Exceeding range on _signed_ variables is undefined in the standard,
  # so these tests can't really be any better.
  subtest "$name: number overflow" => sub {
    if( $is_signed ) {
      for( $range->( $MIN - $extra, $MIN - 1 ) ) {
        $$x = $_;
        isnt( $$x, $get_return->($_) );
        ok( $$x >= $MIN );
      }
      for( $range->( $MIN, $MAX, $cover, $weight, $want_int ) ) {
        $$x = $_;
        is( $$x, $get_return->($_) );
        is( ${$x->data}, pack($x->packcode, $_ ) );
      }
      for( $range->( $MAX + 1, $MAX + $extra ) ) {
        $$x = $_;
        isnt( $$x, $get_return->($_) );
        ok( $$x <= $MAX );
      }
      done_testing();
    } elsif( $is_unsigned ) {
      TODO: {
        local $todo =
          "pack() seems to be wrapping signed overflows unpredictably";

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
    }
  };

  if ($ret_char) {
    subtest "$name: character overflow" => sub {
      for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
	$input = chr($_);
	$$x = $input;
	is( $$x, $get_return->($input) );
	is( ${$x->data}, pack($x->packcode, $_ ) );
      }
      for( $range->( $MAX + 1, $MAX + $extra) ) {
	$input = chr($_);
	$$x = $input;
	isnt( $$x, $get_return->($input) );
	ok( $$x <= $MAX );
      }
      done_testing();
    };

    subtest "$name: characters after first discarded" => sub {
      for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
	$input = chr($_) . 'oubi';
	$$x = $input;
	is( $$x, $get_return->($input) );
	is( ${$x->data}, pack($x->packcode, $_ ) );
      }
      done_testing();
    };
  }

  $x->strict_input(1);

  subtest "$name->strict_input prevents dropping decimal places" => sub {
    plan tests => 6;
    $input = 95;
    $$x = $input;
    undef $@;
    eval { $$x = 100.2 };
    is( $$x, $get_return->(95) );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.2\)/ );
    undef $@;
    eval { $$x = 100.8 };
    is( $$x, $get_return->(95) );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.8\)/ );
  };

  subtest "$name->strict_input prevents numeric overflow" => sub {
    $$x = 95;
    for( $range->( $MIN - $extra, $MIN - 1 ) ) {
      undef $@;
      eval{ $$x = $_ };
      is( $$x, $get_return->(95) );
      is( ${$x->data}, pack($x->packcode, 95 ) );
      like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
    }
    for( $range->( $MIN, $MAX, $cover, $weight, $want_int ) ) {
      undef $@;
      eval { $$x = $_ };
      is( $$x, $get_return->($_) );
      is( ${$x->data}, pack($x->packcode, $_ ) );
      is( $@, '' );
    }
    $$x = $MAX;
    for( $range->( $MAX + 1, $MAX + $extra ) ) {
      undef $@;
      eval { $$x = $_ };
      is( $$x, $get_return->($MAX) );
      is( ${$x->data}, pack($x->packcode, $MAX ) );
      like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
    }
    done_testing();
  };

  subtest "$name->strict_input prevents overflow with characters" => sub {
    for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
      $input = chr($_);
      print "Input: ", $input, "\n";
      $$x = $input;
      is( $$x, $get_return->($input) );
      is( ${$x->data}, pack($x->packcode, $_ ) );
    }
    $$x = $MAX;
    for( $range->( $MAX + 1, $MAX + $extra ) ) {
      undef $@;
      $input = chr($_);
      eval { $$x = $input };
      is( $$x, $get_return->($MAX) );
      is( ${$x->data}, pack($x->packcode, $MAX ) );
      like( $@, qr/$name: character values must be integers 0 <= ord\(x\) <= $MAX \(got .*\)/ );
    }
    done_testing();
  };

  subtest "$name->strict_input: multi-character error" => sub {
    $$x = 95;
    for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
      undef $@;
      $input = chr($_) . 'oubi';
      eval { $$x = $input };
      is( $$x, $get_return->(95) );
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
      is( $$x, $get_return->(95) );
      is( ${$x->data}, pack($x->packcode, 95 ) );
      $like = $name . ': single characters only, and must be integers 0 <= ord\(x\) <= ' . $MAX;
      substr( $like, ( index($like, 'oubi') - 1 ), 0, '\\' )
        if $input =~ qr{\^|\$|\.|\+|\*|\?|\(|\)|\[|\]|\\};
      like( $@, qr/$like/ );
    }
    done_testing();
  };

  $x->strict_input(0);
  Ctypes::Type::strict_input_all(1);

  subtest "$name: strict_input_all prevents dropping decimal places" => sub {
    plan tests => 6;
    $$x = 95;
    undef $@;
    eval { $$x = 100.2 };
    is( $$x, $get_return->(95) );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.2\)/ );
    undef $@;
    eval { $$x = 100.8 };
    is( $$x, $get_return->(95) );
    is( ${$x->data}, pack($x->packcode, 95 ) );
    like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got 100\.8\)/ );
  };

  subtest "$name: strict_input_all prevents numeric overflow" => sub {
    $$x = 95;
    for( $range->( $MIN - $extra, $MIN - 1 ) ) {
      undef $@;
      eval{ $$x = $_ };
      is( $$x, $get_return->(95) );
      is( ${$x->data}, pack($x->packcode, 95 ) );
      like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
    }
    for( $range->( $MIN, $MAX, $cover, $weight, $want_int ) ) {
      undef $@;
      eval { $$x = $_ };
      is( $$x, $get_return->($_) );
      is( ${$x->data}, pack($x->packcode, $_ ) );
      is( $@, '' );
    }
    $$x = $MAX;
    for( $range->( $MAX + 1, $MAX + $extra ) ) {
      undef $@;
      eval { $$x = $_ };
      is( $$x, $get_return->($MAX) );
      is( ${$x->data}, pack($x->packcode, $MAX ) );
      like( $@, qr/$name: numeric values must be integers $MIN <= x <= $MAX \(got $_\)/ );
    }
    done_testing();
  };

  subtest "$name: strict_input_all prevents overflow with characters" => sub {
    for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
      $input = chr($_);
      $$x = $input;
      is( $$x, $get_return->($input) );
      is( ${$x->data}, pack($x->packcode, $_ ) );
    }
    $$x = $MAX;
    for( $range->( $MAX + 1, $MAX + $extra ) ) {
      undef $@;
      $input = chr($_);
      eval { $$x = $input };
      is( $$x, $get_return->($MAX) );
      is( ${$x->data}, pack($x->packcode, $MAX ) );
      like( $@, qr/$name: character values must be integers 0 <= ord\(x\) <= $MAX \(got .*\)/ );
    }
    done_testing();
  };

  subtest "$name: strict_input_all: multi-character error" => sub {
    $$x = 95;
    for( $range->( 0, $MAX, $cover, $weight, $want_int ) ) {
      undef $@;
      $input = chr($_) . 'oubi';
      eval { $$x = $input };
      is( $$x, $get_return->(95) );
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
      is( $$x, $get_return->(95) );
      is( ${$x->data}, pack($x->packcode, 95 ) );
      $like = $name . ': single characters only, and must be integers 0 <= ord\(x\) <= ' . $MAX;
      substr( $like, ( index($like, 'oubi') - 1 ), 0, '\\' )
        if $input =~ qr{\^|\$|\.|\+|\*|\?|\(|\)|\[|\]|\\};
      like( $@, qr/$like/ );
    }
    done_testing();
  };

}

my $types = {
  c_byte => {
    instantiator => 'c_byte',
    packcode     => 'c',
    sizecode     => 'c',
    typecode     => 'b',
    name         => 'c_byte',
    MAX          => 127,
    MIN          => -128,

    ret_input    => 1,
    is_signed    => 1,
    extra        => 128,
            },
#    c_ubyte => {
#      instantiator => 'c_ubyte',
#      packcode     => 'C',
#      sizecode     => 'C',
#      typecode     => 'B',
#      name         => 'c_ubyte',
#      MAX          => 255,
#      MIN          => 0,
#  
#      ret_input    => 1,
#      is_unsigned  => 1,
#      extra        => 256,
#    },
#    c_char => {
#      instantiator => 'c_char',
#      packcode     => 'c',
#      sizecode     => 'c',
#      typecode     => 'c',
#      name         => 'c_char',
#      MAX          => 127,
#      MIN          => -128,
#  
#      ret_char     => 1,
#      is_signed    => 1,
#      extra        => 128,
#    },
};

SimpleTest($_) for values %$types;

done_testing();
