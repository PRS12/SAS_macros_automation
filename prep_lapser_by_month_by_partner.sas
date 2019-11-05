/************************************************************************
*       Program      : prep_lapser_by_month_by_partner.sas              *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : AMR, LSRL-273                                    *
*                                                                       *
*       Input        : DWHLIB.DET_ACTIVITY                              *
*                      SASMART.ACCOUNT_AGGREGATION_MASTER               *
*                                                                       *
*                                                                       *
*       Output       : TEMPLIB.LAPSER_MEMLIST_&PARTNER._&activity_month.*
*                                                                       *
*                                                                       *
*                                                                       *
*       Dependencies : NONE                                             *
*                                                                       *
*       Description  : Prepares a list of customers who have come during*
*                      a selected month and have not returned for the   *
*                      next period as defined for the given partner.    *
*       Usage        :                                                  *
*   %prep_lapser_by_month_by_partner                                    *
*   (                                                                   *
*	activity_month=201212 (or DEC2012)                                  *
*	, partner=BIGBAZAAR (As available in dwhlib.partner_list)           *
*	, lperiod=3 (No. of months defined as lapser period based on partner*
*	, outdsn=%cmpres(TEMPLIB.LAPSER_MEMLIST_&PARTNER._&activity_month.) *
*	, report=Y (flag for generating a report or not)                    * 
*	, report_dest=                                                      *
*   %str(G:\reporting\%cmpres(&partner._lapser_rpt_&activity_month..&fileformat.)) *
*	, fileformat=xls (file format)                                      *
*   );                                                                  *
*                                                                       *
*       History      :                                                  *
*       AMR           04APR2013 Created                                 *
*                                                                       *
************************************************************************/

%macro prep_lapser_by_month_by_partner
(
	activity_month=
	, partner=
	, lperiod=
	, outdsn=%cmpres(TEMPLIB.LAPSER_MEMLIST_&PARTNER._&activity_month.)
	, report=Y
	, report_dest=%str(G:\reporting\%cmpres(&partner._lapser_rpt_&activity_month..&fileformat.))
	, fileformat=xls
);

/*%let start=01nov2012;*/
/*%let end=30nov2012;*/

data _null_;
	if anyalpha("&activity_month.") then do;
		if length("&activity_month.") = 7 then do;
			call symput("start", put(intnx('month', input('01' || strip("&activity_month."), date9.), 0, 'B'), date9.));			
			call symput("end", put(intnx('month', input('01' || strip("&activity_month."), date9.), 0, 'E'), date9.));			
		end;
		else do;
			put "ERROR: ACTIVITY_MONTH not in known SAS format";
			put "ERROR: Please use the following formats: ";
			put "ERROR: yyyymm (e.g. 200606) or monyyyy (e.g. JUN2006)";
			abort ABEND; 
		end;
	end;
	else do;
		if length("&activity_month.") = 6 then do;
			call symput("start", put(intnx("month", input(strip("&activity_month.") || "01", yymmdd8.), 0, 'B'), date9.));			
			call symput("end", put(intnx("month", input(strip("&activity_month.") || "01", yymmdd8.), 0, 'E'), date9.));			
		end;
		else do;
			put "ERROR: Parameter ACTIVITY_MONTH not in known SAS format";
			put "ERROR: Please use the following formats: ";
			put "ERROR: yyyymm (e.g. 200606) or monyyyy (e.g. JUN2006)";
			abort ABEND; 
		end;
	end;
run;

proc sql noprint;
	select distinct partner_id into: plist separated by "," from dwhlib.partner_list where
	%if "&partner." = "BIGBAZAAR" %then %do;
	p_commercial_name in ("BIGBAZAAR", "FOODBAZAAR", "FBB");
	%end;
	%else %do;
	p_commercial_name in (upcase("&partner."));
	%end;
quit;

proc summary data = dwhlib.det_activity (keep=member_id activity_date partner_id transaction_type_id) nway missing;
	where
		partner_id in (&plist.)
		and
		"&start."D <= activity_date <= "&end."d
		and
		transaction_type_id in (8,295)
	;

	class
		member_id
	;
	output out = all_acct_txn_summ (rename=(_Freq_ = tran_count) drop = _type_)
	;
run;

DATA all_cust_txn_summ;

	format primary_member_id 8.;

	if _n_ = 1 then do;
		declare hash memhash(dataset:"sasmart.account_aggregation_master(keep=member_id primary_member_id)");
		memhash.definekey("member_id");
		memhash.definedata("primary_member_id");
		memhash.definedone();
	end;

	set all_acct_txn_summ;

	rc = memhash.find();
	customer_id = member_id;
	if rc = 0 then customer_id = primary_member_id;

	keep customer_id tran_count;
run;

proc summary data = all_cust_txn_summ nway missing;
	class
		customer_id
	;
	var
		tran_count
	;

	output out = all_cust_txn_summ_final (drop=_:)
		sum(tran_count) = tot_tran_count
	;
run;
quit;

data _null_;
	call symput("lapser_lmtdt", put(intnx("month", "&end."d, &lperiod., "E"), date9.));
run; 

proc sql noprint;
	create table returners_acct as 
	select distinct member_id from dwhlib.det_activity (keep=member_id activity_date partner_id transaction_type_id)
	where
		partner_id in (&plist.) 
		and
		("&end."d < activity_date <= "&lapser_lmtdt."d)
		and
		transaction_type_id in (8,295)
	;
quit;

DATA returners;

	format primary_member_id 8.;

	if _n_ = 1 then do;
		declare hash memhash(dataset:"sasmart.account_aggregation_master(keep=member_id primary_member_id)");
		memhash.definekey("member_id");
		memhash.definedata("primary_member_id");
		memhash.definedone();
	end;

	set returners_acct;

	rc = memhash.find();
	customer_id = member_id;
	if rc = 0 then customer_id = primary_member_id;

	keep customer_id;
run;

proc format;
	value bucket
	1='1'
	2-3='2 to 3'
	4-high='> 3'
	;
quit;

data &outdsn.;
	
	if _n_ = 1 then do;
		declare hash rhash(dataset:"returners");
		rhash.definekey("CUSTOMER_ID");
		rhash.definedone();
	end;

	set all_cust_txn_summ_final;

	format tot_tran_count bucket.;

	if rhash.find() = 0 then lapser_flag = 0;
	else lapser_flag = 1;
run;

proc format;
	value lapsfmt
		0="N"
		1="Y"
	;
quit;

%if %cmpres(%upcase("&report.")) = "Y" or %cmpres(%upcase("&report.")) = "YES" %then %do;

	ods listing close;
	ods results off;
	ods html file=%cmpres("&report_dest.") style=minimal;

	title;

	proc tabulate data = &outdsn. missing;
		class
			tot_tran_count
			lapser_flag
		;

		format tot_tran_count bucket.;
		format lapser_flag lapsfmt.;
 
		tables
			tot_tran_count="" ALL="Grand Total"
				, (lapser_flag="Member count by lapse-status"*N="" all=""*N="Total shoppers at &partner.")
			/ box={label="&partner. Lapser behavior for the month &activity_month."} misstext='N/A'
		;
	run;

	ODS HTML close;
	ods results on;
	ods listing;

%end;

%mend prep_lapser_by_month_by_partner;
