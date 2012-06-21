package Ctypes::Util;
use strict;
use warnings;
use Carp;
use Getopt::Long;
use Scalar::Util qw|blessed looks_like_number|;

require Exporter;
our @ISA = qw|Exporter|;
our @EXPORT_OK = qw|
  _check_invalid_types
  _check_type_needed
  _debug
  _make_arrayref
  _valid_for_type
  find_library
  create_range
|;

=head1 Utility Functions

=over

=item Ctypes::Util::find_library (lib, [dynaloader args])

Searches the dll/so loadpath for the given library, architecture dependently.

The lib argument is either part of a filename (e.g. "kernel32"),
a full pathname to the shared library
or the same as for L<DynaLoader::dl_findfile>:

"-llib" or "-Lpath -llib", with -L for the optional path.

Returns the path of the found library or undef.

  find_library "-lm"
    => "/usr/lib/libm.so"
     | "/usr/bin/cygwin1.dll"
     | "C:\\WINDOWS\\\\System32\\MSVCRT.DLL

  find_library "-L/usr/local/kde/lib -lkde"
    => "/usr/local/kde/lib/libkde.so.2.0"

  find_library "kernel32"
    => "C:\\WINDOWS\\\\System32\\KERNEL32.dll"

On cygwin or mingw C<find_library> might try to run the external program C<dllimport>
to resolve the version specific dll from the found unversioned import library.

With C<mode> optional dynaloader args can or even must be specified as with
L<load_library>, because C<find_library> also tries to load every found
library, and only returns libraries which could successfully be dynaloaded.

=cut

sub find_library($;@) {# from C::DynaLib::new
  my $libname = $_ = shift;
  my $so = $libname;
  -e $so or $so = DynaLoader::dl_findfile($libname) || $libname;
  my $lib;
  $lib = DynaLoader::dl_load_file($so, @_) unless $so =~ /\.a$/;
  return $so if $lib;

  # Duplicate most of the DynaLoader code, since DynaLoader is
  # not ready to find MSWin32 dll's.
  if ($^O =~ /MSWin32|cygwin/) { # activeperl, mingw (strawberry) or cygwin
    my ($found, @dirs, @names, @dl_library_path);
    my $lib = $libname;
    $lib =~ s/^-l//;
    if ($^O eq 'cygwin' and $lib =~ m{^(c|m|pthread|/usr/lib/libc\.a)$}) {
      return "/bin/cygwin1.dll";
    }
    if ($^O eq 'MSWin32' and $lib =~ /^(c|m|msvcrt|msvcrt\.lib)$/) {
      $so = $ENV{SYSTEMROOT}."\\System32\\MSVCRT.DLL";
      if ($lib = DynaLoader::dl_load_file($so, @_)) {
	      return $so;
      }
      # python has a different logic: The version+subversion is taken from
      # msvcrt dll used in the python.exe
      # We search in the systempath for the first found. This is really tricky,
      # as we only should take the run-time used in perl itself. (objdump/nm/ldd or the perl.dll)
      push(@names, "MSVCRT.DLL","MSVCRT90","MSVCRT80","MSVCRT71","MSVCRT70",
	   "MSVCRT60","MSVCRT40","MSVCRT20");
    }
    # Either a dll if there exists a unversioned dll,
    # or the import lib points to the versioned dll.
    push(@dirs, "/lib", "/usr/lib", "/usr/bin/", "/usr/local/bin")
      unless $^O eq 'MSWin32'; # i.e. cygwin
    push(@dirs, $ENV{SYSTEMROOT}."\\System32", $ENV{SYSTEMROOT}, ".")
      if $^O eq 'MSWin32';
    push(@names, "cyg$_.dll", "lib$_.dll.a") if $^O eq 'cygwin';
    push(@names, "$_.dll", "lib$_.a") if $^O eq 'MSWin32';
    push(@names, "lib$_.so", "lib$_.a");
    my $pthsep = $Config::Config{path_sep};
    push(@dl_library_path, split(/$pthsep/, $ENV{LD_LIBRARY_PATH} || ""))
      unless $^O eq 'MSWin32';
    push(@dirs, split(/$pthsep/, $ENV{PATH}));
  LOOP:
    for my $name (@names) {
      for my $dir (@dirs, @dl_library_path) {
	      next unless -d $dir;
	      my $file = File::Spec->catfile($dir,$name);
	      if (-f $file) {
	        $found = $file;
	        last LOOP;
	      }
      }
    }
    if ($found) {
      # resolve the .a or .dll.a to the dll.
      # dllimport from binutils must be in the path
      $found = system("dllimport -I $found") if $found =~ /\.a$/;
      return $found if $found;
    }
  } else {
    if (-e $so) {
      # resolve possible ld script
      # GROUP ( /lib/libc.so.6 /usr/lib/libc_nonshared.a  AS_NEEDED ( /lib/ld-linux-x86-64.so.2 ) )
      local $/;
      my $fh;
      open($fh, "<", $so);
      my $slurp = <$fh>;
      # for now the first in the GROUP. We should use ld
      # or /sbin/ldconfig -p or objdump
      if ($slurp =~ /^\s*GROUP\s*\(\s*(\S+)\s+/m) {
	return $1;
      }
    }
  }
}

=item create_range MIN MAX COVER [ WEIGHT WANT_INT ]

=item create_range ARRAYREF, ARRAYREF ...

Used for creating ranges of test values for Ctypes::Type::Simple objects.
Returns an array of values. For more complex ranges, the basic arguments
(C<min>, C<max>, C<cover>, C<weight>, C<want_int>) can be repeated in
as many arrayrefs as you like, and the array returned will be a
combination of those ranges.

=back

=head3 Arguments:

=over

=item min

The 'minimum' value (but see C<min_ext>).

=item max

The 'maximum' value (but see C<max_ext>).

=item cover

If C<cover> is 1 or more, it will specify the B<exact number> of values
between C<min> and C<max> to be returned.
If C<cover> is less than 1 and greater than 0, it will specify a
B<percentage> of values between C<min> and C<max> to be returned. E.g.
if C<cover> is 0.1, C<create_range> will return 10% of the values between
C<min> and C<max>.
C<create_range> will croak if C<cover> is less than 0.

=back

=cut

sub create_range {
  if( ref( $_[0] ) eq 'ARRAY' ) {
    my @res = ();
    for( @_ ) {
      push @res, create_range( @$_ );
    }
    return @res;
  }

  my( $min, $max,
      $cover,              # number of points OR percentage of points
      $weight,                   # x>1 skews->$min; 0<x<1 skews->$max
      $want_int ) = @_;                  # want only integer results?

# $cover
  $cover = $max - $min unless defined $cover;
  croak ( "create_range: 'cover' must be positive (got $cover)" )
    if $cover < 0;
  croak ( "create_range: can't return $cover integer points " .
          "between $min and $max" )
    if $want_int and $cover > ($max - $min);
  if ( $cover < 1 ) {                          # treat as a percentage
    $cover = int( ( $max - $min )  * $cover ); # get number of points
  }

# $weight
  $weight ||= 1;         # no division by zero! Will make even spread
  $weight = $weight * -1;  # make +ves tend->$max and -ves tend->$min

# Let's pretend $min is zero
  my $diff_max = $max - $min;
  my $x_max = $diff_max ** ( 1 / abs($weight) ); # get x where y=$max

  my $interval = $x_max / $cover;

# Stuff for efficiency in find_nearest()
  my $opts = {};
  my $seen = {};
  my $points = [];
  my( $point, $nearest );

  for( my $i = 1; $i <= $cover; $i++ ) {
    if( $weight < 0 ) {
      $point = $max - ( ( $i * $interval ) ** abs($weight) );
    } else {
      $point = $min + ( ( $i * $interval ) ** $weight );
    }
    $nearest = _find_nearest(
      $want_int ? int( $point ) : $point,
      $min, $max, $opts, $seen );
    $point = $nearest;
    push @$points, $point;
  }
  return sort( { $a <=> $b } @$points );
} # sub create_range

# Take an arrayref (see _make_arrayref) and makes sure all contents are
#   valid typecodes
#   Type objects
#   Objects implementing _as_param_ attribute or method
# Returns UNDEF on SUCCESS
# Returns the index of the failing thingy on failure
sub _check_invalid_types ($) {
  my $typesref = shift;
  # Check if supplied args are valid
  my $typecode = undef;
  for( my $i=0; $i<=$#{$typesref}; $i++ ) {
    $_ = $typesref->[$i];
    # Check if all objects fulfill all requirements
    if( ref($_) ) {
      if( !blessed($_) ) {
        carp("No unblessed references as types");
        return $i;
      } else {
        if( !$_->can("_as_param_")
            and not defined($_->{_as_param_}) ) {
          carp("types must have _as_param_ method or attribute");
          return $i;
        }
        # try for attribute first
        $typecode = $_->{_typecode_};
        if( not defined($typecode) ) {
          if( $_->can("typecode") ) {
            $typecode = $_->typecode;
          } else {
            carp("types must have typecode method");
            return $i;
          }
        }
        eval{ Ctypes::sizeof($_->sizecode) };
        if( $@ ) {
          carp( @_ );
          return $i;
        }
      }
    } else {
      # Not a ref; make sure it's a valid 1-char typecode...
      if( length($_) > 1 ) {
        carp("types must be valid objects or 1-char typecodes (perldoc Ctypes)");
        return $i;
      }
      eval{ Ctypes::sizeof($_); };
      if( $@ ) {
        carp( @_ );
        return $i;
      }
    }
  }
  return undef;
} # sub _check_invalid_types

# Take an list of Perl natives. Return the typecode of
# the smallest C type needed to hold all the data - the
# lowest common demoninator.
# char C => string s => short h => int => long => double
sub _check_type_needed (@) {
  # XXX This needs to be changed when we support more typecodes
  _debug( 4, "In _check_type_needed" );
  my @types = $Ctypes::USE_PERLTYPES ? qw|C p s i l d| : qw|C s h i l d|;
  my @numtypes = @types[2..6]; #  0: short 1: int 2: long 3: double
  my $low = 0;
  my $char = 0;
  my $string = 0;
  my $reti = 0;
  my $ret = $types[$reti];
  for(my $i = 0; defined( local $_ = $_[$i]); $i++ ) {
    if( $char or !looks_like_number($_) ) {
      $char++; $reti = 1;
      $string++ if length( $_ ) > 1;
      $reti = 2 if $string;
      $ret = $types[$reti];
      _debug( 5, "    $i: $_ => $ret" );
      last if $string;
      next;
    } else {
      _debug( 5, "  $i: $_ => $ret" ) if $low == 3;
      next if $low == 3;
      $low = 1 if $_ > Ctypes::constant('PERL_SHORT_MAX') and $low < 1;
      $low = 2 if $_ > Ctypes::constant('PERL_INT_MAX')   and $low < 2;
      $low = 3 if $_ > Ctypes::constant('PERL_LONG_MAX')  and $low < 3;
      $ret = $numtypes[$low];
      _debug( 5, "    $i: $_ => $ret" );
    }
  }
  _debug( 4, "  Returning: $ret" );
  return $ret;
} # sub _check_type_needed


# Take input of:
#   ARRAY ref
#   or list
#   or typecode string
# ... and interpret into an array ref
sub _make_arrayref {
  my @inputs = @_;
  my $output = [];
  # Turn single arg or LIST into arrayref...
  if( ref($inputs[0]) ne 'ARRAY' ) {
    if( $#inputs > 0 ) {      # there is a list of inputs
      for(@inputs) {
        push @{$output}, $_;
      }
    } else {   # there is only one input
      if( !ref($inputs[0]) ) {
      # We can make list of argtypes from string of type codes...
        $output = [ split(//,$inputs[0]) ];
      } else {
        push @{$output}, $inputs[0];
      }
    }
  } else {  # first arg is an ARRAY ref, must be the only arg
    croak( "Can't take more args after ARRAY ref" ) if $#inputs > 0;
    $output = $inputs[0];
  }
  return $output;
}



#
# _find_nearest: Used by create_range.
# When point has been used, find a nearby one
# (esp. useful for integers)
#
sub _find_nearest {
  my( $point, $min, $max, $opts, $seen ) = @_;
  $min = $opts->{lowest_available} || $min;
  $max = $opts->{highest_available} || $max;

  if( $point >= $max ) {
    $point = $max;
    $point = exists $opts->{highest_available} ?
             $opts->{highest_available} : $max;
    $opts->{got_to_max} = 1;
  }
  if( $point <= $min ) {
    $point = $min;
    $point = exists $opts->{lowest_available} ?
             $opts->{lowest_available} : $min;
    $opts->{got_to_min} = 1;
  }

  my $try = $opts->{try} || 0;           # offset from desired $point

  $opts->{last_direction} = $opts->{direction} || 0;
  $opts->{direction} = $try < 0 ? -1 : 1;
  if( $opts->{direction} == $opts->{last_direction} ) {
    $opts->{same_direction} += 1;
  } else {
    $opts->{same_direction} = 0;
  }
  my $thistry = $point + $try;
  if( $thistry >= $max ) {
    $thistry = $max;
    $opts->{cant_go_up} = 1;
  }
  if( $thistry <= $min ) {
    $thistry = $min;
    $opts->{cant_go_down} = 1;
  }
  if( exists $seen->{$thistry} ) {
    if( exists $opts->{cant_go_up} ) {
      $opts->{highest_available} = $max - $opts->{same_direction} - 1;
      $try = abs($try) * -1;
      $try -= 1 if $opts->{same_direction} > 1;
    } elsif( exists $opts->{cant_go_down} ) {
      $opts->{lowest_available} = $min + $opts->{same_direction} + 1;
      $try = abs($try);
      $try += 1 if $opts->{same_direction} > 1;
    } else {
      $try = $try * -1;
      $try += $try >= 0 ? 1 : -1;
    }
    $opts->{try} = $try;
    _find_nearest( $point, $min, $max, $opts, $seen );
  } else {
    $seen->{$thistry} = 1;
    $opts->{direction} = 0;
    $opts->{last_direction} = 0;
    $opts->{try} = undef;
    return $thistry;
  }
}



#
# Set up debugging facilities (inspired largely by Debug::Simple)
#
my( $debuglvl );
my $result = GetOptions(
  'debug=i' => \$debuglvl,
);
sub _debug {
  return unless $debuglvl;
  my $level = shift;
  croak( "debug() expects numeric debug level as 1st arg" )
    unless looks_like_number( $level );
  return unless $level <= $debuglvl;
  print @_, ( substr( $_[$#_], -1, 1 ) eq "\n" ? '' : "\n" );
}

1;

__END__
