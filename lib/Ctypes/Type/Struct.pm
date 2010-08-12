package Ctypes::Type::Struct;
use strict;
use warnings;
use Ctypes::Type;
# our @ISA = qw(Ctypes::Type);  # Nothing really In package Ctypes::Type

sub new {
  my ($class, $fields) = @_;
  my $size = 0;
  for (@$fields) { # arrayref of ctypes, or just arrayref of paramtypes
    # XXX convert fields to ctypes
    my $fsize = $_->{size};
    $size += $fsize;
    # TODO: align!!
  }
  return bless { fields => $fields, size => $size, address => 0 }, $class;
}

1;
