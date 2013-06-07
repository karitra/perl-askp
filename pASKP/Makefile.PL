use 5.006000;
use ExtUtils::MakeMaker;

#
# Setting C++ as compiler instead of C
#
$CC         = 'g++';
$PGLIBINC   = '-I' . qx/pg_config --includedir/;
$PGLIBSPATH = '-L' . qx/pg_config --libdir/;

chomp($PGLIBINC);
chomp($PGLIBSPATH);

$ASKPPATH   = "$ENV{HOME}/src";
$ASKPLIBS   = "-L$ENV{HOME}/lib -lASKPobj -lASKPdates -lASKPpglib";


# Check if we are under Windows or linux
if ($ENV{OS} eq 'Windows_NT') {

	$CC = 'c:/PerlRoot/strawberry/c/bin/c++';

#	$PGPATH     = q|"c:/Program Files/PostgreSQL/8.4"|;
	$PGPATH     = q|"/c/Program\ Files/PostgreSQL/8.4"|;
	$PGLIBINC   = "-I$PGPATH/include";
	$PGLIBSPATH = "-L$PGPATH/lib";
	$PGLIBS     = 'libpq.lib';

	$ASKPPATH = '../../askp';
	$ASKPLIBS =
		"$ASKPPATH/pglib/libASKPpglib.a"  . ' ' .
		"$ASKPPATH/obj_askp/libASKPobj.a" . ' ' .
		"$ASKPPATH/dates/libASKPdates.a";

	$CUSTOM_DEFINE = 'WIN32';
} else {
	$CUSTOM_DEFINE = 'LINUX'
}

$ASKPINC  = "-I$ASKPPATH/include -I$ASKPPATH/obj_askp";

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'ASKP',
    VERSION_FROM      => 'lib/ASKP.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/ASKP.pm', # retrieve abstract from module
       AUTHOR         => 'A. Karev <lineum@mail.ru>') : ()),
    LIBS              => ["$ASKPLIBS"], # e.g., '-lm'
    DEFINE            => "-DNDEBUG -D$CUSTOM_DEFINE", # e.g., '-DHAVE_SOMETHING'
    INC               => "-I. $PGLIBINC $ASKPINC", # e.g., '-I. -I/usr/include/other'

	# Additional options to support C++
	CC                => $CC,
	LD                => $CC,

	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too

	XSOPT              => '-C++'
);
