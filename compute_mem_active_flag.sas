%macro compute_mem_active_flag;

%set_rpt_env;

data _null_;
	rundate="&rundate"d;
	CALL SYMPUT("date_cutoff", put(INTNX("YEAR", intnx("MONTH", rundate, -0, "B"), -1, "S"), ddmmyyn8.));
run;

%put &date_cutoff.;

proc sql noprint;
   	connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
	
	%if %sysfunc(exist(dwhlib.activity_1_yr_ever)) %then %do;
		execute ( drop view activity_1_yr_ever) by dwh;
	%end;

	%if %sysfunc(exist(dwhlib.activity_1_yr_true)) %then %do;
		execute ( drop view activity_1_yr_true) by dwh;
	%end;

	execute (
		create view activity_1_yr_ever as
		select
			ACTIVITY_DATE
			, ACTIVITY_ID
			, MEMBER_ID
			, TO_CHAR(LOY_CARD_NUMBER) AS LOY_CARD_NUMBER
			, TO_CHAR(MEMBER_ACCOUNT_NUMBER) AS MEMBER_ACCOUNT_NUMBER 
			, activity_action_id
		from DET_ACTIVITY
		where
			ACTIVITY_DATE >= %cmpres(to_date(%NRBQUOTE('&date_cutoff.'), 'ddmmyyyy'))
			and 
			activity_action_id in (1,5)
		ORDER BY 
			MEMBER_ID, ACTIVITY_DATE DESC
	) by dwh;

	execute (
		create view activity_1_yr_true as
		select
			ACTIVITY_DATE
			, ACTIVITY_ID
			, MEMBER_ID
			, TO_CHAR(LOY_CARD_NUMBER) AS LOY_CARD_NUMBER
			, TO_CHAR(MEMBER_ACCOUNT_NUMBER) AS MEMBER_ACCOUNT_NUMBER 
			, activity_action_id
		from DET_ACTIVITY
		where
			ACTIVITY_DATE >= %cmpres(to_date(%NRBQUOTE('&date_cutoff.'), 'ddmmyyyy'))
			and 
			activity_action_id in (1,5)
			and
			PARTNER_ID not in (163238, 250643, 312341, 312927) /* look for Non-ICICI activities */
		ORDER BY 
			MEMBER_ID, ACTIVITY_DATE DESC
	) by dwh;


	disconnect from dwh;
quit;

data templib.EVER_ACTV_DATA;
	set DWHLIB.ACTIVITY_1_YR_ever;
		by member_id descending activity_date;

	if first.member_id;

	FORMAT EVER_active_flag $15.;
	format ACTIVITY_DT DATE9.;

	ever_active_flag="NOT-ACTIVE";

	activity_dT = DATEPART(activity_date);

	IF strip(upcase(put(activity_action_id, ACTION_TYPE.))) = "EARN" then do;		
		if intnx("MONTH", "&rundate."D, -3, "B") <= activity_dt <= "&RUNDATE"D then do;
			EVER_ACTIVE_FLAG="EVER_ACTV_3MTH";
		end;
		else if ACTIVITY_DT >= INTNX("YEAR", intnx("MONTH", "&rundate."d, -0, "B"), -1, "S") then do;
			EVER_ACTIVE_FLAG="EVER_ACTV_12MTH";
		end;
	end;

	KEEP MEMBER_ID EVER_ACTIVE_FLAG;
run;

data templib.TRUE_ACTV_DATA;
	set DWHLIB.ACTIVITY_1_YR_TRUE;
		by member_id descending activity_date;

	if first.member_id;

	FORMAT true_active_flag $15.;
	format ACTIVITY_DT DATE9.;

	TRUE_active_flag="NOT-ACTIVE";

	activity_dT = DATEPART(activity_date);

	IF strip(upcase(put(activity_action_id, ACTION_TYPE.))) = "EARN" then do;		
		if intnx("MONTH", "&rundate."D, -3, "B") <= activity_dt <= "&RUNDATE"D then do;
			TRUE_ACTIVE_FLAG="TRUE_ACTV_3MTH";
		end;
		else if ACTIVITY_DT >= INTNX("YEAR", intnx("MONTH", "&rundate."d, -0, "B"), -1, "S") then do;
			TRUE_ACTIVE_FLAG="TRUE_ACTV_12MTH";
		end;
	end;

	keep member_id TRUE_ACTIVE_FLAG;
run;

proc sql noprint;
   	connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
	execute (
		drop view ACTIVITY_1_YR_EVER
	) by dwh;

	execute (
		drop view ACTIVITY_1_YR_TRUE
	) by dwh;
quit;

%mend compute_mem_active_flag;

