#!/usr/bin/env perl
# -*- coding: koi8-r -*-

package ASKP::XSS;

use 5.008;

use strict;
use warnings;

use List::Util qw/sum/;
use Scalar::Util qw/looks_like_number/;

use Exporter;

our @ISA=qw[Exporter];

use constant RIGHT_BRD  => 0x01;
use constant BOTTOM_BRD => 0x02;


my $test = <<'TEST';
050701;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40
050703;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40
050730;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40;1,10;2,02;3,30;4,40
TEST

sub xss_val_row($$\@);
sub xss_val_cell($$);
sub day_from_date($);

sub xss_logo($);

sub xss_hdr();
sub xss_hdr_cols();
sub xss_tail();

sub xss_na_row($);
sub xss_na_cell();

sub xss_row_hdr($$);
sub xss_row_tail();
sub xss_empty_row();

sub href2xss($);
sub csv2href($);

sub ps2xss($$);
sub period2xss($);
sub parr2xss(\@);

our @EXPORT = qw/ parr2xss /;

sub xss_hdr_cols() {
  my $r = << 'COLS';
  <ss:Row>
    <ss:Cell/>
	<ss:Cell/>
COLS

  my @cells;
  for (1..24) {
	my $s = sprintf "%d:00", $_;
	push @cells, "<ss:Cell ss:StyleID=\"2\"><ss:Data ss:Type=\"String\">$s</ss:Data></ss:Cell>";
  }

  $r .= "@cells";
  $r .= '<ss:Cell ss:StyleID="2"/>';
  $r .= "</ss:Row>\n";
}


sub csv2href($) {
  my $csv = shift;

  my @lines = split /\n/, $csv;

  my %h;

  for (@lines) {
	my @v = split /;/;
#	print $v[0], " ", day_from_date( $v[0] ), "\n";

	{
	  # local $, = "\n";
	  # print  "Array: ", map {$_ =~ s/,/\./; $_} @v[1..$#v];
	  my @vals = map {s/,/\./; $_} @v[1..$#v];
	  my @hv;
	  for(0..23) {
		push @hv, ($vals[$_ * 2] + $vals[$_ * 2 + 1]) / 2;
	  }

	  push @hv, sum @hv;

	  $h{day_from_date $v[0]} = [ @hv ];
	}
  }

  \%h;
}

sub href2xss($) {
  my $data = shift;

  my $xss  = xss_hdr . xss_hdr_cols;

  $xss .= xss_logo('');

  for my $d (1..31) {
	if (not exists $data->{$d}) {
	  $xss .= xss_na_row($d);
	} else {
#	  print "Valrow => $data->{$d}";
	  $xss .= xss_val_row($d, 0, @{ $data->{$d} });
	}
  }

  $xss .= xss_tail;
}


sub parr2xss(\@) {
  my $pref = shift;

  my $xss = xss_hdr;

  my $ps;
  for my $p (@$pref) {
	$xss .= xss_logo( $p->name() ) . xss_hdr_cols;
	$xss .= period2xss($p);
  }

  return $xss .= xss_tail;
}


sub ps_add_summ($\@) {
  my ($ps, $sum) = @_;
  $sum->[$_] += (($ps->val($_ * 2 + 1) + $ps->val($_ * 2 + 2)) / 2) for(0..23);
}

sub ps_final_summ(\@) {
  my $sum = shift;
  $sum->[24] = sum @$sum[0..23];
}


sub period2xss($) {
  my $p = shift;

  my @dates = sort keys %{ $p->days() };

  return "" if ! @dates;

  my $date_base = (substr $dates[0], 0, 4);

  my ($xss, $ps, $date);

  my @col_summs = map 0, 1..24;

  for my $d (1..31) {
	$date = sprintf "$date_base%02d", $d;
	$ps   = $p->day($date);

	if ($ps) {
	  $xss .= ps2xss($d, $ps);
	  ps_add_summ($ps, @col_summs);
	} else {
	  $xss .=  xss_na_row $d;
	}

  }

  ps_final_summ(@col_summs);

  $xss .= xss_val_row "Сумма", (BOTTOM_BRD | RIGHT_BRD), @col_summs;
  $xss .= xss_empty_row;

  return $xss;
}



sub ps2xss($$) {
  my ($d, $ps) = @_;

  my $vs = '';

  my ( @hh, @hr );

  push @hh, $ps->val($_) for (sort {$a <=> $b}  keys %{$ps->{vals}});
  push @hr, ($hh[$_ * 2] + $hh[$_ * 2 + 1]) / 2 for (0..23);
  push @hr, sum @hr;

  $vs .= xss_val_row $d, ( RIGHT_BRD ), @hr;
}

sub day_from_date($) { int $1 if shift =~ /\d{4}(\d{2})/; }


sub xss_empty_row() {
  return '<ss:Row/>';
}

sub xss_val_row($$\@) {
  my ($day, $flags, $vals) = @_;

#  my $vs = xss_row_hdr( from_date $day );
  my $vs = xss_row_hdr $day, $flags ;
  $vs .= xss_val_cell ($_, $flags) for (@$vals);
  $vs .= xss_row_tail;
}

sub xss_val_cell($$)  {
  my $v     = shift;
  my $flags = shift;

  my $styleCell  = 'CellStyle';

  if ($flags & RIGHT_BRD) {
	$styleCell .= 'Rbrd';
  }

  if ($flags & BOTTOM_BRD) {
	$styleCell .= 'Bbrd';
  }

  return << "VALS";
    <ss:Cell ss:StyleID=\"$styleCell\">
	  <ss:Data ss:Type=\"Number\">$v</ss:Data>
    </ss:Cell>
VALS
}

sub xss_hdr() {
  return  << 'HDR';
<?xml version="1.0"?>
<ss:Workbook xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
  <ss:Styles>
    <ss:Style ss:ID="1">
      <ss:Font ss:Bold="1"/>
      <ss:Interior ss:Color="#ffffcc" ss:Pattern="Solid"/>
      <ss:Borders>
       <ss:Border ss:Position="Left"   ss:Weight="2" ss:LineStyle="Continuous"/>
       <ss:Border ss:Position="Right"  ss:Weight="2" ss:LineStyle="Continuous"/>
       <ss:Border ss:Position="Top"    ss:Weight="2" ss:LineStyle="Continuous"/>
       <ss:Border ss:Position="Bottom" ss:Weight="2" ss:LineStyle="Continuous"/>
      </ss:Borders>
    </ss:Style>
    <ss:Style ss:ID="CellStyleRbrd">
      <ss:Borders>
       <ss:Border ss:Position="Right"  ss:Weight="1" ss:LineStyle="Continuous"/>
      </ss:Borders>
    </ss:Style>
    <ss:Style ss:ID="CellStyleRbrdBbrd">
      <ss:Borders>
       <ss:Border ss:Position="Bottom" ss:Weight="1" ss:LineStyle="Continuous"/>
       <ss:Border ss:Position="Right"  ss:Weight="1" ss:LineStyle="Continuous"/>
      </ss:Borders>
    </ss:Style>
    <ss:Style ss:ID="2" ss:Parent="1">
      <ss:Alingment ss:Horizontal="Center"/>
    </ss:Style>
    <ss:Style ss:ID="red1">
      <ss:Font ss:Color="red"/>
      <ss:Borders>
       <ss:Border ss:Position="Right"  ss:Weight="1" ss:LineStyle="Continuous"/>
      </ss:Borders>
    </ss:Style>
  </ss:Styles>
  <ss:Worksheet ss:Name="РБ-РФ">
    <ss:Table>
HDR
}

sub xss_logo($) {
  my $name = shift;

  $name = '' unless $name;

  return << "LOGO";
      <ss:Row/>
      <ss:Row><ss:Cell/><ss:Cell/>
              <ss:Cell>
                 <ss:Data ss:Type="String">$name</ss:Data>
              </ss:Cell>
      </ss:Row>
      <ss:Row/>
LOGO
}

sub xss_tail() {
  return  << 'TAIL';
    </ss:Table>
  </ss:Worksheet>
</ss:Workbook>
TAIL
}

sub xss_row_hdr($$) {

  my $day   = shift;
  my $flags = shift;

  my $type     = looks_like_number $day ? 'Number' : 'String';
  my $styleRow = 'CellStyle';

  if ($flags & RIGHT_BRD) {
	$styleRow .= 'Rbrd';
  }

  if ($flags & BOTTOM_BRD) {
	$styleRow .= 'Bbrd';
  }

  return << "RHDR";
    <ss:Row>
      <ss:Cell/>
      <ss:Cell ss:StyleID=\"1\">
        <ss:Data ss:Type=\"$type\">$day</ss:Data>
      </ss:Cell>
RHDR
}

sub xss_row_tail() {
  return <<"RTAIL";
    </ss:Row>
RTAIL
}

sub xss_na_cell() {
  return << 'NACELL';
      <ss:Cell ss:StyleID="red1">
        <ss:Data ss:Type="String">н/д</ss:Data>
      </ss:Cell>
NACELL
}

sub xss_na_row($) {
  my $d = shift;

  my $row = xss_row_hdr($d, RIGHT_BRD);
  $row .= xss_na_cell() for (1..25);
  $row .= xss_row_tail;

  $row;
}


#my $h = csv2href($test);
#my $xss = href2xss($h);

#print $xss;

#my @a = split /\n/, $test;
#print day_from_date('040502') . "\n";
