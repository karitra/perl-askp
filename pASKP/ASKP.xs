#include <sstream>
#include <stdexcept>
#include <iostream>
#include <cstdlib>

#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#ifdef __cplusplus
}
#endif
	
#include <libpq-fe.h>

//namespace ASKP {
extern "C" {
#include "status.h"
#include "pglib.h"
#include "pglib_ker.h"
}

//}

//#include "askp.h"
#include "obj_psdata.h"	
#include "dbcrc.h"
#include "dates.h"

#define KWH      0.000001
#define SCALE2WH 1000000 

#define PS_PER_DAY  48
#define PS_IDP_BUFF 32

#define COUNT_CLASS_NAME "ASKP::Counter"
#define PS_CLASS_NAME    "ASKP::PS"

#if 0
#define dbg(m) std::cerr << m << std::endl
#else 
#define dbg(m)
#endif


#define FINALIZE(p) if (p) free(p), (p) = NULL;
#define SetStrA(d, s, sz) memcpy(d, s, sz)
#define SetStr(d,s,sz) SetStrA(d,s,sz)


typedef PGconn DBh;

extern char *DBlist[];
extern int DBlist_n;
// Forward declaration
class Connection;

DBh *conn;
DBh *conn1;

static AV *db_list_array;

class run_time_error_t : std::invalid_argument {
public:
  run_time_error_t(const char *what) : std::invalid_argument(what) {}
};

class Connection {
  bool isConnected;
  DBh *c;
  ObjPSDATA *psdata;

public:
  Connection(const char *url=0) : 
	isConnected(false), 
	c(0) {
	if (url) {
	  if (connect(url) < 0)
		throw run_time_error_t("failed to connect to database");
	}

	psdata = new ObjPSDATA();
	memset(psdata, 0, sizeof (PS) );
  }

  virtual ~Connection() {

	dbg("Connection: dtor");

	if (isConnected)
	  close();
	
	delete psdata;
  }

public:
  int connect(const char *url) {

	if (isConnected)
	  return -1;

	int r = connect_db(&c, const_cast<char *>(url));
	if (r >= 0)
	  isConnected = true;
	else 
	  isConnected = false;

	return r;
  }

  void close() {
	if (!isConnected)
	  return;

	disconnect_db(c);
	c = 0;
	isConnected = false;
  }

  DBh *getConnection() {
	return c;
  }

  operator DBh *() {
	return getConnection();
  }

  bool is_online() const {
	return isConnected;
  }

  PS* getPS() {
	return &psdata->ps;
  }

  bool fetch_ps(const char *id, const char *date, bool useShift=false, int dst_time=0, int dls_time=0) {
	using namespace std;
	DBh *backup;
	//	char *sp;

	assert(id);
	assert(date);
	assert(psdata);

	if (!isConnected ) // TODO: return some smart error message
	  return false;

	memset(&psdata->ps, 0, sizeof(PS) );

	// Note: one byte char string only acceptable here!
	strncpy(psdata->ps.ps_idp, id, sizeof psdata->ps.ps_idp );
	psdata->ps.ps_idp[ sizeof psdata->ps.ps_idp - 1] = '\0';
	strncat(psdata->ps.ps_idp, date, sizeof psdata->ps.ps_idp - strlen(psdata->ps.ps_idp) - 1 );
	psdata->ps.ps_idp[ sizeof psdata->ps.ps_idp - 1] = '\0';

	// Some ritual from Irina's code
	psdata->cur_yr[0]  = date[0];
	psdata->cur_yr[1]  = date[1];
	psdata->cur_yr[2]  = 0;
	psdata->cur_mon[0] = date[2];
	psdata->cur_mon[1] = date[3];
	psdata->cur_mon[2] = 0;
	psdata->cur_day[0] = date[4];
	psdata->cur_day[1] = date[5];
	psdata->cur_day[2] = 0;

	if (useShift) {
	  // 
	  // Note: dangerous code!
	  //
	  // Magic flag from Irina's code to bypass summator
	  // date offset fetching
	  ObjPSDATA::st_int++;

	  // Setting our values for summator instead of those from database
	  psdata->RootTime = dst_time;
	  psdata->RootLetn = dls_time;
	}

	char *idp = new char[PS_IDP_BUFF];
	strncpy(idp, psdata->ps.ps_idp, PS_IDP_BUFF);
	idp[PS_IDP_BUFF - 1] = '\0';

	backup  = conn, conn = c;
	//	int res = psdata->CalculatePS( psdata->ps.ps_idp, &psdata->ps );
	int res = psdata->CalculatePS( idp, &psdata->ps );
	conn    = backup;

	delete[] idp;

	if (res < 0)
	  PerlIO_stdoutf("Fetch error: %s\n", psdata->errmsg );

	if (useShift)
	  ObjPSDATA::st_int--;

	// Recalculate E as we now have PS values for such computation.
	psdata->ComputeE();

	return (res < 0) ? false : true;
  }


  bool store_ps(const char *id, const char *date) {
	set_psidp(id, date);
	return store_ps();
  }

  bool store_ps(const char *idp) {
	set_psidp(idp);
	return store_ps();
  }

  bool store_ps() {
	assert(c);
	assert(psdata);

	if (insert_ps(c, &psdata->ps) < 0) {

	  if (update_ps(c, psdata->ps.ps_idp, &psdata->ps) < 0) {
		return false;
	  } else {
		return true;
	  }

	} 
	
	return true;
  }

  int delete_ps(const char *idp) {
	dbg("Trying to delete idp: " << idp);
	return ::delete_ps( c, const_cast<char *>(idp) );
  }


  int delete_ps(const char *id, const char *date) {
    using namespace std;	   

	dbg("Trying to delete id: " << id << " date: " << date);

	if ( !(strlen(id) == COUNT_IDP && strlen(date) == DATE_LEN)) {
	   return -1;
	}	   

	ostringstream os;
	os << id << date;

	return ::delete_ps( c, const_cast<char *>( os.str().c_str() ) );
  }


  // Utility functions
  void set_psidp(const char *id, const char *date) 
  {
	strncpy( psdata->ps.ps_idp, id, sizeof(psdata->ps.ps_idp) );
	psdata->ps.ps_idp[ sizeof(psdata->ps.ps_idp) - 1 ] = '\0';
	strncat( psdata->ps.ps_idp, id, sizeof(psdata->ps.ps_idp) - strlen(psdata->ps.ps_idp)  );

	psdata->ps.ps_idp[ sizeof(psdata->ps.ps_idp) - 1] = '\0';
  }

  void set_psidp(const char *idp) 
  {
	strncpy(psdata->ps.ps_idp, idp, sizeof(psdata->ps.ps_idp) );
	psdata->ps.ps_idp[ sizeof(psdata->ps.ps_idp) - 1] = '\0';
  }

};

static void load_module() {
  using namespace std;

  dbg( "Loading ASKP::Connect!\n" );

  char *init_path = NULL;

#ifdef WIN32
  init_path = "./";
#elif defined(LINUX)
  init_path = "/home/linaskp/bin/.dbcrc";
#endif

  if (NULL != init_path) {
	assert(DBlist);
		 
	parse_dbcrc( init_path );
	//	db_list_array = (AV *) sv_2mortal( (SV *) newAV() );
	db_list_array = (AV *) newAV();
	for(int i = 0; i < DBlist_n; i++) {
	  if ( DBlist[i] )
		av_push(db_list_array,  newSVpv( DBlist[i], strlen( DBlist[i] ) ) );
	}
  }
}


MODULE = ASKP           PACKAGE = ASKP

BOOT:
	load_module();


SV *
next_date(current)
	 const char *current
PREINIT:
	 char *tmp;
CODE:
	 New(0, tmp, DATE_LEN, char);
	 SAVEFREEPV(tmp);

	 *tmp = '\0';
	 get_next_date(const_cast<char *>(current), tmp);	 
	 RETVAL = newSVpv(tmp,0);
OUTPUT:
	 RETVAL

int
cdate_le(cdate1, cdate2)
	  char *cdate1;
	  char *cdate2;


AV *
bases_list()
PREINIT: 
    AV *array;
PROTOTYPE: DISABLE
CODE:
	  array  = db_list_array;
	  RETVAL = array;
OUTPUT:
	RETVAL	  


MODULE = ASKP		PACKAGE = ASKP::Connection

Connection *
new(self, url)
	char *self
	char *url
PROTOTYPE: $$
PREINIT:
	Connection *c;
CODE:

    try {
	  c = new Connection(url);
	} catch(std::invalid_argument &e) {
	  std::cerr << "Error: " << e.what() << std::endl;
	  XSRETURN_UNDEF;
	}

	RETVAL = c;
OUTPUT:
	RETVAL


MODULE = ASKP 	PACKAGE = ConnectionPtr

SV*
fetch_cnt(c, id)
	Connection *c
	char *id
PROTOTYPE: $$
PREINIT:
	COUNT *cnt;
	HV *hash;
CODE:
    New(0, cnt, 1, COUNT);

    if (!c->is_online() || select_count( c->getConnection(), id, cnt) <= 0)
	  XSRETURN_UNDEF;

	hash = (HV *) sv_2mortal( (SV *) newHV() );
	hv_store(hash, "id",    2, newSVpv(cnt->count_idp,    0), 0);
	hv_store(hash, "name",  4, newSVpv(cnt->count_name,   0), 0);
	hv_store(hash, "idl",   3, newSVpv(cnt->count_idl,    0), 0);
	hv_store(hash, "idd",   3, newSVpv(cnt->count_idd,   0), 0);
	hv_store(hash, "logn2", 5, newSVpv(cnt->count_logn2,    0), 0);
	hv_store(hash, "Ktr",   3, newSVnv(cnt->count_ktr), 0);
	hv_store(hash, "Kln",   3, newSVnv(cnt->count_coeff_length), 0);
	hv_store(hash, "TZ",    2, newSViv(cnt->count_meas_mode), 0);

    RETVAL = sv_bless( (SV *) newRV((SV *) hash), gv_stashpv(COUNT_CLASS_NAME, 1) );
OUTPUT:
    RETVAL
CLEANUP:
    Safefree(cnt);

SV*
fetch_ps(c, id, date, options = NO_INIT)
	Connection *c
	char *id
	char *date
	HV   *options
PROTOTYPE: $$$;\%
PREINIT:
	PS *p;
	HV *hash;
	HV *vals;
CODE:
	bool 
	  getDiff       = false, 
	  useSmartFetch = false;
	int 
	  delta = 0, 
	  dls   = 0;
	double prevE = 0.;

	if (!(c && id && date))
		XSRETURN_UNDEF;

	if (items == 4) { // Some additional options are set 
	  SV **v;

	  if (!(options && SvTYPE(options) == SVt_PVHV)) 
		croak("optional parameter isn't a hash, please remove it or"
			  " set it to hash according to the documentation");

	  v = hv_fetch( options, "Diff", 4, 0 );
	  if ( v && *v              && 
		   SvTYPE(*v) == SVt_IV &&
		   SvIV(*v) ) {
		if (!(date[4] == '0' && 
			  date[5] == '1') ) // not first day of month
		  getDiff = true;
	  }

	  v = hv_fetch( options, "TZ", 2, 0 );
	  if (v && *v &&
		  SVt_IV == SvTYPE(*v) ) {
		useSmartFetch = true;
		delta = SvIV(*v);
	  }

	  v = hv_fetch( options, "DLS", 3, 0 );
	  if (v && *v && 
		  SVt_IV == SvTYPE(*v)) {
		useSmartFetch = true;
		dls = SvIV(*v);
	  }

	}

    if (getDiff) {
	  // must be not less then 7 (6 + 1)
	  char *pdate = new char[16];
	  get_prev_date(date, pdate);

	  if (!c->fetch_ps(id, pdate, useSmartFetch, delta, dls )) {
		std::ostringstream os;
		os << pdate;
		delete[] pdate;		
		//		XSRETURN_UNDEF;
		croak("'Diff' option is set, but no PS id:[%s] value for\n"
			  "previous date [%s] was fetched", id, os.str().c_str() );
	  }

	  prevE = c->getPS()->ps_ie;

	  delete[] pdate;		
	}

    if (!c->fetch_ps(id, date, useSmartFetch, delta, dls))
		XSRETURN_UNDEF;

    p = c->getPS();	

	hash = (HV *) sv_2mortal( (SV *) newHV() );
	vals = (HV *) sv_2mortal( (SV *) newHV() );

	hv_store(hash, "id",   2, newSVpv(id,   0), 0);
	hv_store(hash, "date", 4, newSVpv(date, 0), 0);

	hv_store(hash, "E", 1, 
			 newSVnv( getDiff ? p->ps_ie - prevE : p->ps_ie ), 0);

	// update: Mon Jan 31 15:08:31 GMT 2011
	hv_store(hash, "date_beg", 8, newSVpv(p->ps_date_beg, 0), 0);

	hv_store(hash, "b",    1, newSVnv(p->ps_b  ), 0);
	hv_store(hash, "b_s",  3, newSViv(p->ps_b_s), 0);
	hv_store(hash, "b_t",  3, newSViv(p->ps_b_t), 0);

	hv_store(hash, "ie",   2, newSVnv(p->ps_ie  ), 0);
	hv_store(hash, "ie_s", 4, newSViv(p->ps_ie_s), 0);
	hv_store(hash, "ie_t", 4, newSViv(p->ps_ie_t), 0);

	hv_store(hash, "scf",  3, newSViv(p->ps_scf), 0);

	// TZN = 4
	std::ostringstream tzos;
	std::string stz;

	for(int i = 0; i < TZN; i++) {

	  tzos.clear(), tzos.str("");
	  tzos << "tz" << (i+1);
	  stz = tzos.str();

	  hv_store(hash, stz.c_str(),  stz.size(), newSVnv(p->ps_tz [i] ), 0);
	  stz.append(1, 's');
	  hv_store(hash, stz.c_str(),  stz.size(), newSViv(p->ps_tzs[i] ), 0);

	  assert( stz.size() );

	  stz[stz.size() - 1] = 'h';

	  hv_store(hash, stz.c_str(), stz.size(), newSVnv(p->ps_tzh[i] ), 0);
	}
	

	for(int i = 0; i < PS_PER_DAY; i++) {
		HV *val = (HV *) sv_2mortal( (SV *) newHV() );
		char st[2];

		status2char(st, p->ps_s[i]);
		hv_store(val, "val", 3, newSVnv(p->ps_p[i] * KWH), 0 );
		hv_store(val, "st",  2, newSVpv(st, *st ? 1 : 0),  0 );

		hv_store_ent(vals, newSViv(i+1), newRV( (SV *) val), 0);
	}

	hv_store(hash, "vals", 4, newRV( (SV *) vals), 0);

    RETVAL = sv_bless( (SV *) newRV((SV *) hash), gv_stashpv(PS_CLASS_NAME, 1) );
OUTPUT:	
	RETVAL


AV *
fetch_list(self, parent_id)
    Connection *self
    char *parent_id
PROTOTYPE: $$
PREINIT: 
    UARR *res;
    int n, i;
    AV *array;
CODE:

    if (!self->is_online()) {
	  croak("Connection must be istablished!");
    }

    if ((n = select_list( self->getConnection(), "count", "idp", "name", parent_id, &res)) <= 0)
	  XSRETURN_UNDEF;
    

	array = (AV *) sv_2mortal( (SV *) newAV() );

  	for(i = 0; i < n; i++) {
	  av_push(array,  newSVpv(res[i].idp, 11 ) );
	}

	for(i = 0; i < n; i++) {
		FINALIZE(res[i].val);
		FINALIZE(res[i].idp);
	}

	FINALIZE(res);

    RETVAL = array;
OUTPUT:
    RETVAL


HV *
fetch_hash(self, parent_id, options = NO_INIT )
    Connection *self
    char *parent_id
    HV *options
PROTOTYPE: $$;\%
PREINIT: 
    UARR *res;
    int n, i;
    HV *hash;
    char *tb = "count";
	SV **v;
CODE:

    assert(self);
    assert(parent_id);

    if (items == 3) {

	  if (!(options && SvTYPE(options) == SVt_PVHV)) 
		croak("optional parameter isn't a hash, please remove it or"
			  " set it to hash according to the documentation");

	  v = hv_fetch( options, "Table", 5, 0 );
	  if ( v && *v              && 
		   SvTYPE(*v) == SVt_PV ) {
		tb = SvPVX(*v);
	  }
	}

    if (!self->is_online()) {
	  croak("Connection must be istablished!");
    }

    if ((n = select_list( self->getConnection(), tb, "idp", "name", parent_id, &res)) < 0)
	  XSRETURN_UNDEF;

	hash = (HV *) sv_2mortal( (SV *) newHV() );

  	for(i = 0; i < n; i++) {
	  res[i].idp[COUNT_IDP] = '\0';
	  hv_store(hash, res[i].idp, strlen(res[i].idp), newSVpv(res[i].val, 0), 0 );
	}

	for(i = 0; i < n; i++) {
		FINALIZE(res[i].val);
		FINALIZE(res[i].idp);
	}

	FINALIZE(res);

    RETVAL = hash;
OUTPUT:
    RETVAL


bool
store_ps(c, rh, ...)
	  Connection *c
	  SV *rh
PREINIT:
      HV *hash;
      HV *vals;
      HV *vh;
      SV *rv;
      SV **vp;
      SV **v;
      SV **st;
      SV **id;
      SV **date;
      char *key;
      char *sid;
      char *sdate;
      char *sst;
      STRLEN len_id;
      STRLEN len_date;
      I32 klen;
      unsigned int index;
CODE:

    assert(c);

    if (!c->is_online())
	  croak("Connection must be istablished!");

    if (!SvROK(rh))
	  croak("Second parameter must be an PS reference!");

    hash = (HV *) SvRV(rh);
    if (!(hash && (SvTYPE(hash) == SVt_PVHV)))
	  croak("Second parameter isn't a hash reference!");



    // Check for 'id' and 'date'
    id = hv_fetch(hash, "id", 2, 0);
    if (!(id && SvPOK(*id)) && items != 3 && !ST(2))
	  croak("'id' field doesn't present in the PS object and in call parameters!");

    date = hv_fetch(hash, "date", 4, 0);
    if (!(date && SvPOK(*date)) && items != 4 && !ST(3))
	  croak("'date' field doesn't present in the PS object and in call parameters!");



    vp = hv_fetch(hash, "vals", 4, FALSE);
    if (!vp)
	  croak("PS hash must contain 'vals' reference!");

    vals = (HV *) SvRV(*vp);
    if (!(vals && (SvTYPE(vals) == SVt_PVHV)) )
	  croak("'Vals' isn't a hash reference!");


    PS *p = c->getPS();
    memset(p, 0, sizeof (PS) );

    sid   = 0;
    sdate = 0;

    if (id && SvPOK( *id)) {
	  sid   = SvPV( *id,   len_id   );

	  if (len_id != COUNT_IDP  )
		croak( "'id' field isn't valid" );

	  strncpy( p->ps_idp, sid,   sizeof p->ps_idp );
	  p->ps_idp[sizeof p->ps_idp - 1] = '\0';
	} 

    if (date && SvPOK(*date) ) {
	  sdate = SvPV( *date, len_date );

	  if (len_date != DATE_LEN  )
		croak( "'date' field isn't valid" );

	  strncpy( p->ps_idp + COUNT_IDP, sdate,   sizeof p->ps_idp -  COUNT_IDP );
	  p->ps_idp[sizeof p->ps_idp - 1] = '\0';
	}


	dbg( __func__ << " idp: " << p->ps_idp );

    hv_iterinit(vals);
    while(rv = hv_iternextsv(vals, (char **) &key, &klen)) {

	  if (!key) 
		continue;

	  index = atoi(key) - 1;
	  if (index > 50 - 1)
		croak("Value index %d out of range!", index );


	  vh = (HV *) SvRV(rv);
	  if (!(vh && SvTYPE(vh) == SVt_PVHV))
		croak("Vals item number %d within PS isn't a reference!", index);

	  v  = hv_fetch(vh, "val", 3, 0 );
	  st = hv_fetch(vh, "st",  2, 0 );
	  
	  if (!v)
		croak("Value wasn't set for PS value with index %d!", index);

	  p->ps_p[index] = SvNV( *v  ) * SCALE2WH;

	  sst = SvPV_nolen(*st );

	  if ( !(sst && sst[0]) ) 
		p->ps_s[index] = STATUS_nodata; 
	  else if (sst[0] != ' ')
		p->ps_s[index] = char2status(sst);
	  else 
		p->ps_s[index] = STATUS_space;
	}


	v = hv_fetch(hash, "b", 1, 0);
	if (v && SvNOK(*v))
	  p->ps_b = SvNV(*v);

	v = hv_fetch(hash, "b_s", 3, 0);
	if (v && SvIOK(*v))
	  p->ps_b_s = SvIV(*v);

	v = hv_fetch(hash, "b_t", 3, 0);
	if (v && SvIOK(*v))
	  p->ps_b_t = SvIV(*v);


	v = hv_fetch(hash, "ie", 2, 0);
	if (v && SvNOK(*v))
	  p->ps_ie = SvNV(*v);

	v = hv_fetch(hash, "ie_s", 4, 0);
	if (v && SvIOK(*v))
	  p->ps_ie_s = SvIV(*v);

	v = hv_fetch(hash, "ie_t", 4, 0);
	if (v && SvIOK(*v))
	  p->ps_ie_t = SvIV(*v);

	v = hv_fetch(hash, "scf", 3, 0);
	if (v && SvIOK(*v))
	  p->ps_scf = SvIV(*v);

	v = hv_fetch(hash, "date_beg", 8, 0);
    if (v && SvPOK(*v)) {
	  strncpy(p->ps_date_beg, SvPV_nolen(*v), 7);
	  p->ps_date_beg[7-1] = '\0';
	}

	// TZN = 4
	std::ostringstream tzos;
	std::string stz;

	for(int i = 0; i < TZN; i++) {

	  tzos.clear(), tzos.str("");
	  tzos << "tz" << (i+1);
	  stz = tzos.str();

	  v = hv_fetch(hash, stz.c_str(), stz.length(), 0);
	  if (v && SvNOK(*v))
		p->ps_tz[i] = SvNV(*v);

	  stz.append(1, 's');

	  v = hv_fetch(hash, stz.c_str(), stz.length(), 0);
	  if (v && SvIOK(*v))
		p->ps_tzs[i] = SvIV(*v);

	  stz[stz.length() - 1] = 'h';

	  v = hv_fetch(hash, stz.c_str(), stz.length(), 0);
	  if (v && SvNOK(*v))
		p->ps_tzh[i] = SvNV(*v);
	  
	}


		
	// Setting of id
    switch(items) {
	case 2: // PS reference only case

	  if (!(sid && sdate))
		croak("Counter id is undefined and not set as prameter to 'store_ps'!");

	  break;
	case 3: // user predefined ID case

	  if (!sdate)
		croak("Date for PS is undefined!");
	  
	  sid = SvPV(ST(2), len_id);
	  if (!sid)

	  SetStr(p->ps_idp, SvPV_nolen(ST(2)), COUNT_IDP );

	  break;
	case 4: // user predefined ID and date case
	  sid   = SvPV(ST(2), len_id   );
	  sdate = SvPV(ST(3), len_date );

	  if (!(sid && len_id == COUNT_IDP))
		croak( "'id' field isn't valid" );

	  if (!(sdate && len_date == DATE_LEN))
		croak( "'date' field isn't valid" );

	  strncpy(p->ps_idp, sid, sizeof p->ps_idp);
	  p->ps_idp[ sizeof p->ps_idp - 1] = '\0';

	  strncat(p->ps_idp, sdate, sizeof p->ps_idp - COUNT_IDP);
	  p->ps_idp[ sizeof p->ps_idp - 1] = '\0';

	  break;
	default:
	  croak("Wrong number of parameters to store_ps function!");
	  break;
	}

    RETVAL = c->store_ps();
OUTPUT:
    RETVAL

int
Connection::delete_ps(idp)
  const char *idp

void 
Connection::close()
	
void
Connection::DESTROY()

bool
Connection::is_online()

int
Connection::connect(url)
  const char *url

