#!/usr/bin/env perl
# -*- coding: koi8-r -*-

use lib qw(. ./ASKP);

use ASKP;
use ASKP::Util;
use ASKP::XSS;

use Pod::Usage;
use Time::Local;

sub last_month_day($$);

do 'opt.pl' or die "Невозможно прочитать параметры командной строки: $@\n";

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
  die "Нужно задать либо идентификатор, либо имя файла для считывания списка идентификаторов\n";
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

my $c    = ASKP::Connection->new($Opts::dbname) || die "Сбой при подключении к базе данных $Opts::dbname!\n";
for my $id (@ids) {
  my $pd   = ASKP::Period::fetch_days( $c, $id, $start_date, $end_date) || die "Сбой при получении данных для $id:[$start_date, $end_date]\n";
  push @parr, $pd if $pd;
}
$c->close();

my $xss = parr2xss(@parr);

if ($Opts::xmlfile) {
  open( my $f, "| iconv -f koi8-r -t utf8 > $Opts::xmlfile" ) or
	die 'Невозможно открыть файл для вывода данных!';
  print $f $xss;
} else {
  print $xss;
}

__END__

=head1 NAME

ps2xmlss - Вывод значений получасовых интервалов в формате XML Spreadsheet

=head1 SYNOPSYS

ps2xmlss.pl [параметры]

 Параметры:

  -db        имя базы данных
  -id        идентификатор счётчика
  -list      имя файла для считывания идентификаторов

  -year      год (2009 по умолчанию)
  -month     месяц (январь по умолчанию)

  -xml       имя XML файла

=head1 OPTIONS

=over 8

=item B<-db>

Имя база данных, в которой записан счетчик(и).
Обязательный параметр.

=item B<-id>

Идентификатор счетчика, для которого нужно вывести данные.
Обязательный параметр. Может быть задан либо -list, либо -id, но
не оба параметра одновременно!

=item B<-list>

Имя файла для считывания идентификаторов счетчиков. Может быть задан либо -list, либо -id, но
не оба параметра одновременно!

=item B<-year>

Выбор даты: год. Обязательный параметр.

=item B<-month>

Выбор даты: месяц. Обязательный параметр.

=item B<-xml>

Имя файла, куда будет записан результат. Если имя файла не задано, результат будет выведен на экран.

=cut
