#!/sbin/env perl
#

use ASKP;
use strict;

if (not scalar @ARGV) {
	print "usage: conf.pl <config file>\n";
	exit;
}

#
# $hash_ref = read_config( "config file" );
#
# returns a hash reference (possibly empty) or undef in case of error.
#
# $hash_ref is in format:
#
# {
#   "database1" => [id1, id2, ..., idM],
#   "database2" => [id1, id2, ..., idN],
#   "database3" => [id1, id2, ..., idK]
# }
#
my $cfg = read_config($ARGV[0]) or die "Failed to read config file!";

while( my ($k, $v) = each %$cfg) {
	#
    # May make connection to this database in real script
    #
	print " Database: $k\n";

	foreach my $id (@$v) {
		print "    $id\n";
	}
}
