package Ctypes::FuncProto;

use strict;
use warnings;
use Ctypes;
use Ctypes::Function;
our @ISA = qw(Ctypes::Function);
use overload '&{}' => \&_call_overload;

sub new;
sub AUTOLOAD;
sub _call;
sub _call_overload;

=head1 NAME

Ctypes::FuncProto - Function Protoypes

=head1 DESCRIPTION

Foreign functions can also be created by instantiating function
prototypes. Function prototypes are similar to function prototypes in
C; they describe a function (return type, argument types, calling
convention) without defining an implementation. The factory functions
must be called with the desired result type and the argument types of
the function.

A function prototype is basically the same as a L<Ctypes::Function>,
just without the handle. If called they return a L<Ctypes::Function>.

A prototype can be B<called> in the following ways:

=over

=item $prototype->(address)

Returns a foreign function at the specified address.

=item $prototype->(callable)

Create a C callable function (a callback function) from a Perl callable.

=item $prototype->(func_spec[, paramflags])

Returns a foreign function exported by a shared library. 

B<func_spec> must be a ARRAYREF of [name_or_ordinal, library]. The
first item is the name of the exported function as string, or the
ordinal of the exported function as small integer. The second item is
the shared library instance.

=item $prototype->(vtbl_index, name[, paramflags[, iid]])

Windows only: Returns a foreign function that will call a COM
method. B<vtbl_index> is the index into the virtual function table, a
small nonnegative integer. B<name> is name of the COM method. B<iid>
is an optional pointer to the interface identifier which is used in
extended error reporting.

COM methods use a special calling convention: They require a pointer
to the COM interface as first argument, in addition to those
parameters that are specified in the argtypes tuple.  The optional
C<paramflags> parameter creates foreign function wrappers with much more
functionality than the features described above.

=back

B<paramflags> must be an arrayref of the same length as argtypes.

Each item in this array contains further information about a
parameter, it must be an arrayref containing 1, 2, or 3 items.

The first item is an integer containing flags for the parameter:

  1 - Specifies an input parameter to the function.
  2 - Output parameter. The foreign function fills in a value.
  4 - Input parameter which defaults to the integer zero.

The optional second item is the parameter name as string. If this is
specified, the foreign function can be called with named parameters.

The optional third item is the default value for this parameter.

=head1 SYNOPSIS

  my $prototype  = WINFUNCTYPE(c_int, HWND, LPCSTR, LPCSTR, UINT);
  my $paramflags = [[1, "hwnd", 0], [1, "text", "Hi"], 
	           [1, "caption", undef], [1, "flags", 0]];
  my $MessageBox = $prototype->(["MessageBoxA", WinDLL->user32], $paramflags);
  $MessageBox->({text=>"Spam, spam, spam")});

  my $prototype2 = WINFUNCTYPE(BOOL, HWND, POINTER(RECT));
  my $paramflags2 = [[1, "hwnd"], [2, "lprect"]];
  my $GetWindowRect = $prototype2->(["GetWindowRect", WinDLL->user32], $paramflags2);

=head1 METHODS

=head2 new ( ... )

Create a function prototype instance. This is usually called by the functions
L<WINFUNCTYPE|CTypes/WINFUNCTYPE>, L<CFUNCTYPE|CTypes/CFUNCTYPE> or 
L<PERLFUNCTYPE|CTypes/PERLFUNCTYPE>.

=cut

sub new {
  my ($class, @args) = @_;
  my $proto = {};
  $proto->{abi} = $class =~ /::Win/ ? 's' : 'c';
  return bless $proto, $class;
}

package Ctypes::FuncProto::Win;

use Ctypes;
use Ctypes::Function;
our @ISA = qw(Ctypes::FuncProto);

package Ctypes::FuncProto::C;

use Ctypes;
use Ctypes::Function;
our @ISA = qw(Ctypes::FuncProto);

package Ctypes::FuncProto::Perl;

use Ctypes;
use Ctypes::Function;
our @ISA = qw(Ctypes::FuncProto);

1;
