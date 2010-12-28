#!/usr/lib/perl -w

use strict;
use warnings;

use Test::More;

use Ctypes;

my $ushort_max = Ctypes::constant('PERL_USHORT_MAX');
my $uchar_max = Ctypes::constant('PERL_UCHAR_MAX');
my $uint_max = Ctypes::constant('PERL_UINT_MAX');

my $ushort = c_ushort;
my $uchar = c_uchar;
my $uint = c_uint;

$$ushort = $ushort_max;
$$uchar = $uchar_max;
$$uint = $uint_max;

is( $$ushort, $ushort_max, "ushort is $ushort_max" );
is( ord($$uchar), $uchar_max, "uchar is $uchar_max" );
is( $$uint, $uint_max, "uint is $uint_max" );

$DB::single = 1;
$$ushort++;
print $$ushort, "\n";
$$ushort++;
print $$ushort, "\n";
$$ushort++;
print $$ushort, "\n";

$DB::single = 1;
$$uchar++;
print ord($$uchar), "\n";
$$uchar++;
print ord($$uchar), "\n";
$$uchar++;
print ord($$uchar), "\n";

$DB::single = 1;
$$uint++;
print $$uint, "\n";
$$uint++;
print $$uint, "\n";
$$uint++;
print $$uint, "\n";

done_testing();
