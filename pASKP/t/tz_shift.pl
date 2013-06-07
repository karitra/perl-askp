use ASKP;

my $c = new ASKP::Connection('BASES');

my $psCET = $c->fetch_ps( '1CC**LS1001', '040702' );

=pod

	Optional parameters to fetch_ps:
	  TZ   - time zone;
      DLS  - day light saving time flag (1 - used, 0 - not used);
      Diff - substitute accumulated E for requested date from previous day;

=cut
my $psMSK = $c->fetch_ps( '1CC**LS1001', '040702', { TZ => ASKP::TZ->MSK, DLS => 1 } );
my $psUTC = $c->fetch_ps( '1CC**LS1001', '040702', { TZ => ASKP::TZ->UTC }           );

for(1..48) {
	printf "%6.3f\t%6.3f\t%6.3f\n", $psCET->val($_), $psMSK->val($_), $psUTC->val($_);
}

$c->close();
