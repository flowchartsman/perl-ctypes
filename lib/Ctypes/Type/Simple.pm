package Ctypes::Type::Simple;
use strict;
use warnings;
use Carp;
use Ctypes;
use Ctypes::Type qw|&_types &allow_overflow_all|;
our @ISA = qw|Ctypes::Type|;
use fields qw|alignment name _typecode size
              allow_overflow val _as_param_|;
use overload '${}' => \&_scalar_overload,
             '0+'  => \&_scalar_overload,
             '""'  => \&_scalar_overload,
             '&{}' => \&_code_overload,
             fallback => 'TRUE';
       # TODO Multiplication will have to be overridden
       # to implement Python's Array contruction with "type * x"???
my $Debug = 0;

=head1 NAME

Ctypes::Type::Simple - The atomic C data types

=head1 SYNOPSIS

    use Ctypes;         # standard c_<type> funcs imported

    my $int = c_int;    # defaults to value 0
    $$c_int++;
    $$c_int += 5;

    my $double = c_double(200000);   # etc...

=head1 ABSTRACT

All the basic C data types are represented by Ctypes::Type::Simple
objects. Their constructors are abstracted through the main Ctypes
module, so you'll rarely want to call Simple->new directly.

=head1 DESCRIPTION

=over

=item c_X<lt>typeX<gt>(x)

=back

The basic Ctypes::Type objects are almost always created with the
correspondingly named functions exported by default from Ctypes.
All basic types are objects of type Ctypes::Type::Simple. You could
call the class constructor directly if you liked, passing a typecode
as the first argument followed by any initialisers, but the named
functions put in the appropriate typecode for you and are normally
more convenient.

A Ctypes::Type object represents a variable of a certain C type. If
uninitialised, the value defaults to zero. Uninitialized instances
are often used as parameters for constructing compound objects.

After creation, you can manipulate the value stored in a Type object
in any of the following ways:

=over

=item $$int = 100;

=item $int->(100);

=item $int->value(100);

=item $int->value = 100;

=back

The 'double-sigil' shown first is perhaps the most convenient, despite
looking a bit unusual. In general, the convention to remember in
Ctypes is that you use B<two> sigils to talk about the B<value> you're
representing, and B<one> sigil to talk about the object you're
representing it with. So $$int returns the value which would be
passed to C, while $int can be used to find out things about the object
itself, like C<$int->name>, C<$int->size>, etc.

In addition to the methods provided by Ctypes::Type, Ctypes::Type::Simple
objects provide the following extra methods.

=cut

sub _num_overload { return shift->{_value}; }

sub _add_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{_value} + $y; }
    else { $ret = $y->{_value} + $x; }
  } else {           # += etc.
    $x->{_value} = $x->{_value} + $y;
    $ret = $x;
  }
  return $ret;
}

sub _subtract_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{_value} - $y; }
    else { $ret = $x - $y->{_value}; }
  } else {           # -= etc.
    $x->{_value} = $x->{_value} - $y;
    $ret = $x;
  }
  return $ret;
}

sub _scalar_overload {
  my $self = shift;
  return \$self->{_value};
}

sub _code_overload {
  my $self = shift;
  return sub { $self->{_value} = $_[0] }
}


=over

=item new TYPECODE, ARG

=item new TYPECODE

The Ctypes::Type::Simple constructor. See the main L<Ctypes|Ctypes/call>
module for an explanation of typecodes. ARG is the optional
initialiser for your Type. Try to make it something sensible. Numbers
and characters usually go down well.

=cut

sub new {
  my $class = ref($_[0]) || $_[0]; shift;
  my $typecode = shift;
  my $arg = shift;
  print "In Type::Simple constructor, typecode [ $typecode ]", $arg ? "arg [ $arg ]" : '', "\n" if $Debug == 1;
  croak("Ctypes::Type::Simple error: Need typecode!") if not defined $typecode;
  my $self = $class->SUPER::_new;
  my $attrs = { 
    _typecode        => $typecode,
    _name            => Ctypes::Type::_types()->{$typecode},
    _allow_overflow  => 1,
              };
  for(keys(%{$attrs})) { $self->{$_} = $attrs->{$_}; };
  bless $self => $class;
  $self->{_size} = Ctypes::sizeof($typecode);
  $arg = 0 unless defined $arg;
  $self->{_rawvalue} = tie $self->{_value}, 'Ctypes::Type::Simple::value', $self;
  $self->{_value} = $arg;
  return undef if not defined $self->{_rawvalue}{VALUE};
  return $self;
}


=item allow_overflow

Mutator setting and/or returning a flag (1 or 0) indicating whether
this particular object is allowed to overflow. Defaults to 1, allowing
overflowing, as in C, but you'll get a warning about it. Note that even
if C<allow_overflow> is set to 1 for a particular object, overflows
will be prevented if C<allow_overflow_all> is set to 0. See the
L<allow_overflow_all|Ctypes::Type/allow_overflow_all> class method in
L<Ctypes::Type>.

=cut

sub allow_overflow {
    my $self = shift;
    my $arg = shift;
    if( @_  or ( defined $arg and $arg != 1 and $arg != 0 ) ) {
      croak("Usage: allow_overflow(1 or 0)");
    }
    $self->{_allow_overflow} = $arg if defined $arg;
    $self->{_allow_overflow};
}

=item copy

Return a copy of the object.

=cut

sub copy {
  print "In Simple::copy\n" if $Debug == 1;
  my $value = $_[0]->value;
  print "    Value is $value\n" if $Debug == 1;
  return Ctypes::Type::Simple->new( $_[0]->typecode, $value );
}

=item value EXPR

=item value

Accessor / mutator for the value of the variable the object
represents. C<value> is an lvalue method, so you can assign to it
directly (all the appropriate type checking will still be done).

=back

=cut

sub value : lvalue {
  $_[0]->{_value} = $_[1] if defined $_[1];
  $_[0]->{_value};
}

=head1 SEE ALSO

L<Ctypes>

=cut

sub data { 
  my $self = shift;
  print "In ", $self->{_name}, "'s _DATA_, from ", join(", ",(caller(0))[0..3]), "\n" if $Debug == 1;
  if( defined $self->owner
      or $self->_datasafe == 0 ) {
    print "    Can't trust data, updating...\n" if $Debug == 1;
    $self->_update_;
  }
  if( defined $self->{_data}
      and $self->{_datasafe} == 1 ) {
    print "    asparam already defined\n" if $Debug == 1;
    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
    return \$self->{_data};
  }
  $self->{_data} =
    pack( $self->{_typecode}, $self->{_rawvalue}{VALUE} );
  print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug == 1;
  $self->{_datasafe} = 0;  # used by FETCH
  return \$self->{_data};
}

sub _as_param_ { &data(@_) }

sub _update_ {
  my( $self, $arg ) = @_;
  print "In ", $self->{_name}, "'s _UPDATE_...\n" if $Debug == 1;
  print "    I am pwnd by ", $self->{_owner}->{_name}, "\n" if $self->{_owner} and $Debug == 1;
  if( not defined $arg ) {
    if( $self->{_owner} ) {
      print "    Have owner, getting updated data...\n" if $Debug == 1; 
      my $owners_data = ${$self->{_owner}->data};
      print "    Here's where I think I am in my pwner's data:\n" if $Debug == 1;
      print " " x ($self->{_index} * 8), "v\n" if $Debug == 1;
      print "12345678" x length($owners_data), "\n" if $Debug == 1;
      print unpack('b*', $owners_data), "\n" if $Debug == 1;
      print "    My index is ", $self->{_index}, "\n" if $Debug == 1;
      print "    My size is ", $self->{_size}, "\n" if $Debug == 1;
      $self->{_data} = substr( ${$self->{_owner}->data},
                               $self->{_index},
                               $self->{_size} );
      print "    My data is now:\n    ", unpack('b*', $self->{_data}), "\n" if $Debug == 1;
    }
  } else {
    $self->{_data} = $arg if $arg;
    if( $self->owner ) {
      $self->owner->_update_($self->{_data},$self->{_index});
    }
  }
  $self->{_rawvalue}{VALUE} = unpack($self->{_typecode},$self->{_data});
  print "    VALUE is _update_d to ", $self->{_rawvalue}{VALUE}, "\n" if $Debug == 1;
  $self->{_datasafe} = 1;
  return 1; 
}

sub _set_undef { $_[0]->{_value} = 0 }

package Ctypes::Type::Simple::value;
use strict;
use warnings;
use Carp;

sub TIESCALAR {
  my $class = shift;
  my $object = shift;
  my $self = { object  => $object,
               VALUE   => undef,
             };
  return bless $self => $class;
}

sub STORE {
  croak("STORE must take a value") if scalar @_ != 2;
  my $self = shift;
  my $arg = shift;
  print "In ", $self->{object}{_name}, "'s STORE with arg [ $arg ],\n" if $Debug == 1;
  print "    called from ", (caller(1))[0..3], "\n" if $Debug == 1;
  croak("Simple Types can only be assigned a single value") if @_;
  # Deal with being assigned other Type objects and the like...
  if(my $ref = ref($arg)) {
    if($ref =~ /^Ctypes::Type::/) {
      $arg = $arg->{_data};
    } else {
      if($arg->can("_as_param_")) {
        $arg = $arg->_as_param_;
      } elsif($arg->{_data}) {
        $arg = $arg->{_data};
      } else {
  # ??? Would you ever want to store an object/reference as the value
  # of a type? What would get pack()ed in the end?
        croak("Ctypes Types can only be made from native types or " . 
              "Ctypes compatible objects");
      }
    }
  }

  # Object's Value set to undef: {_val} becomes undef, {_data} filled
  # with null (i.e. numeric zero) , update owners, return early.
  if( not defined $arg ) {
    print "    Assigned undef! All goes null!\n" if $Debug == 1;
    $self->{VALUE} = 0;
    $self->{object}{_data} = "\0" x 8 x $self->{object}{_size}; # stay right length
    if( $self->{object}{_owner} ) {
      $self->{object}{_owner}->_update_($self->{object}{_data}, $self->{object}{_index});
    }
    return $self->{VALUE};
  }

  my $typecode = $self->{object}{_typecode};
  print "    Using typecode $typecode\n" if $Debug == 1;
  print "    arg is $arg\n" if $Debug == 1;
  # return 1 on success, 0 on fail, -1 if (numeric but) out of range
  my $is_valid = Ctypes::_valid_for_type($arg,$typecode);
  print "    _valid_for_type returned $is_valid\n" if $Debug == 1;
  if( $is_valid < 1 ) {
    no strict 'refs';
    if( ($is_valid == -1)
        and ( $self->{object}->allow_overflow == 0
        or Ctypes::Type::allow_overflow_all() == 0 ) ) {
      carp( "Value out of range for " . $self->{object}{_name} . ": $arg");
      return undef;
    } else {
      my $temp = Ctypes::_cast($arg,$typecode);
      print "    _cast returned: ", $temp, "\n" if $Debug == 1;
      if( $temp && Ctypes::_valid_for_type($temp,$typecode) ) {
        $arg = $temp;
      } else {
        carp("Unreconcilable argument for type " . $self->{object}{_name} .
              ": $arg");
        return undef;
      }
    }
  }
  $self->{VALUE} = $arg;
  $self->{object}{_data} =
    pack( $self->{object}{_typecode}, $arg );
  if( $self->{object}{_owner} ) {
    print "    Have owner, updating...\n" if $Debug == 1;
    $self->{object}{_owner}->_update_($self->{object}{_data}, $self->{object}{_index});
  }
  print "  Returning ok...\n" if $Debug == 1;
  return $self->{VALUE};
}

sub FETCH {
  my $self = shift;
  print "In ", $self->{object}{_name}, "'s FETCH, from ", (caller(1))[0..3], "\n" if $Debug == 1;
  if ( defined $self->{object}{_owner}
       or $self->{object}{_datasafe} == 0 ) {
    print "    Can't trust data, updating...\n" if $Debug == 1;
    $self->{object}->_update_;
  }
  croak("Error updating value!") if $self->{object}{_datasafe} != 1;
  print "    ", $self->{object}->name, "'s Fetch returning ", $self->{VALUE}, "\n" if $Debug == 1;
  return $self->{VALUE};
}

1;
__END__
