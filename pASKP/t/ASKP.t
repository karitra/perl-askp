# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl ASKP.t'

#########################

# change 'tests => 2' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 11 };
use ASKP;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
ok(
		sub {
		  my $date1 = '041231';

		  if ('050101' ne next_date($date1) ) {
			return 0;
		  } elsif (!cdate_le( $date1, $date1 )) {
			return 0;
		  } elsif (!cdate_le( $date1, next_date($date1) ) ) {
			return 0;
		  } elsif (cdate_le( next_date($date1), $date1) ) {
			return 0;
		  }

		  return 1;
		}
);

#
# Gets databases list from .dbcrc file which is parsed on module startup
#
ok( scalar bases_list()  );

#
# Note:
# - counter ID must be adjusted on host machine to complement the ids in
#   database;
# - choose counter with CET time set in summator;
#
my ($id1, $date) =  ('1BE****Gs04', '040701');
my $id2 = '1BE****Gs07';

#my $base         =   'BASES@localhost:5432';
my $base         =   'BASES';


my $c = ASKP::Connection->new( $base );


ok( 
   sub {
	 if (!$c) {
	   return 0;
	 }

	 my  $cnt = $c->fetch_cnt( $id1 );
	 if (!$cnt ) {
	   return 0;
	 }

	 if ($cnt->{id} ne  $id1 ) {
	   return 0;
	 }

	 my $ps = $c->fetch_ps( $id2, ++$date );
	 if (!$ps) {
	   return 0;
	 }

	 if ($ps->{id} ne   $id2 || $ps->{date} ne $date ) {
	   return 0;
	 }

	 return 1;
   } );

#
# Extended fetch_ps tests
#
my ($id3, $date3) = ('1BE****Gs06', '040702');
ok(
   sub {
	 my $psA = $c->fetch_ps($id3, $date3 );
	 # next day
	 $date3++;
	 my $psB = $c->fetch_ps($id3, $date3 );
	 my $psC = $c->fetch_ps($id3, $date3, { Diff => 1 } );
	 if ($psB->E - $psA->E != $psC->E) {
	   return 0;
	 }


	 my $psE = $c->fetch_ps($id3, $date3, { TZ   => ASKP::TZ->CET                      } );
	 if (!$psE) {
	   return 0;
	 }

	 if  ($psE->val( 1) != $psB->val( 1) ||
		  $psE->val( 2) != $psB->val( 2)) {
	   return 0;
	 }

	 if  ($psE->val( 1) != $psC->val( 1) ||
		  $psE->val( 2) != $psC->val( 2)) {
	   return 0;
	 }


	 if  ($psE->val(46) != $psB->val(46) ||
		  $psE->val(47) != $psB->val(47)) {
	   return 0;
	 }

	 if  ($psE->val(46) != $psC->val(46) ||
		  $psE->val(47) != $psC->val(47)) {
	   return 0;
	 }

	 return 0 unless $c->fetch_ps($id3, $date3, { TZ   => ASKP::TZ->CET, DLS => 1            } );
	 return 0 unless $c->fetch_ps($id3, $date3, { TZ   => ASKP::TZ->CET, DLS => 1, Diff => 1 } );
	 return 0 unless $c->fetch_ps($id3, $date3, { TZ   => ASKP::TZ->MSK, DLS => 1            } );

	 $psE    = $c->fetch_ps($id3, $date3, { TZ   => ASKP::TZ->MSK                      } );
	 if (!$psE) { return 0; }

	 if ( $psE->val(5)  ne $psB->val(1)  ||
		  $psE->val(6)  ne $psB->val(2)  ||
		  $psE->val(47) ne $psC->val(43) ||
		  $psE->val(48) ne $psC->val(44) ) {
	   return 0;
	 }

	 return 0 unless $c->fetch_ps($id3, $date3, { TZ   => ASKP::TZ->MSK, DLS => 1, Diff => 1 } );
	 return 0 unless $c->fetch_ps($id3, $date3, { TZ   => ASKP::TZ->UTC, DLS => 1, Diff => 1 } );

	 $psE    = $c->fetch_ps($id3, $date3, { TZ   => ASKP::TZ->UTC, Diff => 1           } );
	 if (!$psE) { return 0; }

	 if ( $psE->val(1)  ne $psB->val(3)  ||
		  $psE->val(2)  ne $psB->val(4)  ||
		  $psE->val(45) ne $psC->val(47) ||
		  $psE->val(46) ne $psC->val(48) ) {
	   return 0;
	 }

	 return 0 unless $c->fetch_ps($id3, $date3, { TZ   => ASKP::TZ->MSK_PLUS_2, DLS => 1, Diff => 1 } );

	 1;
   } );

#
# Store/delete tests
#
ok(
   sub {
	 my $up_id   = '1BE*xx*Gs07';
	 my $up_date = ++$date;

	 my $ps = $c->fetch_ps( $id2, $date );

	 $ps->{id}   = $up_id;
	 $ps->{date} = $up_date;

	 if (!($c->store_ps  ( $ps                     ) &&
		   $c->delete_ps ( $ps->{id} . $ps->{date} ) &&
		   $c->store_ps  ( $ps, $up_id             ) &&
		   $c->delete_ps ( $up_id . $ps->{date}    ) &&
		   $c->store_ps  ( $ps, $up_id, $up_date   ) &&
		   $c->delete_ps ( $up_id . $up_date       ) )) {
	   return 0;
	 }
	 1;
   } );


#
# PS arithmetics tests
#
ok(
   sub {
	 my $ps1 = $c->fetch_ps($id1, $date);
	 my $ps2 = $c->fetch_ps($id2, $date);

	 my $res = $ps1       +    1;
	 $res    = 3.14159265 + $ps1;
	 $res    = $ps1       + $ps2;

	 $res    = $ps1       -    1;
	 $res    = $ps1       - $ps2;
	 $res    = $ps1       -    1;
	 $res    = $ps1       - $ps2;
	 $res    = $ps1       *    2;
	 $res    = 3.14159265 * $ps1;

	 return 0 if eval { $ps1       * $ps2 };
	 $res    = $ps1       /    2 ;

	 return 0 if eval { $ps1       /    0 };
     return 0 if eval { 3.14159265 / $ps1 };
	 return 0 if eval { $ps1       / $ps2 };

	 #
	 # Note: 'apply' experements should be after store_ps samples
	 #
	 $ps1->val(1) = 64;

	 $ps1->apply( sub { sqrt } );
	 $ps1->apply( sub { my $v = shift; $v *= 2; return $v; } );

	 return 0 if (16 != $ps1->val(1));

	 #
	 # Logical and compare oprators
	 #
	 if ($ps1 > $ps2) {
	   return 0 if ($ps1 <= $ps2);
	 } elsif ($ps1 < $ps2) {
	   return 0 if ($ps1 >= $ps2);
	 }

	 if ($ps1 > 0) {
	   return 0 if ($ps1 <= 0);
	 } elsif (0 < $ps1) {
	   return 0 if (0 >= $ps1);
	 }

	 if (0 > $ps2) {
	   return 0 if (0 <= $ps2);
	 } elsif ($ps2 > 0) {
	   return 0 if ($ps2 <= 0);
	 }

	 if (0 == $ps2) {
	   return (0 != $ps2);
	 }

	 1;
   } );

ok(
   sub {
	 #
	 # Counter fetch tests
	 #
	 my $list = $c->fetch_list('1BE');
	 return 0 unless scalar @{$list};

} );

ok(
   sub {

	 my $hash = $c->fetch_hash('1BE');
	 return 0 unless scalar keys %{ $hash };

	 $hash = $c->fetch_hash('1', { Table => 'odu'});
	 return 0 unless scalar keys %{ $hash };

   } );


ok(
		sub {
			my ($id3, $date3) =  ('1BE****Gs04', '040701');
			my $to = sprintf '%06d', $date3+5;

			# my $p = ASKP::Connection->fetch_days( $id3, $date3, $to );

			my $p = ASKP::Period::fetch_days( $c, $id3, $date3, $to );

			for my $d ( sort keys  %{ $p->days() }) {
			#	print "date => $d\n";
			}

			1;
		}
);


ok( ! defined $c->close() ? 1 : 0 );