#!perl

use strict;
use warnings;
no warnings 'pack';
use Config;

my $uchar_max = 2 ** 8 - 1;
print "char_max: $uchar_max\t";
my $unpacked_overflowed_char = unpack( 'C', pack( 'C', $uchar_max + 1 ) );
print "Overflowed char: $unpacked_overflowed_char\n";

my $ushort_max = 2 ** (8 * $Config{shortsize}) - 1;
print "short_max: $ushort_max\t";
my $unpacked_overflowed_short = unpack( 'S', pack( 'S', $ushort_max + 1 ) );
print "Overflowed short: $unpacked_overflowed_short\n";

my $uint_max = 2 ** (8 * $Config{intsize}) - 1;
print "int_max: $uint_max\t";
my $unpacked_overflowed_int = unpack( 'I', pack( 'I', $uint_max + 1 ) );
print "Overflowed int: $unpacked_overflowed_int\n";

my $ulong_max = 2 ** (8 * $Config{longsize}) - 1;
print "long_max: $ulong_max\t";
my $unpacked_overflowed_long = unpack( 'L', pack( 'L', $ulong_max + 1 ) );
print "Overflowed long: $unpacked_overflowed_long\n";

if( defined $Config{d_quad} ) {
  my $uquad_max = 2 ** (8 * 8) - 1;
  print "quad_max: $uquad_max\t";
  my $unpacked_overflowed_quad = unpack( 'Q', pack( 'Q', $uquad_max + 1 ) );
  print "Overflowed quad: $unpacked_overflowed_quad\n";
}
