package Opts;

use Getopt::Long;

our $id         = '';
our $year       = 2009;
our $month      = 1;
our $day        = 1;
our $num        = 3;
our $fname      = '';
our $outfile    = '';
our $xmlfile    = '';
our $mode       = '';

our $help;

our $dbname = '';

GetOptions( 'id=s'     => \$id,
			'dbname=s' => \$dbname,
		    'year=i'   => \$year,
			'month=i'  => \$month,
		    'day=i'    => \$day,
			'num=i'    => \$num,
			'list=s'   => \$fname,
			'csv=s'    => \$outfile,
			'xml=s'    => \$xmlfile,
			'help|?'   => \$help); # or pod2usage(1);
