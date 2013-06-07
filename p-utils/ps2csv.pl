#!/usr/bin/env perl
# -*- coding: koi8-r -*-

use lib qw(. ./ASKP);

use ASKP;
use ASKP::Util;

use Pod::Usage;
use Time::Local;


do 'opt.pl' or die "���������� ��������� ��������� ��������� ������: $@\n";

if ($Opts::help or ! $Opts::dbname or not ($Opts::id)) {
  pod2usage(-verbose => 1);
  exit ERR_CODE;
}

if ($Opts::num < 1) {
  pod2usage(1);
  exit ERR_CODE;
}

$Opts::num--;
verify_days_number($Opts::num);

my $t_end   = timelocal 0, 30, 5, $Opts::day, $Opts::month-1, $Opts::year;
my $t_start = $t_end - ASKP::Util::SECS_IN_DAY * $Opts::num - ASKP::Util::DELTA;

my $start_date = askp_date( $t_start );
my   $end_date = askp_date( $t_end   );

my $c    = ASKP::Connection->new($Opts::dbname) || die "���� ��� ����������� � ���� ������ $Opts::dbname!\n";
my $pd   = ASKP::Period::fetch_days( $c, $Opts::id, $start_date, $end_date) || die "���� ��� ��������� ������!\n";

if ($Opts::outfile) {
  $pd->dump_csv($Opts::outfile);
} else {
  $pd->dump_csv();
}

$c->close();

__END__

=head1 NAME

ps2csv - ����� �������� ����������� ���������� � ������� CSV

=head1 SYNOPSYS

ps2csv.pl [���������]

 ���������:

  -db        ��� ���� ������
  -id        ������������� �ޣ�����
  -list      ��� ����� ��� ���������� ���������������

  -year      ��� (2009 �� ���������)
  -month     ����� (������ �� ���������)
  -day       ����� (����, �� ��������� 1 ����� ������)
  -num       ���������� ���� (3 ��� �� ���������)
  -csv       ��� CSV �����

=head1 OPTIONS

=over 8

=item B<-db>

��� ���� ������, � ������� ������� �������.
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

=item B<-day>

����� ����: �����. ������������ ��������.

=item B<-num>

���������� ����, ������� ������������� �� �������� ���� "� �������". � ���������� ����� ������� ���������, ���������� �������� ����, ����� ������� �������� ����������� ���������� ��� ���������� �ޣ�����. ���������� ���� ������ ���� ������ 0.

������������ ��������.

=item B<-csv>

��� �����, ���� ����� ������� ���������. ���� ��� ����� �� ������, ��������� ����� ������� �� �����.

=cut
