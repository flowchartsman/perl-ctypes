package Ctypes::Type::Union;
use strict;
use warnings;
use Ctypes;
use base qw|Ctypes::Type::Struct|;

use Carp;
use Data::Dumper;

my $Debug = 0;

###########################################
# TYPE::UNION : PUBLIC FUNCTIONS & VALUES #
###########################################

sub new {
  my $class = ref($_[0]) || $_[0];  shift;
  print "In Union::new constructor...\n" if $Debug == 1;
  my $self = $class->SUPER::new(@_);
  print "    Hash returned\n" if $Debug == 1;

  print "    Getting biggest size\n" if $Debug == 1;
  my $thissize = 0;
  my $biggest = 0;
  for( keys %{$self->fields} ) {
    print "  Looking at field $_\n" if $Debug == 1;
    $thissize = $self->fields->{$_}->size;
    print "  it's $thissize bytes long\n" if $Debug == 1;
    $biggest = $thissize if $thissize > $biggest;
  }
  $self->_set_size($biggest);
  print "  Biggest field was size $biggest\n" if $Debug == 1;

  my $newname = $self->name;
  $newname =~ s/Struct$/Union/;
  $self->_set_name($newname);

  # ??? Will this be ok or need to explicitly undef all?
  for( keys %{$self->fields} ) {
    if( defined $self->fields->{$_} ) {
    $self->fields->{$_}->_datasafe(0);
    $self->fields->{$_}->_set_owner($self);
    }
  }

  # WHICH MEMber is currently valid.
  $self->{_whichmem} = undef;

  print "    Union constructor returning\n" if $Debug == 1;
  return $self;
}

sub is_set {
  return $_[0]->{_whichmem};
}

sub _set_whichmem {
  $_[0]->{_whichmem} = $_[1] if defined $_[1]; return $_[0]->{_whichmem};
}

sub _as_param_ { return $_[0]->data(@_) }

sub data { 
  my $self = shift;
  print "In ", $self->{_name}, "'s _DATA(), from ", join(", ",(caller(1))[0..3]), "\n" if $Debug == 1;
  my @data;
  my @ordkeys;
  for( 0..$#{$self->{_fields_ord}} ) {
    $ordkeys[$_] = $self->{_fields_ord}[$_][0];
   print "    ordkeys[$_]: ", $ordkeys[$_], "\n" if $Debug == 1;
  }
  if( defined $self->{_data}
      and $self->{_datasafe} == 1 ) {
    print "    _data already defined and safe\n" if $Debug == 1;
    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
    $self->_datasafe(0);
    return \$self->{_data};
  }
# TODO This is where a check for an endianness property would come in.
  if( $self->{_endianness} ne 'b' ) {
    my $rawcontents = $self->{_contents}->{_rawfields};
    for(my $i=0;defined(local $_ = $ordkeys[$i]);$i++) {
      $data[$i] = $rawcontents->{$ordkeys[$i]}->{CONTENTS}->{_data};
    }
    $self->{_data} = join('',@data);
    print "  ", $self->{_name}, "'s _data returning ok...\n" if $Debug == 1;
    $self->_datasafe(0);
    return \$self->{_data};
  } else {
  # <insert code for other / swapped endianness here>
  }
}

sub _update_ {
  my($self, $arg, $index) = @_;
  print "In ", $self->name, "'s _UPDATE_, from ", join(", ",(caller(0))[0..3]), "\n" if $Debug == 1;
  print "  self is: ", $self, "\n" if $Debug == 1;
  print "  current data looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
  print "  arg is: $arg" if $arg and $Debug == 1;
  print $arg ? (",  which is\n", unpack('b*',$arg), "\n  to you and me\n") : ('') if $Debug == 1;
  print "  and index is: $index\n" if defined $index and $Debug == 1;
  if( not defined $arg ) {
    print "    Arg wasn't defined!\n" if $Debug == 1;
    if( $self->{_owner} ) {
    print "      Getting data from owner...\n" if $Debug == 1;
    $self->{_data} = substr( ${$self->owner->data},
                             $self->index,
                             $self->size );
    }
  } else {
    if( defined $index ) {
      print "     Got an index...\n" if $Debug == 1;
      my $pad = $index + length($arg) - length(${$self->data});
      if( $pad > 0 ) {
        print "    pad was $pad\n" if $Debug == 1;
        $self->{_data} .= "\0" x $pad;
      }
      print "    Setting chunk of self->data\n" if $Debug == 1;
      substr( $self->{_data},
              $index,
              length($arg)
            ) = $arg;
    } else {
      $self->{_data} = $arg; # if data given with no index, replaces all
    }
  }

  # Have to send all data upstream even if only 1 member updated
  # ... or do we? Send our _index, plus #bytes updated member starts at?
  # Could C::B::C help with this???
  if( defined $arg and $self->{_owner} ) {
  print "    Need to update my owner...\n" if $Debug == 1;
  my $success = undef;
  print "  Sending data back upstream:\n" if $arg and $Debug == 1;
  print "    Index is ", $self->{_index}, "\n" if $arg and $Debug == 1;
    $success =
      $self->{_owner}->_update_(
        $self->{_data},
        $self->{_index}
      );
    if(!$success) {
      croak($self->{_name},
            ": Error updating member in owner object ",
              $self->{_owner}->{_name});
    }
  }
  $self->{_datasafe} = 1;
  if( defined $arg or $self->{_owner} ) { # otherwise nothing's changed
    $self->_set_owned_unsafe;
  }
  print "  data NOW looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
  print "    updating size...\n" if $Debug == 1;
  $self->{_size} = length($self->{_data});
  print "    ", $self->{_name}, "'s _Update_ returning ok\n" if $Debug == 1;
  return 1;
}

#  
#  package Ctypes::Type::Union::Fields;
#  use warnings;
#  use strict;
#  use Ctypes;
#  use Carp;
#  use Data::Dumper;
#  
#  sub new {
#    my $class = ref($_[0]) || $_[0];  shift;
#    my $owner = shift;
#    return bless {
#                   _owner     => $owner,
#                   _fields    => {},
#                   _rawfields => {},
#                 } => $class;
#  }
#  
#  sub owner { return $_[0]->{_owner} }
#  
#  sub add_field {
#    my $self = shift;
#    my $field = shift;
#    print "IN ADD FIELD\n" if $Debug == 1;
#    print "    offset will be ", $self->owner->size, "\n" if $Debug == 1;
#    $self->{_rawfields}->{$_->[0]} = 
#      tie $self->{_fields}->{$_->[0]},
#        'Ctypes::Type::Field',
#        $_->[0],
#        $_->[1],
#        $self->owner->size,
#        $self->owner;
#  }
#  
#  sub set_value {
#    my( $self, $key, $val ) = @_;
#    $self->{_fields}->{$key} = $val;
#    return 1;
#  }
#  
#  sub raw { return $_[0]->{_rawfields} }
#  
#  sub AUTOLOAD {
#    our $AUTOLOAD;
#    if ( $AUTOLOAD =~ /.*::(.*)/ ) {
#      return if $1 eq 'DESTROY';
#      my $wantfield = $1;
#      print "Trying to AUTOLOAD for $wantfield in FieldSS\n" if $Debug == 1;
#      my $self = $_[0];
#      my $found = 0;
#      if( exists $self->owner->fields->{$wantfield} ) {
#        $found = 1;
#      }
#      my $name = $wantfield;
#      $found ? print "    Found it!\n" : print "    Didnt find it\n" if $Debug == 1;
#      if( $found == 1 ) {
#        my $owner = $self->owner;
#        my $func = sub {
#          my $caller = shift;
#          my $arg = shift;
#          print "In $name accessor\n" if $Debug == 1;
#          croak("Usage: $name( arg )") if @_;
#          if( not defined $arg ) {
#            if(ref($caller)) {
#              print "    Returning value...\n" if $Debug == 1;
#              print Dumper( $self->{_fields}->{$name} ) if $Debug == 1;
#              my $ret = $self->{_fields}->{$name};
#              if( ref($ret) eq 'Ctypes::Type::Simple' ) {
#                return ${$ret};
#              } elsif( ref($ret) eq 'Ctypes::Type::Array') {
#                return ${$ret};
#              } else {
#                return $ret;
#              }
#            } else {  # class method
#              if( defined ${"${owner}::_fields_info{$name}"} ) {
#                return  ${"${owner}::_fields_info{$name}"};
#              } else {
#                my $field;
#                print "    Looking for field '$name'\n" if $Debug == 1;
#                for( $owner->field_list ) {
#                  $field = $_ if $_[0] = $name;
#                }
#                my $info = {
#                       name => $name,
#                       type => $field->[1]->_typecode_,
#                       size => $field->[1]->size,
#                       ofs  => 0,                       # XXX
#                     };
#                 ${"${owner}::_fields_info{$name}"} = $info;
#                return $info;
#              }
#            }
#          } else {
#          }
#        };
#        no strict 'refs';
#        *{"Ctypes::Type::Union::Fields::$wantfield"} = $func;
#        goto &{"Ctypes::Type::Union::Fields::$wantfield"};
#      }
#    }
#  }

1;
