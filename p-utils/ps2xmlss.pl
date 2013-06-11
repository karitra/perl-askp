#!/usr/bin/env perl
# -*- coding: koi8-r -*-

use lib qw(. ./ASKP);

use ASKP;
use ASKP::Util;
use ASKP::XSS;

use Pod::Usage;
use Time::Local;

sub last_month_day($$);

do 'opt.pl' or die "���������� ��������� ��������� ��������� ������: $@\n";

if ($Opts::help or ! $Opts::dbname or not ($Opts::id or $Opts::fname) ) {
  pod2usage(-verbose => 1);
  exit ERR_CODE;
}

if ($Opts::id and $Opts::fname) {
  pod2usage(-verbose => 1);
  exit ERR_CODE;
}

if ($Opts::num < 1) {
  pod2usage(1);
  exit ERR_CODE;
}



my @ids;

if ($Opts::id) {
  push @ids, $Opts::id;
} elsif ($Opts::fname) {
  push @ids, @{ read_list $Opts::fname };
} else {
  die "����� ������ ���� �������������, ���� ��� ����� ��� ���������� ������ ���������������\n";
}

$Opts::num--;
verify_days_number($Opts::num);

use constant SECONDS_PER_DAY => 60 * 60 * 24;

sub last_month_day($$) {
  my ($month, $year) = @_;

  my $middle = timelocal 0, 30, 5, 10, $month-1, $year;
  my $next_middle = $middle + 30 * SECONDS_PER_DAY;
  my ($d,$m,$y) = (localtime $next_middle)[3, 4, 5];

  my $beg_of_next    = timelocal 0, 30, 5, 1, $m, $y;
  my $end_of_cur_mon = $beg_of_next - SECONDS_PER_DAY;

  return (localtime $end_of_cur_mon)[3];
}

my $t_end   = timelocal 0, 30, 5, last_month_day( $Opts::month, $Opts::year), $Opts::month-1, $Opts::year;
my $t_start = timelocal 0, 30, 5, 1, $Opts::month-1, $Opts::year;;

my $start_date = askp_date( $t_start );
my   $end_date = askp_date( $t_end   );



my @parr;

my $c    = ASKP::Connection->new($Opts::dbname) || die "���� ��� ����������� � ���� ������ $Opts::dbname!\n";
for my $id (@ids) {
  my $pd   = ASKP::Period::fetch_days( $c, $id, $start_date, $end_date) || die "���� ��� ��������� ������ ��� $id:[$start_date, $end_date]\n";
  push @parr, $pd if $pd;
}
$c->close();

my $xss = parr2xss(@parr);

if ($Opts::xmlfile) {
  open( my $f, "| iconv -f koi8-r -t utf8 > $Opts::xmlfile" ) or
	die '���������� ������� ���� ��� ������ ������!';
  print $f $xss;
} else {
  print $xss;
}

__END__

=head1 NAME

ps2xmlss - ����� �������� ����������� ���������� � ������� XML Spreadsheet

=head1 SYNOPSYS

ps2xmlss.pl [���������]

 ���������:

  -db        ��� ���� ������
  -id        ������������� �ޣ�����
  -list      ��� ����� ��� ���������� ���������������

  -year      ��� (2009 �� ���������)
  -month     ����� (������ �� ���������)

  -xml       ��� XML �����

=head1 OPTIONS

=over 8

=item B<-db>

��� ���� ������, � ������� ������� �������(�).
������������ ��������.

=item B<-id>

������������� ��������, ��� �������� ����� ������� ������.
������������ ��������. ����� ���� ����� ���� -list, ���� -id, ��
�� ��� ��������� ������������!

=item B<-list>

��� ����� ��� ���������� ��������������� ���������. ����� ���� ����� ���� -list, ���� -id, ��
�� ��� ��������� ������������!

=item B<-year>

����� ����: ���. ������������ ��������.

=item B<-month>

����� ����: �����. ������������ ��������.

=item B<-xml>

��� �����, ���� ����� ������� ���������. ���� ��� ����� �� ������, ��������� ����� ������� �� �����.

=cut
