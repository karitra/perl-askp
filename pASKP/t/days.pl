use ASKP;

print "ASKP perl module, version: ", $ASKP::VERSION, "\n";

my $c    = ASKP::Connection->new('BASES') || die "Failed to open database session!\n";

my $date1 = '040701';
my $date2 = sprintf "%06d\n", $date1+5;

print "date from $date1\n";
print "date   to $date2\n";

my $pd   = ASKP::Period::fetch_days( $c, '1BE****Gs06', $date1, $date2)            || die "Failed to fetch ps!\n";

for my $d ( sort keys %{ $pd->days() } ) {
  local $, = "\n";
  print "date => $d\n";
  $pd->day($d)->dump();
  #$pd->day($d)->csv();
  #print "ps => " . @{ $pd->day($d) } . "\n";
}

$pd->dump_csv();

$c->close();


