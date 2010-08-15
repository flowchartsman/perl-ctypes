package Ctypes::Type::Struct;
use strict;
use warnings;
use Ctypes;
use Ctypes::Type::Field;
use Carp;
use Data::Dumper;
use overload 
  '${}'    => \&_scalar_overload,
  fallback => 'TRUE';

our @ISA = qw|Ctypes::Type|;
my $Debug = 0;

sub _hash_overload {
  return shift->_get_inner;
}

sub _scalar_overload {
  return \shift->contents;
}

############################################
# TYPE::STRUCT : PUBLIC FUNCTIONS & VALUES #
############################################

sub new {
  my $class = ref($_[0]) || $_[0];  shift;
  print "In Struct::new constructor...\n" if $Debug == 1;
  print "args:\n" if $Debug == 1;
  # Try to determine if ::new was called by a class that inherits
  # from Struct, and get the name of that class
  # XXX Later, the [non-]existence of $progeny is used to make an
  # educated guess at whether Struct was instantiated directly, or
  # via a subclass.
  # Q: What are some of the ways the following logic fails?
  my $progeny = undef;
  my $caller = (caller(1))[3];
  print "    caller is ", $caller, "\n" if $caller and $Debug == 1;
  if( defined $caller and $caller =~ m/::/ ) {  # need check for eval()s
    $caller =~ s/::(.*)$//;
    if( $caller->isa('Ctypes::Type::Struct') ) {
      $progeny = $caller;
    }
  }

  # What kind of input?
  my( $in_vals, $in_fields ) = [];
  if( ref($_[0]) eq 'HASH' ) {
    my $hashref = shift;
    # We only know about fields=> and values=>
    for my $key (keys(%{$hashref})) {
    croak(($progeny ? $progeny : 'Struct'), " error: unknown arg $key") 
      unless $key eq 'fields' or $key eq 'values';
    }
    $in_vals   = $hashref->{values} if exists $hashref->{values};
    $in_fields = $hashref->{fields} if exists $hashref->{fields};
    print "    in_vals:\n", Dumper( $in_vals ) if $Debug == 1;
    if( !$in_vals and @_ ) {  # So can specify fields in hashref
      $in_vals = [ @_ ];      # and still list values lazily afterwards,
    }                         # without having to name them all :)
  } else {
    print"    Vals are an Arrayref!\n" if $Debug == 1;
    $in_vals = [ @_ ];
  }

  if( !$progeny ) {   # (probably) called as "new Struct( foo )"
    print "    Check for multiply defined fields...\n" if $Debug == 1;
    my %seenfields;
    for( 0..$#{$in_fields} ) {
      print "      Looking at ", Dumper($in_fields->[$_]) if $Debug == 1;
      if( exists $seenfields{$in_fields->[$_][0]} ) {
        croak( "Struct error: ",
           "field '", $in_fields->[$_][0], "' defined more than once");
        return undef;
      }
      $seenfields{$in_fields->[$_][0]} = 1;
    }
  }

  # Get fields, populate with named/unnamed args
  my $self = { _fields     => undef,      # hashref, field data by name
               _fields_ord => undef,      # arrayref, order of fields
               _typecode_  => 'p'    };

  # format of _fields_ info: <name> <type> <default> <bitwidth>
  for( my $i=0; defined(local $_ = $in_fields->[$i]); $i++ ) {
    if( defined $_->[3] and $_->[1]->type ne 'i' ) {
      croak("Bit fields must be type c_int (you specified a bit width)");
    }
    print "    Assigning field ", $_->[0], "\n" if $Debug == 1;
    $self->{_fields}{ $_->[0] } =
      [ $_->[0], $_->[1], $_->[2] ];
    $self->{_fields}{$_->[0]}->[3] = $_->[3] if defined $_->[3];
    $self->{_fields_ord}->[$i] = $self->{_fields}{ $_->[0] };
  }

  if( ref($in_vals) eq 'HASH' ) { # Named arguments
    print "    Checking for unknown named attrs...\n" if $Debug == 1;
    for(keys(%$in_vals) ) {
      if( not exists $self->{_fields}{$_} ) {
        my $tc = Ctypes::_check_type_needed( $in_vals->{$_} );
        if( !ref($in_vals->{$_}) ) {
          $in_vals->{$_} = Ctypes::Type::Simple->new( $tc, $in_vals->{$_} );
        }
        $self->{_fields}{$_}
          = [ $_, Ctypes::Type::Simple->new($tc,0), undef ];
      }
      $self->{_fields_ord}->[ $#{$self->{_fields_ords}} + 1 ]
        = $self->{_fields}{$_};
    }
  } else {  # positional arguments
    if( $#$in_vals > $#{$self->{_fields_ord}} ) {
      print $#$in_vals, " in_vals and ", scalar @{$self->{_fields_ord}},
            " fields\n" if $Debug == 1;
      print Dumper($in_vals) if $Debug == 1;
      print Dumper($self->{_fields_ord}) if $Debug == 1;
      croak( ($progeny ? $progeny : 'Struct'), " error: ",
        "Too many positional arguments for fields!");
    }
  }

  bless $self => $class;
  my $base = $class->SUPER::_new;

  for(keys %$base) { $self->{$_} = $base->{$_} }
    print "    in_vals:\n", Dumper( $in_vals ) if $Debug == 1;

  # Set name. This could be hella long, but it's how we figure out if two
  # Structs in an array were of the same type, for example (until we work
  # out multiple inheritance of fields).
  $self->{_name} = '';
  print "    Making name...\n" if $Debug == 1;
  for( @{$self->{_fields_ord}} ) {
    if( !ref($_->[1]) ) {
      my $tc = Ctypes::_check_type_needed($_->[1]);
      $_->[1] = Ctypes::Type::Simple->new($tc, $_->[1]);
    }
    $self->{_name} .= $_->[1]->name . '_';
    $self->{_name} =~ s/c_//;
  }
  $self->{_name} .= '_Struct';

  $self->{_allow_new_fields} = 1;
  $self->{_size} = 0;
  $self->{_contents} = new Ctypes::Type::Struct::Fields($self);
  print "    Creating fields...\n" if $Debug == 1;
  for( @{$self->{_fields_ord}} ) {
    $self->{_contents}->add_field($_);
    $self->{_size} += $_->[1]->size;
  }
  print "    Assigning values...\n" if $Debug == 1;
    print "    in_vals:\n", Dumper( $in_vals ) if $Debug == 1;
  if( ref($in_vals) eq 'HASH' ) {
    for( @{$self->{_fields_ord}} ) {
      $in_vals->{ $_[0] }
        ? $self->{_contents}->set_value( $_->[0], $in_vals->{ $_->[0] } )
        : $self->{_contents}->set_value( $_->[0], $_->[1] );
    }
  } else {
    for( 0..$#{$self->{_fields_ord}} ) {
      if( defined $in_vals->[$_] ) {
        print "INTVALZIZ ", $in_vals->[$_], "\n" if $Debug == 1;
        print "going into field ", $self->{_fields_ord}->[$_][0], "\n" if $Debug == 1;
        $self->{_contents}->set_value(
          $self->{_fields_ord}->[$_][0], $in_vals->[$_] );
      } else {
        $self->{_contents}->set_value(
          $self->{_fields_ord}->[$_][0], $self->{_fields_ord}->[$_][1] );
      }
    }
  }
  $self->{_allow_new_fields} = 0;

#  for (@$fields) { # arrayref of ctypes, or just arrayref of paramtypes
    # XXX convert fields to ctypes
#    my $fsize = $_->{size};
#    $size += $fsize;
    # TODO: align!!
  print "    Struct constructor returning\n" if $Debug == 1;
  return $self;
}

sub _as_param_ { return $_[0]->_data(@_) }

sub _data { 
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
    for(@ordkeys) {
      print "    Calling Datasafe on ", $_, "\n" if $Debug == 1;
      if( defined $self->contents->raw->{$_}->contents ) {
        $self->contents->raw->{$_}->contents->_datasafe = 0;
        print "    He now knows his data's ", $self->contents->raw->{$_}->contents->_datasafe, "00% safe\n" if $Debug == 1;
      }
    }
    return \$self->{_data};
  }
# TODO This is where a check for an endianness property would come in.
  if( $self->{_endianness} ne 'b' ) {
    for(my $i=0;defined(local $_ = $ordkeys[$i]);$i++) {
      $data[$i] = ${$self->{contents}->{$ordkeys[$i]}->_data};
    }
    $self->{_data} = join('',@data);
    print "  ", $self->{_name}, "'s _data returning ok...\n" if $Debug == 1;
    $self->_datasafe = 0;
    for(@ordkeys) {
      print "    Calling Datasafe on ", $self->{_contents}->{$_}, "\n"; # if $Debug == 1;
      $self->{_contents}->{$_}->_datasafe = 0
    }
    return \$self->{_data};
  } else {
  # <insert code for other / swapped endianness here>
  }
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
    $self->{_data} = substr( ${$self->{_owner}->_data},
                             $self->{_index},
                             $self->{_size} );
    }
  } else {
    if( defined $index ) {
      my $pad = $index + length($arg) - length($self->{_data});
      if( $pad > 0 ) {
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
    for(keys %{$self->{_fields}}) {
      print ref($self->{_contents}->{_rawfields}->{$_}->{CONTENTS}), "\n" if $Debug == 1;
      $self->{_contents}->{_rawfields}->{$_}->{CONTENTS}->_datasafe = 0
        if defined $self->{_contents}->{_rawfields}->{$_}->{CONTENTS};
    }
  }
  print "  data NOW looks like:\n", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
  print "    ", $self->{_name}, "'s _Update_ returning ok\n" if $Debug == 1;
  return 1;
}

#
# Accessor generation
#
my %access = ( 
  typecode        => ['_typecode_'],
  type              => ['_typecode_'],
  allow_overflow    =>
    [ '_allow_overflow',
      sub {if( $_[0] == 1 or $_[0] == 0){return 1;}else{return 0;} },
      1 ], # <--- makes this settable
  alignment         => ['_alignment'],
  name              => ['_name'],
  size              => ['_size'],
  fields            => ['_fields'],
  field_list        => ['_fields_ord'],
  contents          => ['_contents'],
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

sub AUTOLOAD {
  our $AUTOLOAD;
  if ( $AUTOLOAD =~ /.*::(.*)/ ) {
    return if $1 eq 'DESTROY';
    my $wantfield = $1;
    print "Trying to AUTOLOAD for $wantfield in STRUCT\n" if $Debug == 1;
    my $self = $_[0];
    my $found = 0;
    if( exists $self->fields->{$wantfield} ) {
      $found = 1;
    }
    my $name = $wantfield;
    $found ? print "    Found it!\n" : print "    Didnt find it\n" if $Debug == 1;
    if( $found == 1 ) {
      my $func = sub {
        my $caller = shift;
        my $arg = shift;
        print "In $name accessor\n" if $Debug == 1;
        croak("Usage: $name( arg )") if @_;
        if( not defined $arg ) {
          if(ref($caller)) {
            print "    Returning value...\n" if $Debug == 1;
            my $ret = $caller->{_contents}->{_rawfields}->{$name};
            if( ref($ret) eq 'Ctypes::Type::Simple' ) {
              return ${$ret};
            } else {
              return $ret;
            }
          } else {  # class method
            if( defined ${"${caller}::_fields_info{$name}"} ) {
              return  ${"${caller}::_fields_info{$name}"};
            } else {
              my $field;
              print "    Looking for field '$name'\n" if $Debug == 1;
              for( $self->field_list ) {
                $field = $_ if $_[0] = $name;
              }
              my $info = {
                     name => $name,
                     type => $field->[1]->_typecode_,
                     size => $field->[1]->size,
                     ofs  => 0,                       # XXX
                   };
               ${"${caller}::_fields_info{$name}"} = $info;
              return $info;
            }
          }
        } else {
        }
      };
      no strict 'refs';
      *{"Ctypes::Type::Struct::$wantfield"} = $func;
      goto &{"Ctypes::Type::Struct::$wantfield"};
    }
  }
}

package Ctypes::Type::Struct::Fields;
use warnings;
use strict;
use Ctypes;
use Carp;
use Data::Dumper;

sub new {
  my $class = ref($_[0]) || $_[0];  shift;
  my $owner = shift;
  return bless {
                 _owner     => $owner,
                 _fields    => {},
                 _rawfields => {},
               } => $class;
}

sub owner { return $_[0]->{_owner} }

sub add_field {
  my $self = shift;
  my $field = shift;
  print "IN ADD FIELD\n" if $Debug == 1;
  print "    offset will be ", $self->owner->size, "\n" if $Debug == 1;
  $self->{_rawfields}->{$_->[0]} = 
    tie $self->{_fields}->{$_->[0]},
      'Ctypes::Type::Field',
      $_->[0],
      $_->[1],
      $self->owner->size,
      $self->owner;
}

sub set_value {
  my( $self, $key, $val ) = @_;
  $self->{_fields}->{$key} = $val;
  return 1;
}

sub raw { return $_[0]->{_rawfields} }

sub AUTOLOAD {
  our $AUTOLOAD;
  if ( $AUTOLOAD =~ /.*::(.*)/ ) {
    return if $1 eq 'DESTROY';
    my $wantfield = $1;
    print "Trying to AUTOLOAD for $wantfield in FieldSS\n" if $Debug == 1;
    my $self = $_[0];
    my $found = 0;
    if( exists $self->owner->fields->{$wantfield} ) {
      $found = 1;
    }
    my $name = $wantfield;
    $found ? print "    Found it!\n" : print "    Didnt find it\n" if $Debug == 1;
    if( $found == 1 ) {
      my $owner = $self->owner;
      my $func = sub {
        my $caller = shift;
        my $arg = shift;
        print "In $name accessor\n" if $Debug == 1;
        croak("Usage: $name( arg )") if @_;
        if( not defined $arg ) {
          if(ref($caller)) {
            print "    Returning value...\n" if $Debug == 1;
            print Dumper( $self->{_fields}->{$name} ) if $Debug == 1;
            my $ret = $self->{_fields}->{$name};
            if( ref($ret) eq 'Ctypes::Type::Simple' ) {
              return ${$ret};
            } else {
              return $ret;
            }
          } else {  # class method
            if( defined ${"${owner}::_fields_info{$name}"} ) {
              return  ${"${owner}::_fields_info{$name}"};
            } else {
              my $field;
              print "    Looking for field '$name'\n" if $Debug == 1;
              for( $owner->field_list ) {
                $field = $_ if $_[0] = $name;
              }
              my $info = {
                     name => $name,
                     type => $field->[1]->_typecode_,
                     size => $field->[1]->size,
                     ofs  => 0,                       # XXX
                   };
               ${"${owner}::_fields_info{$name}"} = $info;
              return $info;
            }
          }
        } else {
        }
      };
      no strict 'refs';
      *{"Ctypes::Type::Struct::Fields::$wantfield"} = $func;
      goto &{"Ctypes::Type::Struct::Fields::$wantfield"};
    }
  }
}

1;
