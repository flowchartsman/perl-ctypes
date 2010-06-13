package Ctypes;

use 5.010000;
use strict;
use warnings;
use Carp;

=head1 NAME

Ctypes - Call and wrap C libraries and functions from Perl, using Perl

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';

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

=head1 SYNOPSIS

    use Ctypes;
    use DynaLoader;

    # Look Ma, no XS!
    my $lib =  DynaLoader::dl_load_file( DynaLoader::dl_findfile( "-lm" ));
    my $func = Dynaloader::dl_find_symbol( $lib, 'sqrt' );
    my $ret =  Ctypes::call( $func, 'sdd', 16  );

    print $ret # 4! Eureka!

=head1 DESCRIPTION

Ctypes is designed to let you, the Perl module author, who likes perl,
and doesn't want to have to mess about with XS or C or any of that guff,
to wrap native C libraries in a Perly way. You benefit by writing only
Perl. Your users benefit from not having to have a compiler properly
installed and configured.

The module should also be as useful for the admin, scientist or general
datamangler who wants to quickly script together a couple of functions
from different native libraries as for the Perl module author who wants
to expose the full functionality of a large C/C++ project.

=head1 SUBROUTINES/METHODS

Ctypes will offer both a procedural and OO interface (to accommodate
both types of authors described above). At the moment only the
procedural interface is working.

=head2 call

The main procedural interface to libffi's functionality.

Toss it some vars, see what you get!

=head1 AUTHOR

Ryan Jendoubi, C<< <ryan.jendoubi at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ctypes at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Ctypes>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can see the proposed API and keep up to date with development at
L<http://blogs.perl.org/users/doubi> or by following <at>doubious_code
on Twitter (if anyone knows a microblogging client that lets me manage
my Twitter, Facebook and Iden.ti.ca from the one interface, please let
me know :-)

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
