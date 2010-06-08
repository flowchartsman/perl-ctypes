#!perl -T

use Test::More tests => 4;

use Ctypes;
use DynaLoader;
use Devel::Peek;
use Data::Dumper;

# Adapted from http://github.com/rurban/c-dynalib/blob/master/lib/C/DynaLib.pm, 31/05/2010
my ($lib, $cos, $sig, $ret);

if ($^O eq 'cygwin') {
  $lib = DynaLoader::dl_load_file( "/bin/cygwin1.dll" );
    ok( defined $lib, 'Load cygwin1.dll' );
  $cos = DynaLoader::dl_find_symbol( $lib, 'cos' );
    ok( defined $cos, 'Load cos() function' );
}

if ($^O eq 'MSWin32') {
  $lib = DynaLoader::dl_load_file($ENV{SYSTEMROOT}."\\System32\\MSVCRT.DLL" );
    ok( defined $lib,   'Load msvcrt.dll' );
  $cos = DynaLoader::dl_find_symbol( $lib, 'cos' );
    ok( defined $cos,   'Load cos() function' );
}

if ($^O =~ /linux/) {
  my $found = DynaLoader::dl_findfile( '-lm' );
  $lib = DynaLoader::dl_load_file( $found );
    ok( defined $lib, 'Load libm' ) or diag( DynaLoader::dl_error() );
  $func = DynaLoader::dl_find_symbol( $lib, 'sqrt' );
    ok( defined $func, 'Load sqrt() function' ) or diag( DynaLoader::dl_error() );
}

$sig = "sdd";

note( "\n\nThe presence of this message will cause the following Ctypes::call to pass, but the following one will fail." );
$ret = Ctypes::call( $func, $sig, 16 ) or croak( "Call to Ctypes::call just after diag(\$func) failed." );
  is( $ret, 4, "Gave 16 to sqrt() just after calling diag(\$func), got $ret" ) or diag( "Ctypes::call with diag(\$func) failed: \$ret = $ret" );

$ret = Ctypes::call( $func, $sig, 16 ) or croak( "Call to Ctypes::call after diag(\$func) failed." );
  is( $ret, 4, "Gave 16 to sqrt() WITHOUT first calling diag(\$func),  got $ret" ) or diag( "Ctypes::call without diag(\$func) failed: \$ret = $ret" );

#    push(@names, "MSVCRT.DLL","MSVCRT90","MSVCRT80","MSVCRT71","MSVCRT70",
#         "MSVCRT60","MSVCRT40","MSVCRT20");
#  }
#  # Either a dll if there exists a unversioned dll,
  # or the import lib points to the versioned dll.
#  push(@dirs, "/lib", "/usr/lib", "/usr/bin/", "/usr/local/bin")
#    unless $^O =~ /^(MSWin32|VMS)$/;
#  push(@dirs, $ENV{SYSTEMROOT}."\\System32", $ENV{SYSTEMROOT}, ".")
#    if $^O eq 'MSWin32';
#  push(@names, "cyg$_.dll", "lib$_.dll.a") if $^O eq 'cygwin';
#  push(@names, "$_.dll", "lib$_.a") if $^O eq 'MSWin32';
#  push(@names, "lib$_.so", "lib$_.a");
#  my $pthsep = $Config::Config{path_sep};
#  push(@dl_library_path, split(/$pthsep/, $ENV{LD_LIBRARY_PATH} || ""))
#    unless $^O eq 'MSWin32';
#  push(@dirs, split(/$pthsep/, $ENV{PATH}));
#LOOP:
#  for my $name (@names) {
#    for my $dir (@dirs, @dl_library_path) {
#      next unless -d $dir;
#      my $file = File::Spec->catfile($dir,$name);
#      if (-f $file) {
#        $found = $file;
#        last LOOP;
#      }
#    }
#  }
#  if ($found) {
#    $found = system("dllimport -I $found") if $found =~ /\.a$/;
#    $lib = DynaLoader::dl_load_file($found, @_);
#  }
#}
## last ressort, try $so which might trigger a Windows MessageBox.
#unless ($lib) {
#  $lib = DynaLoader::dl_load_file($so, @_) if $so;
#  return undef unless $lib;

# diag( "Testing Ctypes $Ctypes::VERSION, Perl $], $^X" );
