use ASKP;

my $c    = ASKP::Connection->new('BASES@localhost:5432') || die "Failed to open database session!\n";
my $ps   = $c->fetch_ps('1BE****Gs04', '040701')         || die "Failed to fetch ps!\n";
my $cnt  = $c->fetch_cnt('1BE****Gs07' )                 || die "Failed to fetch counter data!\n";
my $list = $c->fetch_list('1BE')                         || die "Failed to fetch list of objects\n";

use Devel::Peek;

print '$c', "\n";
Dump($c);

print '$ps', "\n";
Dump($ps);

print '$cnt', "\n";
Dump($cnt);

print '$list', "\n";
Dump( $list );


