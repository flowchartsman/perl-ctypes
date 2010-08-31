package Ctypes::Type::Struct;
use strict;
use warnings;
use Scalar::Util qw|blessed looks_like_number|;
use Ctypes;
use Ctypes::Type::Field;
use Carp;
use Data::Dumper;
use overload 
  '${}'    => \&_scalar_overload,
  fallback => 'TRUE';

our @ISA = qw|Ctypes::Type|;
my $Debug = 0;

=head1 NAME

Ctypes::Type::Struct - C Structures

=head1 SYNOPSIS

  use Ctypes;

  my 

=head1 ABSTRACT

=cut

sub _process_fields {
  my $self = shift;
  my $fields = shift;
  if( ref($fields) ne 'ARRAY' ) {
    croak( 'Usage: $struct->_process_fields( ARRAYREF )' );
  }
  if( scalar @$fields % 2 ) {
    croak( "Fields must be given as key => value pairs!" );
  }
  my( $key, $val );
  for( 0 .. (( $#$fields - 1 ) / 2) ) {
    $key = shift @{$fields};
    $val = shift @{$fields};
    $self->{_fields}->_add_field($key, $val);
  }
}

sub _scalar_overload {
  return \$_[0]->{_fields};
}

############################################
# TYPE::STRUCT : PUBLIC FUNCTIONS & VALUES #
############################################

sub new {
  my $class = ref($_[0]) || $_[0];  shift;
  print "In Struct::new constructor...\n" if $Debug == 1;
  print "    args:\n" if $Debug == 1;
  # Try to determine if ::new was called by a class that inherits
  # from Struct, and get the name of that class
  # XXX Later, the [non-]existence of $progeny is used to make an
  # educated guess at whether Struct was instantiated directly, or
  # via a subclass.
  # Q: What are some of the ways the following logic fails?
  my( $progeny, $extra_fields ) = undef;
  my $caller = caller;
  print "    caller is ", $caller, "\n" if $caller and $Debug == 1;
  if( $caller->isa('Ctypes::Type::Struct') ) {
    no strict 'refs';
    $progeny = $caller;
    if( defined ${"${caller}::_fields_"} ) {
      my $_fields_ = ${"${caller}::_fields_"};
      for( 0..$#$_fields_ ) {
      # Can't just set = as shift() extra_fields later affects every instance
        if( blessed( $_fields_->[$_] )
            and $_fields_->[$_]->isa('Ctypes::Type') ) {
          $extra_fields->[$_] = $_fields_->[$_]->copy;
        } else {
          $extra_fields->[$_] = $_fields_->[$_];
        }
      }
      print "    Got these extra fields:\n" if $Debug == 1;
      print Dumper( $extra_fields ) if $Debug == 1;
      if( scalar @$extra_fields % 2 ) {
        croak( "_fields_ must be key => value pairs!" );
      }
    }
  }

  # Get fields, populate with named/unnamed args
  my $self = { _fields     => {},
               _typecode_  => 'p',
               _subclass   => $progeny,
               _alignment  => 0,
               _data       => '', };
  $self->{_fields} = new Ctypes::Type::Struct::_Fields($self);
  bless $self => $class;
  my $base = $class->SUPER::_new;
  for( keys(%$base) ) {
    $self->{$_} = $base->{$_};
  }
  $self->{_name} = $progeny ? $progeny . '_Struct' : 'Struct';

  print "    \$self now looks like this:\n" if $Debug == 1;
  print Dumper( $self ) if $Debug == 1;

  if( $extra_fields ) {
    my( $key, $val );
    for( 0 .. (( $#$extra_fields - 1 ) / 2) ) {
      $key = shift @{$extra_fields};
      $val = shift @{$extra_fields};
      print "    Adding extra field '$key'...\n" if $Debug == 1;
      $self->{_fields}->_add_field( $key, $val );
    }
  }

  my $in = undef;
  if( ref($_[0]) eq 'HASH' ) {
    $in = shift;
    if( exists $in->{align} ) {
      if( $in->{align} !~ /^2$|^4$|^8$|^16$|^32$|^64$/ ) {
        croak( '\'align\' parameter must be 2, 4, 8, 16, 32 or 64' );
      }
      $self->{_alignment} = $in->{align};
      print "    My alignment is now ", $self->{_alignment}, "\n" if $Debug == 1;
      delete $in->{align};
    }
    if( exists $in->{fields} ) {
      $self->_process_fields($in->{fields});
      delete $in->{fields};
    }
  } elsif( ref($_[0]) eq 'ARRAY' ) {
    $in = shift;
    $self->_process_fields($in);
  } else {
    if( !$progeny
        or scalar @{$self->{_fields}} == 0 ) {
      croak( "Don't know what to do with args without fields" );
    }
    for( @{$self->{_fields}} ) {
      $_ = shift;
    }
  }

  print "    Struct constructor returning\n" if $Debug == 1;
  return $self;
}

sub _as_param_ { return $_[0]->data(@_) }

=item copy

Return a copy of the Struct object.

=cut

sub copy {
  my $self = shift;
}

sub data { 
  my $self = shift;
  print "In ", $self->{_name}, "'s _DATA(), from ", join(", ",(caller(1))[0..3]), "\n" if $Debug == 1;
  my @data;
  my @ordkeys;
#  print "    Fields are:\n" if $Debug == 1;
#  for( 0..$#{$self->{_fields}} ) {
#    print "      field $_: ", $self->{_fields}->[$_], "\n" if $Debug == 1;
#  }
  if( defined $self->{_data}
      and $self->{_datasafe} == 1 ) {
    print "    _data already defined and safe\n" if $Debug == 1;
    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
    return \$self->{_data};
  }
# TODO This is where a check for an endianness property would come in.
#  if( $self->{_endianness} ne 'b' ) {
    for(@{$self->{_fields}->{_rawarray}}) {
      push @data, $_->{_data};
    }
    $self->{_data} = join('',@data);
    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
    print "  ", $self->{_name}, "'s _data returning ok...\n" if $Debug == 1;
    $self->_datasafe(0);
    return \$self->{_data};
#  } else {
  # <insert code for other / swapped endianness here>
#  }
}

sub _update_ {
  my($self, $arg, $index) = @_;
  print "In ", $self->{_name}, "'s _UPDATE_, from ", join(", ",(caller(0))[0..3]), "\n" if $Debug == 1;
  print "  self is: ", $self, "\n" if $Debug == 1;
  print "  current data looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
  print "  arg is: $arg" if $arg and $Debug == 1;
  print $arg ? (",  which is\n", unpack('b*',$arg), "\n  to you and me\n") : ('') if $Debug == 1;
  print "  and index is: $index\n" if defined $index and $Debug == 1;
  if( not defined $arg ) {
    print "    Arg wasn't defined!\n" if $Debug == 1;
    if( $self->{_owner} ) {
    print "      Getting data from owner...\n" if $Debug == 1;
    $self->{_data} = substr( ${$self->{_owner}->data},
                             $self->{_index},
                             $self->{_size} );
    }
  } else {
    if( defined $index ) {
      print "     Got an index...\n" if $Debug == 1;
      my $pad = $index + length($arg) - length($self->{_data});
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
  print "    ", $self->{_name}, "'s _Update_ returning ok\n" if $Debug == 1;
  return 1;
}

#
# Accessor generation
#
my %access = ( 
  typecode      => ['_typecode_'],
  align         => ['_alignment'],
  alignment     => ['_alignment'],
  name          => ['_name'],
  size          => ['_size'],
  fields        => ['_fields'],
             );
for my $func (keys(%access)) {
  no strict 'refs';
  my $key = $access{$func}[0];
  *$func = sub {
    my $self = shift;
    my $arg = shift;
#    print "In $func accessor\n" if $Debug == 1;
    croak("The $key method only takes one argument") if @_;
    if($access{$func}[1] and defined($arg)){
      eval{ $access{$func}[1]->($arg); };
      if( $@ ) {
        croak("Invalid argument for $key method: $@");
      }
    }
    if($access{$func}[2] and defined($arg)) {
      $self->{$key} = $arg;
    }
#    print "    $func returning $key...\n" if $Debug == 1;
    return $self->{$key};
  }
}

sub _datasafe {
  my( $self, $arg ) = @_;
  if( defined $arg and $arg != 1 and $arg != 0 ) {
    croak("Usage: ->_datasafe(1 or 0)")
  }
  if( defined $arg and $arg == 0 ) {
    $self->_set_owned_unsafe;
  }
  $self->{_datasafe} = $arg if defined $arg;
  return $self->{_datasafe};
}

sub _set_owned_unsafe {
  my $self = shift;
  print "Setting _owned_unsafe\n" if $Debug == 1;
  for( @{$self->{_fields}->{_rawarray}} ) {
#    print "    Setting owned obj ", $_, "'s datasafe = 0\n" if $Debug == 1;
    $_->_datasafe(0);
    print "    He now knows his data's ", $_->_datasafe, "00% safe\n" if $Debug == 1;
  }
  return 1;
}

package Ctypes::Type::Struct::_Fields;
use warnings;
use strict;
use Carp;
use Data::Dumper;
use Scalar::Util qw|blessed looks_like_number|;
use overload
  '@{}'    => \&_array_overload,
  '%{}'    => \&_hash_overload,
  fallback => 'TRUE';
use Ctypes;

sub _array_overload {
#  print "In _Fields' _array_overload\n" if $Debug == 1;
  return $_[0]->{_array};
}

sub _hash_overload {
#  print "In _Fields' _hash_overload\n" if $Debug == 1;
  if( caller =~ /^Ctypes::Type::Struct/ ) {
#    print "    Called from self, returning self...\n" if $Debug == 1;
    return $_[0];
  }
#  print for (@_);
  my( $self, $key ) = ( shift, shift );
  my $class = ref($self);
  bless $self => 'overload::dummy';
  my $ret = $self->{_hash};
  bless $self => $class;
  return $ret;
}

sub new {
  my $class = ref($_[0]) || $_[0];  shift;
  my $obj = shift;
  my $self = {
                _obj         => $obj,
                _hash        => {},
                _rawhash     => undef,
                _array       => [],
                _rawarray    => undef,
                _size        => 0,
                _allowchange => 1,
                _finder      => undef,
              };
  $self->{_rawhash} = tie %{$self->{_hash}},
                      'Ctypes::Type::Struct::_Fields::_hash';
  $self->{_rawarray} = tie @{$self->{_array}},
                      'Ctypes::Type::Struct::_Fields::_array';
  bless $self => $class;
#  $self->{_finder} = new Ctypes::Type::Struct::_Fields::_Finder($self);
  return $self;
}

sub _add_field {
  my( $self, $key, $val ) = ( shift, shift, shift );
  print "In ", $self->{_obj}->{_name}, "'s _add_field(), from ", join(", ",(caller(1))[0..3]), "\n" if $Debug == 1;
  if( blessed($val) ) {
    if( $val->isa('Ctypes::Type') ) {
      $val = $val->copy;
    } else {
      croak( "Fields must be initialised with a Ctypes Type" );
    }
  } else {
    if( looks_like_number($val) ) {
      my $tc = Ctypes::_check_type_needed( $val );
      $val = new Ctypes::Type::Simple( $tc, $val );
    } else {
      croak( "Fields must be initialised with a Ctypes Type" );
    }
  }
  print "    key is $key\n" if $Debug == 1;
  print "    value is $$val\n" if $Debug == 1;
  my $offset = undef;
  $DB::single = 1;
  if( not exists $self->{_rawhash}->{$key} ) {
    print "    Key didn't exist, adding...\n" if $Debug == 1;
    $offset = 0;
    my $newfieldindex = 0;
    if( scalar @{$self->{_array}} > 0 ) {
      print "    Already stuff in array\n" if $Debug == 1;
      my $lastindex = $#{$self->{_rawarray}};
      my $align = $self->{_obj}->{_alignment};
      $align = 1 if $align == 0;
      $offset = $self->{_rawarray}->[$lastindex]->index
                + $self->{_rawarray}->[$lastindex]->size;
      print "    alignment is $align\n" if $Debug == 1;
      my $offoff = abs( $offset - $align ) % $align;
      if( $offoff ) { # how much the 'off'set is 'off' by.
        print "  offoff was $offoff off!\n" if $Debug == 1;
        $offset += $offoff;
      }
      $newfieldindex = $#{$self->{_array}} + 1;
    }
    print "    offset will be ", $offset, "\n" if $Debug == 1;
    print "    setting array...\n" if $Debug == 1;
    $self->{_rawarray}->[$newfieldindex] = $val;
  } else {
    $offset = $self->{_rawhash}->{$key}->index;
  }
  my $datum = ${$val->data};
  print $datum ? ("    datum is\n", unpack('b*',$datum), "\n") : ('') if $Debug == 1;
  print "    setting hash...\n" if $Debug == 1;
  $self->{_rawhash}->{$key} = $val;
  print "    setting index $offset...\n" if $Debug == 1;
  $self->{_rawhash}->{$key}->_set_index($offset);
  print "  offset is ", $self->{_rawhash}->{$key}->index, "\n" if $Debug == 1;
  print "    setting owner...\n" if $Debug == 1;
  $self->{_rawhash}->{$key}->_set_owner($self->{_obj});
  $self->{_obj}->_update_( $datum, $offset );
  print "  val is still ", $$val, "\n" if $Debug == 1;
#  print "  self->hash->key is ", $self->{_hash}->{$key}, "\n" if $Debug == 1;
  $self->{_obj}->{_size} = length($self->{_obj}->{_data});
  print "    _ADD_FIELD returning!\n" if $Debug == 1;
  return $self->{_rawhash}->{$key};
}

#  sub _add_field {
#    my $self = shift;
#    my $key = shift;
#    my $val = shift;
#    print "In ", $self->{_obj}->{_name}, "'s _add_field(), from ", join(", ",(caller(1))[0..3]), "\n" if $Debug == 1;
#    if( blessed($val) ) {
#      if( $val->isa('Ctypes::Type') ) {
#        $val = $val->copy;
#      } else {
#        croak( "Fields must be initialised with a Ctypes Type" );
#      }
#    } else {
#      if( looks_like_number($val) ) {
#        my $tc = Ctypes::_check_type_needed( $val );
#        $val = new Ctypes::Type::Simple( $tc, $val );
#      } else {
#        croak( "Fields must be initialised with a Ctypes Type" );
#      }
#    }
#    print "    key is $key\n" if $Debug == 1;
#    print "    value is $$val\n" if $Debug == 1;
#    my $offset = undef;
#        $DB::single = 1;
#    if( not exists $self->{_rawhash}->{$key} ) {
#      print "    Key didn't exist, adding...\n" if $Debug == 1;
#      $offset = 0;
#      my $newfieldindex = 0;
#      if( scalar @{$self->{_array}} > 0 ) {
#        print "    Already stuff in array\n" if $Debug == 1;
#        my $lastindex = $#{$self->{_rawarray}};
#        my $align = $self->{_obj}->{_alignment};
#        $align = 1 if $align == 0;
#        $offset = $self->{_rawarray}->[$lastindex]->index
#                  + $self->{_rawarray}->[$lastindex]->size;
#        print "    offset is $offset\n" if $Debug == 1;
#        print "    alignment is $align\n" if $Debug == 1;
#        my $offoff = abs( $offset - $align ) % $align;
#        if( $offoff ) { # how much the 'off'set is 'off' by.
#          print "  offoff was $offoff off!\n" if $Debug == 1;
#          $offset += $offoff;
#        }
#        $newfieldindex = $#{$self->{_array}} + 1;
#      }
#      print "    offset will be ", $offset, "\n" if $Debug == 1;
#      print "    setting array...\n" if $Debug == 1;
#      $self->{_rawarray}->[$newfieldindex] = $val;
#    } else {
#      $offset = $self->{_rawhash}->{$key}->index;
#    }
#    my $datum = ${$val->data};
#    print $datum ? ("    datum is\n", unpack('b*',$datum), "\n") : ('') if $Debug == 1;
#    print "    setting hash...\n" if $Debug == 1;
#    $self->{_rawhash}->{$key} = $val;
#    print "    setting index $offset...\n" if $Debug == 1;
#    $self->{_rawhash}->{$key}->_set_index($offset);
#    print "  offset is ", $self->{_rawhash}->{$key}->index, "\n" if $Debug == 1;
#    print "    setting owner...\n" if $Debug == 1;
#    $self->{_rawhash}->{$key}->_set_owner($self->{_obj});
#    $self->{_obj}->_update_( $datum, $offset );
#    print "  val is still ", $$val, "\n" if $Debug == 1;
#  #  print "  self->hash->key is ", $self->{_hash}->{$key}, "\n" if $Debug == 1;
#    $self->{_obj}->{_size} = length($self->{_obj}->{_data});
#    print "    _ADD_FIELD returning!\n" if $Debug == 1;
#    return $self->{_rawhash}->{$key};
#  }

package Ctypes::Type::Struct::_Fields::_array;
use warnings;
use strict;
use Carp;
use Tie::Array;
use Scalar::Util qw|blessed|;
use Ctypes;
use Data::Dumper;
our @ISA = 'Tie::StdArray';

sub STORE {
  my $self = shift;
  my $index = shift;
  my $val = shift;
  print "In _Fields::_array::STORE\n" if $Debug == 1;
  print "    index is $index\n" if $Debug == 1;
  print "    val is $val\n" if $Debug == 1;
  if( not exists $self->[$index] ) {
    croak( "There is no field at position '$index'" );
  } else {
    if( blessed($self->[$index])
        and $self->[$index]->isa('Ctypes::Type::Simple') ) {
      ${$self->[$index]} = $val;
    } else {
      $self->[$index] = $val;
    }
  }
  print "    returning ", $self->[$index], "\n" if $Debug == 1;
  return $self->[$index];
}

sub FETCH {
  if( blessed($_[0]->[$_[1]])
    and $_[0]->[$_[1]]->isa('Ctypes::Type::Simple') ) {
    return ${$_[0]->[$_[1]]};
  } else {
    return $_[0]->[$_[1]];
  }
}

package Ctypes::Type::Struct::_Fields::_hash;
use warnings;
use strict;
use Tie::Hash;
use Scalar::Util qw|blessed|;
use Ctypes;
use Carp;
use Data::Dumper;
our @ISA = 'Tie::StdHash';

#  sub TIEHASH {
#    my $class = ref($_[0]) || $_[0];  shift;
#    my $obj = shift;
#    my $self = {
#                  _obj         => $obj,
#                  _hash        => {},
#                  _array       => [],
#                  _size        => 0,
#                  _allowchange => 1,
#                  _finder      => undef,
#                };
#    bless $self => $class;
#    $self->{_finder} = new Ctypes::Type::Struct::_Fields::_Finder($self);
#    return bless \{} => shift;
#  }

sub STORE {
  my $self = shift;
  my $key = shift;
  my $val = shift;
  print "In _Fields::_hash::STORE\n" if $Debug == 1;
  print "    key is $key\n" if $Debug == 1;
  print "    val is $val\n" if $Debug == 1;
  if( not exists $self->{$key} ) {
    croak( "Field '$key' does not exist" );
  } else {
    if( $self->{$key}->isa('Ctypes::Type::Simple') ) {
      ${$self->{$key}} = $val;
    } else {
      $self->{$key} = $val;
    }
  }
  print "    returning ", $self->{$key}, "\n" if $Debug == 1;
  return $self->{$key};
}

sub FETCH {
  print "In _hash::FETCH, from ", join(", ",(caller(1))[0..3]), "\n" if $Debug == 1;
  if( blessed($_[0]->{$_[1]})
    and $_[0]->{$_[1]}->isa('Ctypes::Type::Simple') ) {
    return ${$_[0]->{$_[1]}};
  } else {
    return $_[0]->{$_[1]};
  }
}


package Ctypes::Type::Struct::_Fields::_Finder;
use warnings;
use strict;
use Ctypes;
use Carp;
use Data::Dumper;

sub new {
  if( caller ne 'Ctypes::Type::Struct::_Fields' ) {
    our $AUTOLOAD = '_Finder::new';
    shift->AUTOLOAD;
  }
  my $class = shift;
  my $fields = shift;
  return bless [ $fields ] => $class;
}

sub AUTOLOAD {
  our $AUTOLOAD;
  print "In _Finder::AUTOLOAD\n" if $Debug == 1;
  print "    AUTOLOAD is $AUTOLOAD\n" if $Debug == 1;
  if ( $AUTOLOAD =~ /.*::(.*)/ ) {
    return if $1 eq 'DESTROY';
    my $wantfield = $1;
    print "     Trying to AUTOLOAD for $wantfield\n" if $Debug == 1;
    my $self = $_[0];
    my $instance = $self->[0]->{_obj};
    if( defined $instance->{_subclass}
        and $instance->can($wantfield) ) {
      no strict 'refs';
      goto &{$self->[0]->{_obj}->can($wantfield)};
    }
    my $found = 0;
    if( exists $self->[0]->{_hash}->{$wantfield} ) {
      $found = 1;
      print "    Found it!\n" if $Debug == 1;
      my $object = $self->[0]->{_obj};
      my $func = sub {
        my $caller = shift;
        my $arg = shift;
        print "In $wantfield accessor\n" if $Debug == 1;
        croak("Too many arguments") if @_;
        if( not defined $arg ) {
          if(ref($caller)) {
            print "    Returning value...\n" if $Debug == 1;
            my $ret = $self->[0]->{_hash}->{$wantfield};
            if( ref($ret) eq 'Ctypes::Type::Simple' ) {
              return ${$ret};
            } elsif( ref($ret) eq 'Ctypes::Type::Array') {
              return ${$ret};
            } else {
              return $ret;
            }
          } else {
            # class method?
            # or should that be done in Type::Struct?
          }
        } else {
        }
      };
      if( defined( my $subclass = $self->[0]->{_obj}->{_subclass} ) ) {
        no strict 'refs';
        *{"${subclass}::$wantfield"} = $func;
        goto &{"${subclass}::$wantfield"};
      }
    } else { # didn't find field
      print "    Didn't find it\n" if $Debug == 1;
      print "    Here's what we had:\n" if $Debug == 1;
      print Dumper( $self->[0]->{_hash} ) if $Debug == 1;
      print Dumper( $self->[0]->{_array} ) if $Debug == 1;
      croak( "Couldn't find field '$wantfield' in ",
        $self->[0]->{_obj}->name );
    }
  }  # if ( $AUTOLOAD =~ /.*::(.*)/ )
}

1;
