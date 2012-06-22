package Ctypes::Type::Simple;
use strict;
use warnings;
use Carp;
use Ctypes::Util qw|_debug|;
use Ctypes::Type qw|&_types &strict_input_all|;
use Data::Dumper;
use Devel::Peek;
our @ISA = qw|Ctypes::Type|;
use fields qw|alignment name _typecode size
              strict_input val _as_param_|;
use overload '${}' => \&_scalar_overload,
             '0+'  => \&_scalar_overload,
             '""'  => \&_scalar_overload,
             '&{}' => \&_code_overload,
             fallback => 'TRUE';
       # TODO Multiplication will have to be overridden
       # to implement Python's Array construction with "type * x"???

=head1 NAME

Ctypes::Type::Simple - The atomic C data types

=head1 SYNOPSIS

    use Ctypes;         # standard c_<type> funcs and classes imported

    my $int = c_int;    # defaults to value 0
    $$c_int++;
    $$c_int += 5;

    my c_int $i = 5;

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
passed to C, while $int can be used to find out things I<about> the object
itself, like C<$int->name>, C<$int->size>, etc.

In addition to the methods provided by Ctypes::Type, Ctypes::Type::Simple
objects provide the following extra methods:

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

#
# Remember the properties of input.
# Calls XS function _save_input_flags, which works
# as follows:
#   See if input scalar is a number AND a string
#     If so, see if the string looks like a number
#       If so, take the number value
#       If not, take the string value
#     If not, respect the appropriate flag
#
sub _save_input_properties {
  # my( $self, $arg ) = @_;
  $_[0]->{_input} = {};
  Ctypes::Type::_save_input_flags( $_[0]->{_input}, $_[1] );
  $_[0]->{_input}->{orig} = $_[1];
}

sub _load_input_properties {
  # my( $self, $arg ) = @_;
  Ctypes::Type::_load_input_flags( $_[0]->{_input}, $_[1] );
  $_[1];
}

=over

=item new Simple TYPECODE [ARG]

=item new c_I<(class)> [ARG]

The Ctypes::Type::Simple constructor. See the main L<Ctypes|Ctypes/call>
module for an explanation of typecodes. ARG is the optional value
initialisation for your Type. Try to make it something sensible.
Numbers and characters usually go down well.

=cut

sub new {
  my $class = ref($_[0]) || $_[0]; shift;
  my ($typecode, $name);
  if ($class eq 'Ctypes::Type::Simple') {
    $typecode = shift;
    $name = Ctypes::Type::_types()->{$typecode}->{name};
    $class = 'Ctypes::Type::'.$name;
  } else {
    $name = $class =~ /(c_\w+|)/;
    $typecode = $Ctypes::Type::_defined{$name};
  }
  _debug( 4, "In Type::Simple constructor: typecode [ $typecode ]" );
  croak("Ctypes::Type::Simple error: Need typecode") if not defined $typecode;
  my $self = $class->_new( {
    _typecode        => $typecode,
    _name            => $name,
    _strict_input    => 0,
    _input           => {},
  } );

  my $arg = shift;
  $arg = 0 unless defined $arg;
  my( $invalid, $validated_arg ) = ( undef, 0 ); # 0 will be assigned if no $arg
##### Copious debugging
  _debug( 5, "    Saving arg..." );
  $self->_save_input_properties( $arg );  ## Essential!
  _debug( 5, "    arg was:");
  _debug( 5, "      D::D");
  print Dumper $arg if $Ctypes::Util::debuglvl;
  _debug( 5, "      D::P" );
  Dump( $arg ) if $Ctypes::Util::debuglvl;
#####
  $self->{_rawvalue} = tie $self->{_value}, 'Ctypes::Type::Simple::value', $self;
  $self->{_value} = $arg; # validation done in STORE
  return $self;
}


=item strict_input

Mutator setting and/or returning a flag (1 or 0) indicating how
fuzzy this object should be about values given it to store. Defaults
to 0, meaning Ctypes will do its best to make a sensible value of
the correct type out of any value it gets (although its ability to do
so is not always guaranteed). You'll probably get a warning about it.
Note that even if C<strict_input> is 0 for a particular object, it is
overridden if C<strict_input_all> is set to 1.

See the L<strict_input_all|Ctypes::Type/strict_input_all> class method
in L<Ctypes::Type>.

=cut

sub strict_input {
    my $self = shift;
    my $arg = shift;
    if( @_  or ( defined $arg and $arg != 1 and $arg != 0 ) ) {
      croak("Usage: strict_input(1 or 0)");
    }
    $self->{_strict_input} = $arg if defined $arg;
    $self->{_strict_input};
}

=item copy

Return a copy of the object.

=cut

sub copy {
  _debug( 5, "In Simple::copy\n"  );
  my $value = $_[0]->value;
  return Ctypes::Type::Simple->new( $_[0]->typecode, $value );
}

=item value EXPR

=item value

Accessor / mutator for the value of the variable the object
represents. C<value> is an lvalue method, so you can assign to it
directly, all the appropriate type checking will still be done.

=cut

sub value : lvalue {
  $_[0]->{_value} = $_[1] if defined $_[1];
  $_[0]->{_value};
}

sub data {
  my $self = shift;
  _debug( 5, "In ", $self->{_name}, "'s _DATA_, from ", join(", ",(caller(0))[0..3]), "\n"  );
  if( defined $self->owner
      or $self->_datasafe == 0 ) {
    _debug( 5, "    Can't trust data, updating...\n"  );
    $self->_update_;
  }
  if( defined $self->{_data}
      and $self->{_datasafe} == 1 ) {
    _debug( 5, "    asparam already defined\n"  );
    _debug( 5, "    returning ", unpack('b*',$self->{_data}), "\n"  );
    return \$self->{_data};
  }
  $self->{_data} =
    pack( $self->packcode, $self->{_value} );
  _debug( 5, "    returning ", unpack('b*',$self->{_data}), "\n"  );
  $self->{_datasafe} = 0;  # used by FETCH
  return \$self->{_data};
}

sub _as_param_ { &data(@_) }

#
# NB: _update_ should only ever take an argument of *binary data*
#     which can be assigned to $obj->{_data} directly.
#
#     This is so that the process works the same way with more
#     complex, aggregate types.
#
#     Nothing should need packed here!
#
sub _update_ {
  my $self = $_[0];
  _debug( 4, "In ", $self->{_name}, "'s _UPDATE_...\n"  );
  _debug( 5, "    Owned by ", $self->{_owner}->{_name} ) if $self->{_owner};
  if( not exists $_[1] ) {
    _debug( 5, "    No (binary) argument..." );
    if( $self->{_owner} ) {
#    if ( $self->{_owner} and not $self->{_datasafe} == 1 ) {
      _debug( 5, "    Have owner, getting updated data...\n"  );
      my $owners_data = ${$self->{_owner}->data};
      _debug( 5, "    Here's where I think I am in my pwner's data:\n"  );
      _debug( 5, " " x ($self->{_index} * 8), "v\n"  );
      _debug( 5, "12345678" x length($owners_data), "\n"  );
      _debug( 5, unpack('b*', $owners_data), "\n"  );
      _debug( 5, "    My index is ", $self->{_index}, "\n"  );
      _debug( 5, "    My size is ", $self->size, "\n"  );
      $self->{_data} = substr( $owners_data,
                               $self->{_index},
                               $self->size );
      _debug( 5, "    My data is now:\n", unpack('b*', $self->{_data}), "\n"  );
      _debug( 5, "    Which is ", unpack($self->packcode,$self->{_data}), " as a number");
      $self->{_rawvalue}->[1] = unpack($self->packcode, $self->{_data});
    }
  } else { # we WERE passed an argument
    $self->{_data} = $_[1]; # args must be binary, no pack needed
    if( $self->owner ) {
      $self->owner->_update_($self->{_data}, $self->{_index});
    }
  }
  _debug( 5, "Self->data: ", $self->{_data} );
  _debug( 5, "Self->data: ", unpack( 'b*', $self->{_data} ) );
  Dump $self->{_data} if $Ctypes::Util::debuglvl;
  $self->{_rawvalue}->[1] = unpack($self->packcode, $self->{_data});
  _debug( 5, "    VALUE is _update_d to ", $self->{_rawvalue}->[1], "\n"  );
  Dump $self->{_rawvalue}->[1] if $Ctypes::Util::debuglvl;
  $self->{_datasafe} = 1;
  return 1;
}

sub _set_undef { $_[0]->{_value} = 0 }

=item size

Returns the size of the type in bytes.

=cut

sub size { Ctypes::sizeof($_[0]->sizecode) }

=item sizecode

Access the packcode, used as libffi interface.

=cut

# defaults, overridden below
sub sizecode { $_[0]->packcode } # used as libffi interface

=item packcode

Access the typecode, used for perl pack/unpack.

=cut

sub packcode { $_[0]->typecode }

#sub sizecode {
#  my $t = $Ctypes::Type::_types->{$_[0]->{_typecode}};
#  defined $t->{sizecode} ? $t->{sizecode} : $_[0]->{_typecode};
#}
#sub packcode {
#  my $t = $Ctypes::Type::_types->{$_[0]->{_typecode}};
#  defined $t->{packcode} ? $t->{packcode} : $_[0]->{_typecode};
#}

=item validate

Calls the _hook_store() callback method, which checks types and limits on write.

=cut

sub validate {
  my $self = shift;
  $self->_hook_store(@_);
  #my $h = $Ctypes::Type::_types->{$_[0]->{_typecode}}->{hook_in};
  #defined $h ? $h->($_[1]) : ("", 1);
}

sub _limcheck {
}

# strings should override it, only for numbers.
# takes $arg
# returns (bool $invalid, number $arg)
sub _hook_store {
  my $self = shift;
  my $arg = shift;
  my $invalid = undef;
  my $tc = $self->typecode;
  my $name = $self->name;
  my $integer_only = $name =~ /double|float/ ? 0 : 1;
  _debug( 4, "In _hook_store $name\n" );
  return ( "$name: cannot take references", undef )
    if ref($arg);
  return ($invalid, $arg) unless $self->can('_minmax');

  my ($MIN,$MAX) = $self->_minmax();
  unless (defined $MIN) {
    return ("$name: wrong _minmax", $arg);
  }
  if( Ctypes::Type::is_a_number($arg) ) {
    if( $integer_only ) {
      if( $arg !~ /^[+-]?\d+$/ ) { # XXX fix to better rx's
        $invalid = "$name: numeric values must be "
          . ( $integer_only ? "integers " : '' )
          . "$MIN <= x <= $MAX";
        $arg = sprintf("%u",$arg);
      }
    }
    if( $arg < $MIN or $arg > $MAX ) {
        $invalid = "$name: numeric values must be "
          . ( $integer_only ? "integers " : '' )
          . "$MIN <= x <= $MAX"
          if not defined $invalid;
    }
  } else {
    if( length($arg) == 1 ) {
      _debug( 5, "    1 char long, good\n" );
      $arg = ord($arg);
      if( $arg < 0 or $arg > $MAX ) {
        $invalid = "$name: character values must be integers " .
          "0 <= ord(x) <= $MAX";
      }
    } else {
      $invalid = "$name: single characters only";
      $arg = ord(substr($arg, 0, 1));
      if( $arg < 0 or $arg > $MAX ) {
        $invalid .= ", and must be integers " .
          "0 <= ord(x) <= $MAX";
      }
    }
  }
  return ($invalid, $arg);
}

=back

=head1 INTERNAL METHODS

These are documented here solely for the understanding and ongoing
development of Ctypes internals. B<They DO NOT form part of the
official Ctypes API>. Do not use them in your applications.

=over

=item _hook_fetch I<internal_value>

C<_hook_fetch> is for taking the internal representation of the
data type object and returning it in the form expected by the
Perl code in the "outside world". If no modification is required,
it must return its single argument unmodified.

The case where _hook_fetch is most needed by the core Ctypes
types are for C<c_byte> and C<c_ubyte> types. Both of these types
can be assigned either numerical or single-character string
values. Inside the object, both types of input are stored as
numbers: both the decimal value 65 and the ASCII character 'A'
have the same value in a c_byte type. However, if a user put
in a character, it is reasonable to expect that character to come
back out, not its internal numeric representation. This is what
_hook_fetch is for.

_hook_fetch should not modify any public or private properties
of its object. All the logic for cleansing input is held in the
STORE and _hook_store methods. Circumventing these methods
in _hook_fetch or anywhere else would raise the possibility
of inconsistent data.

=cut

sub _hook_fetch {
  my $obj = shift;
  _debug( 4, "In _hook_fetch ", $obj->name  );
  $_[0];
  #my $value = $obj->{_value};
}

sub _minmax_const {
  my ($invalid1, $v1, $invalid2, $v2) = @_;
  $v1 = undef if $invalid1;
  $v2 = undef if $invalid2;
  return ($v1, $v2);
}

=back

=head1 SEE ALSO

L<Ctypes>

=cut

# DONE
# c_char c_byte c_ubyte c_short c_ushort c_int c_uint c_long c_ulong
# c_longlong c_ulonglong c_float c_double c_longdouble
# c_int8 c_int16 c_int32 c_int64 c_uint8 c_uint16 c_uint32 c_uint64

# CHECK
# c_wchar c_char_p c_wchar_p c_bool c_void_p
# c_size_t c_ssize_t

package Ctypes::Type::c_byte;
use base 'Ctypes::Type::Simple';
use Ctypes::Util qw|_debug|;
sub sizecode{'c'};
sub packcode{'c'};
sub typecode{ $Ctypes::USE_PERLTYPE ? 'c' : 'b'};
sub _minmax { ( -128, 127 ) }
sub _hook_fetch {
  _debug( 4, "In _hook_fetch c_byte\n"  );
# If the value assigned was a character, give a character back.
# Otherwise give a number back (stored as a number internally).
# XXX What if last assignment was e.g. a float?
  return chr($_[1]) if exists $_[0]->{_input}->{PV};
  $_[1];
}

package Ctypes::Type::c_ubyte;
use base 'Ctypes::Type::Simple';
use Ctypes::Util qw|_debug|;
our $Debug;
sub sizecode{'C'};
sub packcode{'C'};
sub typecode{ $Ctypes::USE_PERLTYPES ? 'C' : 'B'};
sub _minmax { ( 0, 255 ) }
sub _hook_fetch {
  _debug( 4, "In _hook_fetch c_ubyte\n"  );
  return $_[0]->_load_input_properties( chr($_[1]) )
    if exists $_[0]->{_input}->{PV};
  $_[1];
}

# single character, c signed, possibly a multi-char (?)
package Ctypes::Type::c_char;
use base 'Ctypes::Type::Simple';
use Ctypes::Util qw|_debug|;
sub sizecode{'c'};
#sub packcode{'c'};
sub typecode{'c'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const(
    Ctypes::constant('CHAR_MIN'),
    Ctypes::constant('CHAR_MAX')
  );
}
sub _hook_fetch {
  _debug( 4, "In _hook_fetch c_char\n"  );
# For char types, we want to return a PV (string) type scalar
# regardless of the input type.
  delete  $_[0]->{_input}->{IV} if exists $_[0]->{_input}->{IV};
  delete  $_[0]->{_input}->{NV} if exists $_[0]->{_input}->{NV};
  $_[0]->{_input}->{PV} = 1;
  return $_[0]->_load_input_properties( chr($_[1] ) );
}

# single character, c unsigned, possibly a multi-char (?)
package Ctypes::Type::c_uchar;
use base 'Ctypes::Type::Simple';
use Ctypes::Util qw|_debug|;
#sub sizecode{'C'};
#sub packcode{'C'};
sub typecode{'C'};
sub _minmax { ( 0, 255 ) }
sub _hook_fetch {
  _debug( 4, "In _hook_fetch c_uchar\n"  );
# For char types, we want to return a PV (string) type scalar
# regardless of the input type.
  delete  $_[0]->{_input}->{IV} if exists $_[0]->{_input}->{IV};
  delete  $_[0]->{_input}->{NV} if exists $_[0]->{_input}->{NV};
  $_[0]->{_input}->{PV} = 1;
  return $_[0]->_load_input_properties( chr($_[1] ) );
}

package Ctypes::Type::c_short;
use base 'Ctypes::Type::Simple';
#sub sizecode{'s'};
sub packcode{'s'};
sub typecode{ $Ctypes::USE_PERLTYPES ? 's' : 'h'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const
      (Ctypes::constant('PERL_SHORT_MIN'),
       Ctypes::constant('PERL_SHORT_MAX') ) }

package Ctypes::Type::c_ushort;
use base 'Ctypes::Type::Simple';
#sub sizecode{'S'};
sub packcode{'S'};
sub typecode{ $Ctypes::USE_PERLTYPES ? 'S' : 'H'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const
      (Ctypes::constant('PERL_USHORT_MIN'),
       Ctypes::constant('PERL_USHORT_MAX') ) }

# Alias to c_long where equal; i
package Ctypes::Type::c_int;
use base 'Ctypes::Type::Simple';
#sub sizecode{'i'};
sub packcode{'i'};
sub typecode{'i'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const
      (Ctypes::constant('PERL_INT_MIN'),
       Ctypes::constant('PERL_INT_MAX') ) }
sub _hook_fetch {
  return 0 unless defined $_[1];
  return $_[0]->_load_input_properties( $_[1] );
}

# Alias to c_ulong where equal; I
package Ctypes::Type::c_uint;
use base 'Ctypes::Type::Simple';
sub sizecode{'i'};
sub packcode{'I'};
sub typecode{'I'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const
      (Ctypes::constant('PERL_UINT_MIN'),
       Ctypes::constant('PERL_UINT_MAX') ) }
sub _hook_fetch {
  return 0 unless defined $_[1];
  return $_[0]->_load_input_properties( $_[1] );
}

package Ctypes::Type::c_long;
use base 'Ctypes::Type::Simple';
#sub sizecode{'l'};
#sub packcode{'l'};
sub typecode{'l'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const
      (Ctypes::constant('PERL_LONG_MIN'),
       Ctypes::constant('PERL_LONG_MAX') ) }

package Ctypes::Type::c_ulong;
use base 'Ctypes::Type::Simple';
sub sizecode{'l'};
sub packcode{'L'};
sub typecode{'L'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const
      (Ctypes::constant('PERL_ULONG_MIN'),
       Ctypes::constant('PERL_ULONG_MAX') ) }

package Ctypes::Type::c_float;
use base 'Ctypes::Type::Simple';
#sub sizecode{'f'};
sub packcode{'f'};
sub typecode{'f'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const
      (Ctypes::constant('FLT_MIN'),
       Ctypes::constant('FLT_MAX') ) }

package Ctypes::Type::c_double;
use base 'Ctypes::Type::Simple';
#sub sizecode{'d'};
#sub packcode{'d'};
sub typecode{'d'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const
      (Ctypes::constant('DBL_MIN'),
       Ctypes::constant('DBL_MAX') ) }

package Ctypes::Type::c_longdouble;
use base 'Ctypes::Type::Simple';
#sub sizecode{'D'};
sub packcode{'D'};
sub typecode{ $Ctypes::USE_PERLTYPES ? 'D' : 'g'};
sub _minmax {
  Ctypes::Type::Simple::_minmax_const
      (Ctypes::constant('LDBL_MIN'),
       Ctypes::constant('LDBL_MAX') ) }

package Ctypes::Type::c_longlong;
use base 'Ctypes::Type::Simple';
use Config;
#sub sizecode{'q'};
#sub packcode{'q'};
sub typecode{'q'};
sub _minmax { (-hex("8".("F" x (2*$Config{longlongsize}))),
                hex("8".("F" x (2*$Config{longlongsize})))) }

package Ctypes::Type::c_ulonglong;
use base 'Ctypes::Type::Simple';
use Config;
#sub sizecode{'Q'};
#sub packcode{'Q'};
sub typecode{'Q'};
sub _minmax { (0, hex("F" x (2*$Config{longlongsize}))) }

package Ctypes::Type::c_bool;
use base 'Ctypes::Type::Simple';
#sub sizecode{'c'}; # ?
sub packcode{'c'}; # ?
sub typecode{'v'};

package Ctypes::Type::c_void;
use base 'Ctypes::Type::Simple';
sub sizecode{'v'};
sub packcode{'a'};
sub typecode{'O'};
sub _hook_store{
  my $invalid = undef;
  if( exists $_[0] ) {
    $invalid = "c_void: void types cannot take values";
  }
  return ( $invalid, "\0" );
}

package Ctypes::Type::c_size_t;
use base 'Ctypes::Type::c_uint';
package Ctypes::Type::c_ssize_t;
use base 'Ctypes::Type::c_int';

package Ctypes::Type::c_int8;
use base 'Ctypes::Type::c_byte';
package Ctypes::Type::c_int16;
use base 'Ctypes::Type::c_short';
package Ctypes::Type::c_int32;
use base 'Ctypes::Type::c_long';
package Ctypes::Type::c_int64;
use base 'Ctypes::Type::c_longlong';
package Ctypes::Type::c_uint8;
use base 'Ctypes::Type::c_ubyte';
package Ctypes::Type::c_uint16;
use base 'Ctypes::Type::c_ushort';
package Ctypes::Type::c_uint32;
use base 'Ctypes::Type::c_ulong';
package Ctypes::Type::c_uint64;
use base 'Ctypes::Type::c_ulonglong';

# Not so simple types:
# XXX TODO size

# null terminated string, A?
package Ctypes::Type::c_char_p;
use base 'Ctypes::Type::Simple';
use Ctypes::Util qw|_debug|;
sub sizecode{'p'};
sub packcode{'A?'};
sub typecode{ $Ctypes::USE_PERLTYPES ? 'A' : 's'};
sub size { $_[0]->{_size} }
sub _hook_store {
  my $self = shift;
  my $arg = shift;
  my $invalid = undef;
  _debug( 4, "In _hook_store c_char_p\n"  );
  return ($invalid, $arg);
}

package Ctypes::Type::c_wchar;
use base 'Ctypes::Type::Simple';
sub sizecode{'p'};
sub packcode{'U'};
sub typecode{ $Ctypes::USE_PERLTYPES ? 'U' : 'w'};
sub size { $_[0]->{_size} }

package Ctypes::Type::c_wchar_p;
use base 'Ctypes::Type::Simple';
sub sizecode{'p'};
sub packcode{'U*'};
sub typecode{'z'};
sub size { $_[0]->{_size} }

package Ctypes::Type::c_bstr;
use base 'Ctypes::Type::Simple';
#sub sizecode{'a'};
sub sizecode{'p'};
sub packcode{'a?'};
sub typecode{'X'};
sub size { $_[0]->{_size} }

#####################################################################

package Ctypes::Type::Simple::value;
use strict;
use warnings;
no warnings 'pack';
use Carp;
use Ctypes::Util qw |_debug|;
use Scalar::Util qw|blessed|;
use Data::Dumper;
use Devel::Peek;

sub TIESCALAR {
  my $class = shift;
  my $object = shift;
  my $self = [ $object, $object->{_value} ];
  return bless $self => $class;
}

sub STORE {
  croak("Simple Types can only be assigned a single value") if scalar @_ != 2;
  my $self = $_[0];
  my $object = $self->[0];
  my $arg = $_[1];
  my $orig_arg = $arg;
  _debug( 4, "In ", $object->{_name}, "'s STORE with arg [ ", $arg, " ],\n"  );
  _debug( 5, "    called from ", (join ", ", ((caller(0))[0..3]) ), "\n" );

  # Deal with being assigned other Type objects and the like...
#    if(my $ref = ref($arg)) {
#      if($ref =~ /^Ctypes::Type::/) {
#        $arg = $arg->{_data};
#      } else {
#        if($arg->can("data")) {
#          $arg = ${$arg->data};
#        } else {
#    # ??? Would you ever want to store an object/reference as the value
#    # of a type? What would get pack()ed in the end?
#          croak("Ctypes Types can only be made from native types or " .
#                "Ctypes compatible objects");
#        }
#      }
#    }

  # Object's Value set to undef: {_val} becomes undef, {_data} filled
  # with null (i.e. numeric zero) , update owners, return early.
  if( not defined $arg ) {
    _debug( 5, "    Assigned undef. All goes null.\n"  );
    $object->{_datasafe} = 0;
    _debug( 5, "Rawvalue before assignment:" );
    Dump $self->[1] if $Ctypes::Util::debuglvl;
    $self->[1] = 0;
    _debug( 5, "Rawvalue after assignment:" );
    Dump $self->[1] if $Ctypes::Util::debuglvl;
    $object->{_data} = "\0" x 8 x $object->{_size}; # stay right length
    _debug( 5, "  data is: ", unpack( 'b*', $object->{_data} ) );
    if( $object->{_owner} ) {
      $object->{_owner}->_update_($object->{_data}, $object->{_index});
    }
    return $self->[1];
  }

  my $typecode = $object->{_typecode};
  _debug( 5, "    Using typecode $typecode\n" );
  _debug( 5, "    1) arg is ", $arg, "\n" );
  my ($invalid, $validated_arg) = $object->validate($arg);

  _debug( 5, "    validate() returned ", ( $invalid ? "'$invalid'" : "ok" ), "\n" );
  if( defined $invalid ) {
    no strict 'refs';
    if( ($object->strict_input == 1)
        or (Ctypes::Type::strict_input_all() == 1)
        or (not defined $validated_arg) ) {
      _debug( 5, "Unable to ameliorate input. strict input or validate couldn't convert\n"  );
      croak( $invalid, ' (got ', $arg, ')');
      return undef;
    } else {
      carp( $invalid, ' (got ', $arg, ')');
    }
  }
  _debug( 5, "    2) arg is $validated_arg\n",
    "    binary:\n\t", unpack('b*', $validated_arg), "\n",
    "    ordinal:\n\t", ord($validated_arg), "\n" );
#
# Put the $object's values in order
#
  eval { $object->{_data} = pack( $object->packcode, $validated_arg ); }; # overflow warning
  $self->[1] = unpack( $object->packcode, $object->{_data} );
  $object->_save_input_properties( $orig_arg );
#
# This object might be part of an Array or Struct;
# if so update the binary data in that as well.
#
  if( $object->{_owner} ) {
    _debug( 5, "    Have owner, updating with:\n",
      , "    binary:\n\t", unpack('b*', $object->{_data}), "\n"
      , "    typed:\n\t",  unpack($object->{_typecode},$object->{_data}), "\n" );
    $object->{_owner}->_update_($object->{_data}, $object->{_index});
  }
  _debug( 4, "  Returning ok [ ", $self->[1], " ]...\n"  );
  return $self->[1];
}

sub FETCH {
  my $self = shift;
  my $object = $self->[0];
  _debug( 4, "In ", $object->{_name}, "'s FETCH, from ", join(", ",(caller(0))[0..3]) );
#
# If this object is part of a larger complex type object (like an Array
# or a Struct), it's possible that that owning object's binary data has
# been operated upon by a library.
# 
# Call update now to ensure propagation of those changes to this object
# (both binary data and Perl-space 'value' will be updated).
#
  if ( defined $object->{_owner}
       or $object->{_datasafe} == 0 ) {
    _debug( 5, "    Can't trust data, updating...\n"  );
    $object->_update_;
  }
  croak("Error updating value!") if $object->{_datasafe} != 1;
  _debug( 4, "    ", $object->name, "'s Fetch returning "
    , $self->[1], "\n" );
  _debug( 5, "#    " . $object->{_name} . "'s FETCH: Input:" );
  print Dumper $object->{_input} if $Ctypes::Util::debuglvl;
  _debug( 5, "#    " . $object->{_name} . "'s FETCH: Self->[1]:" );
  Dump( $self->[1] ) if $Ctypes::Util::debuglvl;
  my $to_return = $self->[1];
  return $object->_hook_fetch( $to_return );
}

1;
__END__
