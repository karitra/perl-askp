# -*- coding: koi8-r -*-

package ASKP::Util;

use strict;
use warnings;

use DBI;
use Time::Local;
use Exporter;

our @ISA = qw[ Exporter ];

use constant ID_LEN        => 11;
use constant ASKP_DATE_LEN =>  6;
use constant SUMM_IDP => 8;

use constant VARS_NUM      => 48;

#
# Small time correction (in seconds)
#
use constant DELTA       => 20;
use constant SECS_IN_DAY => 60 * 60 * 24;

use constant DELETE_MODE => 'delete';
use constant CREATE_MODE => 'create';

use constant DELETE_MODE_INDEX => 0;
use constant CREATE_MODE_INDEX => 1;

use constant MAXIMUM_DAYS => 35;

use constant ERR_CODE     => 1310;


sub askp_date($);
sub read_list($);
sub delete_ps($$;$$$);
sub make_ps($$;$$$);
sub make_idp($$);
sub verify_date($$$);
sub compose_arr(\@$$$);

sub is_summator_grp($$);

sub proc_counter_interval($$$$$$$;$);

our @EXPORT=qw( proc_counter_interval read_list verify_days_number askp_date );

my @procs = (
			 \&delete_ps,
			 \&make_ps );


sub verify_date($$$) {
  my ($y, $m, $d) = @_;

  die "Год задан неверно: $y\n"   if $y < 2005 || $y > 2018;
  die "Месяц задан неверно: $m\n" if $m > 12   || $m < 1;
  die "Дата неверна: $d\n"        if $d > 31   || $d < 1;
}

sub verify_days_number($) {
  my $n = shift;
  die "Слишком много дней задано для удаления данных: $n\n" if ($n > MAXIMUM_DAYS);
}

sub is_id_valid($$) {
  my ($id, $map) = @_;

  ($_ eq $id) && return 1 for @$map;
  return 0;
}

sub askp_date($) {
  my (undef, undef, undef, $d, $m, $y) = localtime shift;
  $y += 1900;
  $m++;

  # print "  day => $d\n" .
  # 	    "month => $m\n" .
  # 	    " year => $y\n";

  verify_date($y,$m,$d);

  return sprintf "%02d%02d%02d", $y % 100 , $m, $d;
}

sub read_list($) {
  my $name = shift;

  open(my $file, '<', $name) or die "Сбой про попытки открыть файл с номерами счетчиков: $!";

  my @a;

  while(<$file>) {
	next if (/^#/);
	next if (/^[ ]*$/);

	chomp;
	push @a, $_;
  }

  return \@a;
}


sub compose_arr(\@$$$) {
  my ($val, $q, $fill, $num) = @_;

  my $s   = '';

  for my $i (0..$num - 1) {
	if ($val->[$i]) {
	  $s .= $q.c($val->[$i]).$q;
	} else {
	  $s .= $q.$fill.$q;
	}
	if ($i < $num - 1) {
	  $s .= ', ';
	}
  }

  return "{$s}";
}


sub delete_ps($$;$$$) {
  my ($db, $idp) = @_;

  my $id = substr( $idp, 0, ID_LEN );
  my  $d = substr( $idp, ID_LEN, ASKP_DATE_LEN );

  print "Удаление записи [$id:$d]\n";

  my $r = $db->do('delete from askp_ps where idp = ?',
		  {},
		  $idp ) or die "Сбой при удалении данных их базы: " . $db->errstr . "\n";

  print "Запись не удалена, так как отсутствует в базе данных\n" if ($r != 1);
}

sub make_ps($$;$$$) {
  my ($db, $id, $y, $m, $d) = @_;


  my @empty = ();

  # my $date     = "$y-$m-$d";
  my $real_id  = substr $id, 0, ID_LEN;
  my $date_beg = sprintf "%02d%02d%02d", $y % 100, $m,  1;

  print "Создание записи [$real_id:$date_beg]\n";

  my $ps  = compose_arr( @empty, '', '0', 48 );
  my $st  = compose_arr( @empty, '', '0', 48 );

  my $tz  = compose_arr( @empty, '', '0', 4 );
  my $tzs = compose_arr( @empty, '', '0', 4 );
  my $tzh = compose_arr( @empty, '', '0', 4 );

  # print "$ps\n";
  # print "$st\n";

  # print "$tz\n";
  # print "$tzs\n";
  # print "$tzh\n";

  $db->do('insert into askp_ps(idp, date_beg, p, s, tz, tzs, tzh, ie) values(?,?,?,?,?,?,?,0)',
		  {},
		  $id, $date_beg, $ps, $st, $tz, $tzs, $tzh ) or warn "Сбой при добавлении данных в базу: " . $db->errstr . "\n";
}


sub make_idp($$) {
  my ($idp, $date) = @_;

  my $psid = $idp . $date;

  die "Неверно заданы номер счетчика и дата для удаления: $idp $date" if (length($psid) != ID_LEN + ASKP_DATE_LEN);

  $psid;
}

use constant SUMM_IDP => 8;

sub is_summator_grp($$) {

  use warnings;

  my ($db, $id) = @_;

  my $summ_id = substr $id, 0, SUMM_IDP;

  die "В идентификаторе сумматора [$summ_id] должно быть 8 символов\n" if (length( $summ_id) < SUMM_IDP);

  my $ref = $db->selectrow_hashref( 'select * from askp_summ where idp = ?',
								 {},
								 $summ_id );


  die "Ошибка! Такого сумматора [$summ_id] нет в базе данных\n" unless $ref;

#  print "$summ_id => dtyp => $ref->{dtyp}\n";

  $ref->{dtyp} == 2 ? 1 : 0;
}

sub proc_counter_interval($$$$$$$;$) {
  my ($db, $y, $m, $d, $n, $mode, $ids, $allowed) = @_;

  my @months = qw/Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь/;
  my @dn     = qw/день дня дней/;

  my $t_end   = timelocal 0, 30, 5, $d, $m-1, $y;
  my $t_start = $t_end - SECS_IN_DAY * $n - DELTA;

  my $askp_date;
  my $selector;


  if ($mode eq DELETE_MODE) {
	$selector = DELETE_MODE_INDEX;
  } elsif ($mode eq CREATE_MODE) {
	$selector = CREATE_MODE_INDEX;
  } else {
	die "Неправильно задан режим работы! Допустимые режимы: create, delete\n";
  }

  my $dnum = 0;
  for my $id (@$ids) {

	if ($mode eq DELETE_MODE && defined $allowed) {
	  die "Счетчик $id отсутствует в списке разрешенных!\n" unless is_id_valid( $id, $allowed );
	}

	if ($mode eq CREATE_MODE) {
	  next if is_summator_grp($db, $id);
	}

	if ($n+1 <= 1) {
	  $dnum = 0;
	} elsif ($n+1 > 1 and $n+1 < 5) {
	  $dnum = 1;
	} else {
	  $dnum = 2;
	}

	print "Удаление записей для счетчика $id\n" if $mode eq DELETE_MODE;
	print  "Создние записей для счетчика $id\n" if $mode eq CREATE_MODE;

	printf "начиная с даты: %02d %02s %02d (ДД МММ ГГГГ), %d %s (в прошлое)\n", $d, $months[$m-1], $y, $n+1, $dn[$dnum];

	for(my $current = $t_start;  $current <= $t_end; $current += SECS_IN_DAY) {
	  $askp_date = askp_date($current);
	  $procs[$selector]->( $db, make_idp($id, $askp_date), $y, $m, $d);
	}
  }
}
