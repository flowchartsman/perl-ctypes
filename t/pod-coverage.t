use strict;
use warnings;
use Test::More;
plan tests => 4;

# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage"
    if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

my $opts = { trustme => [ qr/^c_[a-z_]*$/,    # all private methods
                          qr/^PF_.*/,         # inlined flags, Function.pm
                          # (XXX will expose to users in a different format later) 
                          qr/^constant$/,     # Auto-generated
                          qr/^data$/,         # doc'd in Type, skip in children
                        ] };
# all_pod_coverage_ok($opts);
pod_coverage_ok( 'Ctypes', $opts );
pod_coverage_ok( 'Ctypes::Type', $opts );
pod_coverage_ok( 'Ctypes::Type::Simple', $opts );
# pod_coverage_ok( 'Ctypes::Type::Struct', $opts );
# pod_coverage_ok( 'Ctypes::Type::Pointer', $opts );
pod_coverage_ok( 'Ctypes::Type::Array', $opts );
