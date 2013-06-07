package ASKP;

use 5.006000;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use ASKP ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	next_date
    cdate_le
	bases_list
    read_config
);

our $VERSION = '0.07';

require XSLoader;
XSLoader::load('ASKP', $VERSION);

package ASKP::TZ;

#
#	Offsets from Moscow time zone.
#	To be used in fetch_ps with extended parameters
#
use constant {
	MSK_PLUS_10 => 10,
	MSK_PLUS_9  =>  9,
	MSK_PLUS_8  =>  8,
	MSK_PLUS_7  =>  7,
	MSK_PLUS_6  =>  6,
	MSK_PLUS_5  =>  5,
	MSK_PLUS_4  =>  4,
	MSK_PLUS_3  =>  3,
	MSK_PLUS_2  =>  2,
	MSK_PLUS_1  =>  1,
	MSK         =>  0,
	EET         => -1,
	CET         => -2,
	WET         => -3,
	UTC         => -3,
	GWT         => -3,
	GWT_MINUS_1 => -4
};

package ASKP::PS;

sub fill_if
{
	my ($self, $other, $predicat) = @_;
	my $up = 0;

	for my $i (1..48) {
		if ( $predicat->( $self->{vals}{$i}, $other->{vals}{$i} ) ) {
			$self->val($i) = $other->val($i);
			$self->st ($i) = $other->st ($i);
			$up = 1;
		}
	}

	if ($up) {
		my $summ = 0;
		for my $i (1..48) {	$summ += $self->val($i); }
		$self->E  = $summ / 2;
		$self->ie = $self->E; # Note: may be a bug? Should we do this?

		return 1;
	}

	0;
}

sub dump
{
	my $self = shift;

	if ($self->{id}) {
		print "id:   $self->{id}\n";
	} else {
		print "Undefined id!\n";
	}

	print "date: $self->{date}\n";
	print "E: $self->{E}\n";
	print "TZ1: $self->{tz1} TZ2: $self->{tz2} TZ3: $self->{tz3} TZ4: $self->{tz4}\n";
	print "TZh: $self->{tz1h}, $self->{tz2h}, $self->{tz3h}, $self->{tz4h}\n";

	for my $i (1..48) {
		printf "\t%02s\t%3.6f\n", $self->st($i), $self->val($i);
	}
}

sub csv {
    my $self = shift;

	#
	# 1. arrange as array
	#
	my @a;
	for my $i (1..48) {
	  my $s = sprintf( "%.5f", $self->val($i) );
	  $s =~ s/\./,/g;
	  push @a, $s;
	}

	join ';', @a;
}

sub id : lvalue
{
	my $self = shift;
	$self->{id};
}


sub val : lvalue
{
	my ($self, $id) = @_;
	$self->{vals}{$id}{val};
}

sub st : lvalue
{
	my ($self, $id) = @_;
    $self->{vals}{$id}{st};
}


sub E : lvalue
{
	my $self = shift;
	$self->{E};
}

sub ie : lvalue
{
	my $self = shift;
	$self->{ie};
}

sub record
{
	my ($self, $id) = @_;

	return ($self->{vals}{$id}{val}, $self->{vals}{$id}{st});
}

sub apply($\&)
{
	my ($self, $f) = @_;

	map {
		my $arg     = $_;
		local $_    = $_->{val};
		$arg->{val} = $f->($_);
	} values %{ $self->{vals} };
}


use Scalar::Util qw/blessed looks_like_number/;
use Carp;
use Storable qw/dclone/;

use overload
	'+'        => \&add_ps,
	'-'        => \&sub_ps,
	'*'        => \&mul_ps,
	'/'        => \&div_ps,
# Comparsion oprators:
	'>'        => \&gt_ps,
	'<'        => \&lt_ps,
	'=='       => \&eq_ps,
	'>='       => \&ge_ps,
	'<='       => \&le_ps,
	'fallback' => 1;


sub ps_cmp(\@$)
{
	my ($op1, $op2, $is_swapped) = @{ $_[0] };
	my $f = $_[1];

	if ($is_swapped) {
		return $f->( $op2, $op1->{E} );
	} else {
		my $class = blessed $op2;
		if (  $class and
			( $class eq __PACKAGE__) ) {
			return $f->($op1->{E}, $op2->{E});
		} else {
			return $f->($op1->{E}, $op2 );
		}
	}
}


sub ps_op(\@$)
{
	my ($op1, $op2, $is_swapped) = @{ $_[0] };
	my $f = $_[1];

	my %tmp = %$op1;
	$tmp{vals} = dclone $op1->{vals};

	undef $tmp{id};

	my $e = 0;
	if (ref $op2 and blessed ($op2) eq __PACKAGE__) { # PS object

		while( my ($k,$v)  = each %{ $tmp{vals} }) {
			$v->{val} = $f->($v->{val}, $op2->{vals}{$k}{val} );

			if ($v->{st} eq ' ') {
				$v->{st} = $op2->{vals}{$k}{st};
			}

			if ($v->{st} ne 'N') {
				$e += $v->{val};
			}
		}

	} elsif (looks_like_number $op2) { # scalar

		foreach my $v (values %{ $tmp{vals} }) {
			$v->{val} = $f->( $v->{val}, $op2);
			$e += $v->{val};
		}
	}

	$tmp{E} = $e / 2;
	return bless \%tmp, __PACKAGE__;
}

sub le_ps
{
	return ps_cmp( @_, sub { $_[0] <= $_[1]} );
}

sub ge_ps
{
	return ps_cmp( @_, sub { $_[0] >= $_[1]} );
}


sub gt_ps
{
	return ps_cmp( @_, sub { $_[0] > $_[1]} );
}

sub lt_ps
{
	return ps_cmp( @_, sub { $_[0] < $_[1]} );
}

sub eq_ps
{
	return ps_cmp( @_, sub { $_[0] == $_[1]} );
}



sub add_ps
{
	return ps_op( @_, sub { $_[0] + $_[1]; } );
}

sub sub_ps
{
	if ($_[2]) {
		croak(q/'scalar - ps' operation not allowed (hint: try to swap operands)/);
	}

	return ps_op( @_, sub { $_[0] - $_[1]; } );
}

sub mul_ps
{
	if (blessed $_[0] and blessed $_[1]  and
		(blessed $_[0] eq blessed $_[1]) and
		(blessed $_[0] eq __PACKAGE__) ) {
		croak( q/'ps * ps' operation not allowed (hint: try to replace one of the arguments with scalar)/);
	}

	return ps_op( @_, sub { $_[0] * $_[1]; } );
}

sub div_ps
{
	my $class1 = blessed $_[0];
	my $class2 = blessed $_[1];

	if ($class1 and $class2  and
		($class1 eq $class2) and
		($class1 eq __PACKAGE__) ) {
		croak( q|'ps / ps' operation not allowed (hint: try to replace one of the arguments with scalar)|);
	}

	if ($_[2]) {
		croak( q|'scalar / ps' operation not allowed (hint: try to swap operands)|);
	}

	if (looks_like_number $_[1] and
		$_[1] == 0) {
		croak q|can't devide by zero!|;
	}

	return ps_op( @_, sub { $_[0] / $_[1]; } );
}


package ASKP::Counter;

sub coeff
{
	my $self = shift;
	return $self->{Kln};
}

sub k_line
{
	return coeff shift;
}

sub idl
{
	my $self = shift;
	return $self->{idl};
}

sub id
{
	my $self = shift;
	return $self->{id};
}

package ASKP::Period;
use Carp;

sub new
{
	my $class   = shift;
	my ($a, $b) = @_;

	my %tmp;

	$tmp{days} = { };

	( $tmp{from}, $tmp{to} ) = date_pair($a, $b);

	if (!($tmp{from} && $tmp{to})) {
		croak("Incorrect 'period' parameters, look at documentation!\n");
	#	      "    from => $tmp{from}, to => $tmp{to}" );
	}

	return bless \%tmp;
}

sub from
{
  my $self = shift;
  return $self->{from};
}

sub to
{
  my $self = shift;
  return $self->{to};
}

sub date_pair
{
	my ($a, $b)     = @_;

	my ( $from_y, $from_m, $from_d ) = (0, 0, 0);
	my (   $to_y,   $to_m,   $to_d ) = (0, 0, 0);

	my $is_period      = 0;

	my $now = time;

	if ($a =~ /(\d{2})(\d{2})(\d{2})/) {

		$is_period = 1;

		$from_y    = $1;
		$from_m    = $2;
		$from_d    = $3;

	} elsif ($a =~ /-(\d+)/ ) {
		$is_period = 0;

		$now -= 60 * 60 * 24 * $1;

		(undef, undef, undef, $to_d, $to_m, $to_y) = localtime $now;
		$to_m++;
		$to_y %= 100;

	} else {
		return (undef, undef);
	}

	if ($b =~ /(\d{2})(\d{2})(\d{2})/) {
		if (!$is_period) {
			croak("incompatible parameters: must be 'from', 'to' or '-offset', 'num'!");
		}

		$to_y = $1;
		$to_m = $2;
		$to_d = $3;

	} elsif ($b =~ /(\d+)/) {
		if ($is_period) {
			croak("incompatible parameters: must be 'from', 'to' or '-offset', 'num'!");
		}

		if (!$1) {
			croak("number of days in period offest can't be '0'");
		}

		$now -= 60 * 60 * 24 * ($1 - 1);

		(undef, undef, undef, $from_d, $from_m, $from_y) = localtime $now;
		$from_m++;
		$from_y %= 100;

	} else {
		return (undef, undef);
	}

	return (
		sprintf("%02d%02d%02d", $from_y, $from_m, $from_d ),
		sprintf("%02d%02d%02d",   $to_y,   $to_m,   $to_d ) );
}

sub day
{
	my ($self, $date) = @_;
	return $self->{days}{$date};
}

sub days
{
	my $self = shift;
	return $self->{days};
}

sub dump_csv {
  my $self  = shift;
  my $fname = shift;


  if ($fname) {
	open FD, '>' , $fname or die "Failed to open CSV file for output: $@\n";
  } else {
	*FD = *STDOUT;
  }

  my $ps;

  for my $d ( sort keys %{ $self->days() } ) {
	$ps = $self->day($d);
	if ($ps) {
	  print FD "$d;", $ps->csv(), "\n";
	} else {
	  my $s = "$d; 0,0";
	  $s .= ";0,0" for (2..48);
	  print FD "$s\n";
	}
  }

  if ($fname) {
	close FD;
  }
}

#package ASKP;
#package ASKP::ConnectionPtr;

sub fetch_days
{
	my $c                   = shift;
	my ( $id, $arg1, $arg2) = @_;

	my $p = ASKP::Period->new( $arg1, $arg2 );

	my $date = $p->{from};
	if (!$date) {
		warn("Starting date is undefined!");
		return undef;
	}

	while( ASKP::cdate_le( $date, $p->{to}) ) {
		my $ps = $c->fetch_ps( $id, $date );
		$p->{days}{$date} = $ps ? $ps : undef;
	} continue {
		$date = ASKP::next_date($date);
	}

	$p;
}

sub read_config($)
{
	my $fname = shift;
	open(CFG, '<', $fname) or die "Failed to open config file $!";

	my %h = ();
	while(my $line = <CFG>) {
		if ($line =~ /([0-9A-Za-z\*]{1,11}) ([A-Z0-9:\.@]*)\s*/) {
			push @{ $h{$2} }, $1;
		}
	}

	close CFG;

	return \%h;
}


1;
__END__

=head1 NAME

ASKP - Perl extension for  ASKP SSOD MGP system

=head1 SYNOPSIS

  use ASKP;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for ASKP, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. Karev, E<lt>lineum@mail.ruE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 2013 by A. Karev

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
