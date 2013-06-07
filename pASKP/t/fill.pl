#!/usr/bin/env perl
#

use warnings;
use strict;

use ASKP;

sub fill(\@\@$)
{
	my $cnt      = shift;
	my $upd_from = shift;
	my $p        = shift;

	my $c     = ASKP::Connection->new( $cnt     ->[0]  ) or die "Failed to connect to database: '$cnt->[0]'\n";
	my $cupd  = ASKP::Connection->new( $upd_from->[0]  ) or die "Failed to connect to database: '$upd_from->[0]'\n";

	print "Date interval (YYMMDD) set from $p->{from} to $p->{to}\n";

	my $date = $p->{from};
	while( cdate_le( $date, $p->{to} ) ) {

		print "Date: $date\n";
		my $ps_src = $c   ->fetch_ps( $cnt     ->[1], $date ) or print "\tNo data for $cnt->[1]\n"      and next;
		my $ps_upd = $cupd->fetch_ps( $upd_from->[1], $date ) or print "\tNo data for $upd_from->[1]\n" and next;

		if ($ps_src->fill_if( $ps_upd, sub { $_[0]->{st} eq '' and $_[1]->{st} ne ''} )) {
			print "Updating PS for id: $ps_src->{id}\n";
			$c->store_ps( $ps_src );
		}

	} continue {
		$date = next_date $date;
	}

	$c   ->close();
	$cupd->close();
}


=pod

 ������ ������������� ��������� fill
 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

 ��� �ޣ����: ���� ��� �������� ������ = nodata, ��ң� ������ �� �ޣ����� �� ������ �������
 ������ ���� ��� ������ �� nodata.
=cut
#my @our_cnt1         = ( 'BASES', '1BE****Gx06' );

=pod

 �ޣ���� �� ������ ������� 

=cut
#my @update_from_cnt2 = ( 'BASES', '1BE****Gs06' );

=pod

 new ASKP::Period -1, 7;

 -1 - ��������� ������� ����� ����� ��������� �� �������� ���, 
      ����� �������� ��������� ���������. ����� ����� �� ������������, 
       �� � ��� �������. � ������� ����� ��������� ����.
 7 - ������� ��� ���� ����� ��������� �� ��������� ��������� ���������,
      ��� ��������� ������ ��������� (������� ���� ��������� ���������).

	��������� ����� ������� ������ ��������� � ������� ���� (YYDDMM):
    
	my $period = new ASKP::Period '040701', '040715';

=cut      
#my $period = new ASKP::Period '040701', '040715';
#my $period = new ASKP::Period -1, 10;



=pod

 fill(@our_cnt1, @update_from_cnt2, $period);

 @our_cnt1         - ��� �ޣ���� � ���� ������� ('����', 'ID' );
 @update_from_cnt2 - cޣ���� �� ��������������� ������� � ���� ������� ('����', 'ID' );
 $period           - ��������, ��������� ���� ��������, ������ �� ������� ����� 
	                 ���������� �ޣ�����;

=cut
#fill (@our_cnt1, @update_from_cnt2, $period);


die("usage: fill <base_to_update> <id_to_update> <base> <id> <period_param1> <period_param2>\n")
	if ($#ARGV+1 ne 6);

my @our_cnt1         = ($ARGV[0], $ARGV[1]);
my @update_from_cnt2 = ($ARGV[2], $ARGV[3]);

fill (@our_cnt1, @update_from_cnt2, new ASKP::Period( $ARGV[4], $ARGV[5]) );

