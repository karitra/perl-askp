use ASKP;

print "ASKP perl module, version: ", $ASKP::VERSION, "\n";

my $c    = ASKP::Connection->new('BASES@localhost:5432') || die "Failed to open database session!\n";
my $date = '040701';
my $ps   = $c->fetch_ps('1BE****Gs06', $date)            || die "Failed to fetch ps!\n";

print "ID: $ps->{id} DATE: $ps->{date}\n";
print "E:  $ps->{E}\n";

foreach $i (1..48) {
	printf "\t%2d: %6.4f\n", $i, $ps->val($i);
}

$date++;
my ($id1, $id2) = ( '1BE****Gs06', '1BE****Gs08' );

my $ps1 = $c->fetch_ps( $id1, $date) || die "Failed to fetch ps1: $id1!\n";
my $ps2 = $c->fetch_ps( $id2, $date) || die "Failed to fetch ps2: $id2!\n";
my $scale = 2.3;

my $rps = $ps1 + $ps2 * $scale;

for my $i (1..48) {
	printf "%3.6f + %3.6f = %3.6f\n", $ps1->val($i), $ps2->val($i) * $scale, $rps->val($i);
}

#
# 'apply' example:
# 
# apply supplied subroutine to every PS value and store it back 
# in hash under the same index:
#
# val[i] = sub(val[i]);
#
$rps->val(1) = 64;

$rps->apply( sub {sqrt} );
$rps->apply( sub { my $val = shift; $val *= 2; return $val; } );

$rps->dump;

#
# Counter parameters
#
my $cnt = $c->fetch_cnt('1BE****Gs06' ) || die "Failed to fetch counter data!\n";
print "ID: $cnt->{id} NAME: $cnt->{name}\n";
print "K_len: ", $cnt->coeff(), ", idl: ", $cnt->idl(), "\n";

#
# Formula example:
#
my $A = $c->fetch_ps( $cnt->idl(), $date );
my $B = $c->fetch_ps( $cnt->id (), $date );

my $Brd;

if ($A - $B > 0) {
	# Note: formula taken from 'dbc'
    #   $Brd will contain results of formula evaluation, but 
    #   $Brd->{id} is undefined, you must set it manually!
	$Brd = $A - ($A - $B) * $cnt->coeff();
# or:
# 	$Brd = $A - ($A - $B) * $cnt->k_line();
} else { # redloss
	$Brd = $A;
}

use List::Util qw/reduce/;
print "A(src): $A->{E} B(dst): $B->{E}\n";
print "Results on board: E = $Brd->{E}\n";

my $Esumm = reduce { $a + $b->{val} } 0, values %{ $Brd->{vals} };
$Esumm /= 2;
print "Esumm (recount): $Esumm\n";

for my $i (1..48) {
	printf "\t%02d: SRC %6.3f DST %6.3f BRD %6.3f %s\n", $i, $A->val($i), $B->val($i), $Brd->val($i), $Brd->st($i);
}


#
# store_ps/delete_ps
#
# For usage example: look at t/ASKP.t
#
# $c->store_ps( $ps );
# $c->store_ps( $ps, "1BE..." );
# $c->store_ps( $ps, "1BE...", "110101" );
#
# $c->delete_ps( $ps->{id}   );
# $c->delete_ps( $ps->id() );
#
#
my $id_request = '1BE';
print "\n", "Selecting counters for ID: $id_request...\n";
my $list = $c->fetch_list($id_request);
foreach $item (@$list) {
	print "\t$item\n";
}

#
# 'date' examples
#
sub cmp_dates
{
	my ( $dateA, $dateB ) = @_;

	if (cdate_le( $dateA, $dateB)) {
		print "$dateA <= $dateB\n" ;
	} else {
		print "$dateA > $dateB\n" ;
	}
}

my $date2 = '040227';
my $date3 = next_date($date2);
print "Next date: $date2\n";
cmp_dates $date2, $date3;
cmp_dates $date3, $date2;


$c->close();
