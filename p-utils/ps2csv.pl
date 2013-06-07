#!/usr/bin/env perl
# -*- coding: koi8-r -*-

use lib qw(. ./ASKP);

use ASKP;
use ASKP::Util;

use Pod::Usage;
use Time::Local;


do 'opt.pl' or die "Невозможно прочитать параметры командной строки: $@\n";

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

my $c    = ASKP::Connection->new($Opts::dbname) || die "Сбой при подключении к базе данных $Opts::dbname!\n";
my $pd   = ASKP::Period::fetch_days( $c, $Opts::id, $start_date, $end_date) || die "Сбой при получении данных!\n";

if ($Opts::outfile) {
  $pd->dump_csv($Opts::outfile);
} else {
  $pd->dump_csv();
}

$c->close();

__END__

=head1 NAME

ps2csv - Вывод значений получасовых интервалов в формате CSV

=head1 SYNOPSYS

ps2csv.pl [параметры]

 Параметры:

  -db        имя базы данных
  -id        идентификатор счётчика
  -list      имя файла для считывания идентификаторов

  -year      год (2009 по умолчанию)
  -month     месяц (январь по умолчанию)
  -day       число (дата, по умолчанию 1 число месяца)
  -num       количество дней (3 дня по умолчанию)
  -csv       имя CSV файла

=head1 OPTIONS

=over 8

=item B<-db>

Имя база данных, в которой записан счетчик.
Обязательный параметр.

=item B<-id>

Идентификатор счетчика, для которого нужно удалить данные.
Обязательный параметр. Может быть задан либо -list, либо -id, но
не оба параметра одновременно!

=item B<-list>

Имя файла для считывания идентификаторов счетчиков. Может быть задан либо -list, либо -id, но
не оба параметра одновременно!

=item B<-year>

Выбор даты: год. Обязательный параметр.

=item B<-month>

Выбор даты: месяц. Обязательный параметр.

=item B<-day>

Выбор даты: число. Обязательный параметр.

=item B<-num>

Количество дней, которое отсчитывается от заданной даты "в прошлое". В полученном таким образом интервале, включающем заданную дату, будут удалены значения получасовых интервалов для указанного счётчика. Количество дней должно быть больше 0.

Обязательный параметр.

=item B<-csv>

Имя файла, куда будет записан результат. Если имя файла не задано, результат будет выведен на экран.

=cut
