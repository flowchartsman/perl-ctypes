package Ctypes;

use 5.010001;
use strict;
use warnings;
use Carp;

=head1 NAME

Ctypes - Call C libraries from Perl, using Perl

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);


our @EXPORT_OK = [ qw(
	FFI_BAD_ABI
	FFI_BAD_TYPEDEF
	FFI_LONG_LONG_MAX
	FFI_OK
	FFI_SIZEOF_ARG
	FFI_SIZEOF_JAVA_RAW
	FFI_TYPE_DOUBLE
	FFI_TYPE_FLOAT
	FFI_TYPE_INT
	FFI_TYPE_LAST
	FFI_TYPE_LONGDOUBLE
	FFI_TYPE_POINTER
	FFI_TYPE_SINT16
	FFI_TYPE_SINT32
	FFI_TYPE_SINT64
	FFI_TYPE_SINT8
	FFI_TYPE_STRUCT
	FFI_TYPE_UINT16
	FFI_TYPE_UINT32
	FFI_TYPE_UINT64
	FFI_TYPE_UINT8
	FFI_TYPE_VOID
	ffi_type_longdouble
	ffi_type_schar
	ffi_type_sint
	ffi_type_slong
	ffi_type_sshort
	ffi_type_uchar
	ffi_type_uint
	ffi_type_ulong
	ffi_type_ushort
) ];

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Ptypes::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Ctypes', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Ptypes - Perl extension for blah blah blah

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Ctypes;
    # Look Ma, no XS!
    my $foo = Ctypes->new();
    ...

=head1 DESCRIPTION

Stub documentation for Ptypes, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.

=head2 Exportable constants

  FFI_BAD_ABI
  FFI_BAD_TYPEDEF
  FFI_LONG_LONG_MAX
  FFI_OK
  FFI_SIZEOF_ARG
  FFI_SIZEOF_JAVA_RAW
  FFI_TYPE_DOUBLE
  FFI_TYPE_FLOAT
  FFI_TYPE_INT
  FFI_TYPE_LAST
  FFI_TYPE_LONGDOUBLE
  FFI_TYPE_POINTER
  FFI_TYPE_SINT16
  FFI_TYPE_SINT32
  FFI_TYPE_SINT64
  FFI_TYPE_SINT8
  FFI_TYPE_STRUCT
  FFI_TYPE_UINT16
  FFI_TYPE_UINT32
  FFI_TYPE_UINT64
  FFI_TYPE_UINT8
  FFI_TYPE_VOID
  ffi_type_longdouble
  ffi_type_schar
  ffi_type_sint
  ffi_type_slong
  ffi_type_sshort
  ffi_type_uchar
  ffi_type_uint
  ffi_type_ulong
  ffi_type_ushort

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

#sub function1 { }

=head2 function2

=cut

# sub function2 { }

=head1 AUTHOR

Ryan Jendoubi, C<< <ryan.jendoubi at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ctypes at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Ctypes>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Ctypes


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Ctypes>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Ctypes>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Ctypes>

=item * Search CPAN

L<http://search.cpan.org/dist/Ctypes/>

=back

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

=head1 ACKNOWLEDGEMENTS

This module was created under the auspices of Google through their
Summer of Code 2010. My deep thanks to Jonathan Leto, Reini Urban
and Shlomi Fish for giving me the opportunity to work on the project.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Ryan Jendoubi.

This program is free software; you can redistribute it and/or modify it
under the terms of the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Ctypes
