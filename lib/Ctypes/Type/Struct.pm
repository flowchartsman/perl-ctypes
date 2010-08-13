package Ctypes::Type::Struct;
use strict;
use warnings;
use Ctypes::Type;
use Carp;
use Data::Dumper;
our @ISA = qw|Ctypes::Type|;
my $Debug = 0;

sub new {
  my $class = ref($_[0]) || $_[0];     shift;
  my $args = { @_ };
  my $self = $class->SUPER::_new;
  print "In Struct::new constructor...\n" if $Debug == 1;
  print Dumper( $args ) if $Debug == 1;

# Try to determine if ::new was called by a class that inherits
# from Struct, and get the name of that class
  my $progeny = undef;
  my $caller = (caller(1))[3];
  print "    caller is ", $caller, "\n" if $caller and $Debug == 1;
  if( defined $caller and $caller =~ m/::/ ) {  # need check for eval()s
    $caller =~ s/::(.*)$//;
    if( $caller->isa('Ctypes::Type::Struct') ) {
      $progeny = $caller;
    }
  }

  croak( "Cannot instantiate ", ($progeny ? $progeny : 'Struct'),
         " class without _fields_!") unless $args->{_fields_};

  if( !$progeny ) {   # (probably) called as "new Struct( foo )"
    print "    Check for multiply defined fields...\n" if $Debug == 1;
    my %seenfields;
    for( 0..$#{$args->{_fields_}} ) {
      print "      Looking at ", Dumper($args->{_fields_}[$_]) if $Debug == 1;
      if( exists $seenfields{$args->{_fields_}[$_][0]} ) {
        croak( ($progeny ? $progeny : 'Struct'), " error: ",
           "field '", $args->{_fields_}[$_][0], "' defined more than once");
        return undef;
      }
      $seenfields{$args->{_fields_}[$_][0]} = 1;
    }
  }

  # Get fields, populate with named/unnamed args
  print "ARGS->FIELDS:\n" if $Debug == 1;
  print Dumper($args->{_fields_}) if $Debug == 1;
  print "VALUES:\n" if $Debug == 1;
  print Dumper($args->{values}) if $Debug == 1;
  if( ref($args->{values}[0]) eq 'HASH' ) { # instantiated with named args
    if( $args->{values}[0] ) {
    }
  } 
  $self->{_fields_list} = $args->{_fields_};
  for(0..$#{$args->{_fields_}}) {
    $self->{_fields_}{$args->{_fields_}[$_][0]} = $args->{_fields_}[$_][1];
  }

  if(ref($args->{values}[0]) eq 'HASH') { # instantiated with named args
    print "    Filling in Named args:\n" if $Debug == 1;
    for(keys(%{$args->{values}[0]}) ) {
      print "    Field: ", $_, "\n" if $Debug == 1;
      print "      Value: ", $args->{values}[0]{$_}, "\n" if $Debug == 1;
# From Py spec: no check on extant fields, new names create new ones
      $self->{_fields_}{$_} = $args->{values}[0]{$_};
    }
  } else {  # positional arguments
    print "    Filling in Positional args:\n" if $Debug == 1;
    for(0..$#{$args->{values}}) {
      print "    Field: ", $self->{_fields_list}[$_][0], "\n" if $Debug == 1;
      print "      Value: ", $args->{values}[$_], "\n" if $Debug == 1;
      $self->{_fields_}{ $self->{_fields_list}[$_][0] }
        = $args->{values}[$_];
    }
  }
  if( $#{$args->{values}} > length keys(%{$self->{_fields_}}) ) {
      croak( ($progeny ? $progeny : 'Struct'), " error: ",
        "Too many arguments for given fields!");
  }

  my $myclass = $class . ((scalar $self) =~ m/\(([x0-9a-fA-F]*)\)/ )[0];
  print "myclass is $myclass\n" if $Debug == 1;
  bless $self => $myclass;
  if( !$progeny ) {
  no strict 'refs';
  push @{$myclass::ISA}, 'Ctypes::Type::Struct';
  print "    My class is $myclass\n" if $Debug == 1;
  print "    It inherits from Struct\n" if $myclass->isa('Ctypes::Type::Struct') and $Debug == 1;
  print $myclass->isa('Ctypes::Type::Struct'), "\n";
  }
  _gen_fields_accessors($self,$progeny);

#  for (@$fields) { # arrayref of ctypes, or just arrayref of paramtypes
    # XXX convert fields to ctypes
#    my $fsize = $_->{size};
#    $size += $fsize;
    # TODO: align!!
  print "    Struct constructor returning:\n" if $Debug == 1;
  print Dumper( $self ) if $Debug == 1;
  return $self;
}

sub fields {
  print "In fields accessor!\n" if $Debug == 1;
  return $_[0]->{_fields_list};
}

#
# Generate _fields_ accessors
#
sub _gen_fields_accessors {
  my $self = shift;
  my $progeny = shift;
  print "In gen accessors\n" if $Debug == 1;
  print "    Have a subclass called $progeny\n" if $progeny and $Debug == 1;
  print Dumper($self->{_fields_}) if $Debug == 1;
  for my $key (keys(%{$self->{_fields_}})) {
    print "    Now we're on ", $self->{_fields_}{$key}, "\n" if $Debug == 1;
    my $name     = $key;
    my( $type, $default, $width ) = undef;
    for( 0..$#{$self->{_fields_list}}) {
      if($self->{_fields_list}[$_][0] = $name ) {
        $type    = $self->{_fields_list}[$_][1];
        $default = $self->{_fields_list}[$_][2];
        $width   = $self->{_fields_list}[$_][3];
      }
    }
    $self->{_fields_methods}->{$name} = sub {
      my $caller = shift;
      my $arg = shift;
      print "In $name accessor\n" if $Debug == 1;
      croak("Usage: $name( arg )") if @_;
      if( not defined $arg ) {
        if(ref($caller)) {
          return $caller->{_fields_}->{$name};
        } else {  # class method
          no strict 'refs';
          if( defined ${"${caller}::_fields_info{$name}"} ) {
            return  ${"${caller}::_fields_info{$name}"};
          } else {
            my $field;
            print "    Looking for field '$name'\n" if $Debug == 1;
            for( @${"${caller}::_fields_"} ) {
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
    if( $progeny ) {
      no strict 'refs';
      *{"${progeny}::$name"} = \&{$self->{_fields_methods}->{$name}};
    }
  }
}

sub AUTOLOAD {
  our $AUTOLOAD;
  if ( $AUTOLOAD =~ /.*::(.*)/ ) {
    return if $1 eq 'DESTROY';
    my $wantfield = $1;
    print "Trying to AUTOLOAD for $wantfield\n" if $Debug == 1;
    my $self = shift;
    my $found = 0;  
    no strict 'refs';
    my $class;
    foreach $class ( ($self->isa) ) {
      for( 0..$#{"${class}::_fields_"} ) {
        $found = 1 if ${"${class}::_fields_[$_][0]"} eq $wantfield;
      }
      last if $found == 1;
    }
    my $name = $wantfield;
    if( $found == 1 ) {
      my $func = sub {
        my $caller = shift;
        my $arg = shift;
        print "In $name accessor\n" if $Debug == 1;
        croak("Usage: $name( arg )") if @_;
        if( not defined $arg ) {
          if(ref($caller)) {
            return $caller->{_fields_}->{$name};
          } else {  # class method
            if( defined ${"${caller}::_fields_info{$name}"} ) {
              return  ${"${caller}::_fields_info{$name}"};
            } else {
              my $field;
              print "    Looking for field '$name'\n" if $Debug == 1;
              for( @${"${caller}::_fields_"} ) {
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
      *{"${class}::$wantfield"} = $func;
    }
  }
}


1;
