%macro create_member_mart_updt;

/************************************** create_agg_mem_dsn_with_points *************************************************/

proc sql noprint;
   connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000); 
   EXECUTE(
			CREATE TABLE TREE_CN1 AS 
    		SELECT DISTINCT TO_CHAR(MEMBER_ACCOUNT_NEW) AS SECONDARY_ACC, TO_CHAR(MEMBER_ACCOUNT_NEW) AS FINAL_ACC, 1 AS LEVELNO
			FROM 
				MAP_ACC_AGGREGATION 
			WHERE 
				MEMBER_ACCOUNT_NEW NOT IN (SELECT MEMBER_ACCOUNT_OLD FROM MAP_ACC_AGGREGATION)
	) BY DWH; 


	EXECUTE (
		CREATE TABLE TREE_CN2 AS 
	 	SELECT CONNECT_BY_ROOT TO_CHAR(AG.MEMBER_ACCOUNT_OLD) AS SECONDARY_ACC
	             , TO_CHAR(AG.MEMBER_ACCOUNT_NEW) AS FINAL_ACC
				 , LEVEL AS LEVELNO 
	     FROM MAP_ACC_AGGREGATION AG
		CONNECT BY NOCYCLE PRIOR AG.MEMBER_ACCOUNT_NEW = AG.MEMBER_ACCOUNT_OLD
		AND LEVEL <= 15
		ORDER BY AG.AGGREGATION_ID
	) BY DWH;
	DISCONNECT FROM DWH;
QUIT;

DATA AGG_MEM_TREE;
	set DWHLIB.TREE_CN1 DWHLIB.TREE_CN2;
RUN;

PROC DATASETS LIBRARY=DWHLIB NOLIST;
	delete
		TREE_CN1
		TREE_CN2
		AGG_MEM_TREE
	;
QUIT;

data DWHLIB.AGG_MEM_TREE;
	SET agg_mem_tree;
run;

proc datasets lib=dwhlib nolist;
	delete
		agg_tree_with_points
	;
quit;


proc sql noprint;
   connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000); 

   EXECUTE (
   create table agg_tree_with_points as
   select a.*
			, b.EARN_ACTION_POINTS
			, b.BURN_REV_ACTION_POINTS
			, b.PREALL_EARN_ACTION_POINTS
			, b.BURN_ACTION_POINTS
			, b.EARN_REV_ACTION_POINTS
			, b.PREALL_BURN_ACTION_POINTS
			, b.POINTS_UNDER_PROCESS
			/* C0002 */
			, b.sourced_association_id
			, b.member_id
			, to_char(c.loy_card_number) as LOY_CARD_NUMBER
			, c.promo_code_id
	FROM 
		agg_mem_tree A
		, DIM_MEMBER B
		, DET_MEMBER_CARD_ACC_MAP C
	WHERE
		A.SECONDARY_ACC=TO_CHAR(B.MEMBER_ACCOUNT_NUMBER)
		and
		A.SECONDARY_ACC = TO_CHAR(C.MEMBER_ACCOUNT_NUMBER) 
	) 
	BY DWH;
   disconnect from dwh;
quit;

DATA SUPPLIB.AGG_TREE_WITH_POINTS 
;
	SET dwhlib.agg_tree_with_points;
run;

proc datasets library=DWHLIB NOLIST;
	DELETE
		AGG_TREE_WITH_POINTS
		AGG_MEM_TREE
	;
QUIT;
RUN;


/* Added step to avoid multiple aggregations into the same final_acc. (LSRL-273, 23FEB2012) */
proc sort data = SUPPLIB.AGG_TREE_WITH_POINTS nodupkey;
	by secondary_acc final_acc;
run;

proc sort data = SUPPLIB.AGG_TREE_WITH_POINTS OUT = TEMP(keep=levelno FINAL_ACC secondary_acc);
	by secondary_acc descending levelno;
run;

PROC SORT DATA = temp nodupkey;
	by secondary_acc;
run;

proc sort data = temp nodupkey;
	by final_acc;
run;

proc summary data = supplib.agg_tree_with_points nway;
	class
		FINAL_ACC
	;
	var
		EARN_ACTION_POINTS
		BURN_REV_ACTION_POINTS
		PREALL_EARN_ACTION_POINTS
		BURN_ACTION_POINTS
		EARN_REV_ACTION_POINTS
		PREALL_BURN_ACTION_POINTS
		POINTS_UNDER_PROCESS
/*		POINTS_TO_EXPIRE*/
	;

	output out = AGGREGATED_MEMBERS_PRIMARY (RENAME=(_freq_=NO_OF_ACCTS) DROP = _TYPE_)
		SUM(EARN_ACTION_POINTS) = EARN_ACTION_POINTS
		SUM(BURN_REV_ACTION_POINTS) = BURN_REV_ACTION_POINTS
		SUM(PREALL_EARN_ACTION_POINTS) = PREALL_EARN_ACTION_POINTS
		SUM(BURN_ACTION_POINTS) = BURN_ACTION_POINTS
		SUM(EARN_REV_ACTION_POINTS) = EARN_REV_ACTION_POINTS
		SUM(PREALL_BURN_ACTION_POINTS) = PREALL_BURN_ACTION_POINTS
		SUM(POINTS_UNDER_PROCESS) = POINTS_UNDER_PROCESS
/*		SUM(POINTS_TO_EXPIRE) = POINTS_TO_EXPIRE*/
	;
RUN;
QUIT;

proc sort data = AGGREGATED_MEMBERS_PRIMARY;
	BY FINAL_ACC;
RUN;

proc sort data = temp;
	BY FINAL_ACC;
RUN;

data WHOUSE.AGGREGATED_MEMBERS_PRIMARY(rename=(FINAL_ACC=MEMBER_ACCOUNT_NUMBER));
	MERGE AGGREGATED_MEMBERS_PRIMARY (IN=IN1) TEMP(IN=IN2);
		BY FINAL_ACC;
	IF IN1 AND IN2;
run;

/* C0001 */
proc sort data = SUPPLIB.AGG_TREE_WITH_POINTS;
	by secondary_acc descending levelno;
run;

data SUPPLIB.AGG_TREE_WITH_POINTS;
	set SUPPLIB.AGG_TREE_WITH_POINTS;
		by secondary_acc descending levelno;
	if first.secondary_acc;
run;

/************************************** create_agg_mem_dsn_with_points - ENDS *************************************************/

/************************************** compute active flag *******************************************************************/

data _null_;
	rundate="&rundate"d;
	CALL SYMPUT("date_cutoff", put(INTNX("YEAR", intnx("MONTH", rundate, -0, "B"), -1, "S"), ddmmyyn8.));
run;

%put &date_cutoff.;

proc datasets lib=dwhlib nolist;
	delete
		activity_1_yr_ever
		activity_1_yr_true
	;
quit;

proc sql noprint;
   	connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
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

data supplib.EVER_ACTV_DATA;
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

data supplib.TRUE_ACTV_DATA;
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

proc datasets lib=dwhlib nolist;
	delete
		activity_1_yr_ever
		activity_1_yr_true
	;
quit;

/******************************************* Compute active flags - ENDS ******************************************************/


proc datasets lib=dwhlib nolist;
	delete 
		dim_member_updt_vw
		LKP_CARD_DEL_STATUS
	;
quit;

proc datasets lib=whouse nolist;
	delete 
		member_UPDT
	;
quit;

proc sql noprint;
	   connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
	   execute (
				create view dim_MEMBER_updt_vw as
				select
					TO_CHAR(dm.member_account_number) as MEMBER_ACCOUNT_NUMBER
					,TO_CHAR(dm.loy_card_number) as LOY_CARD_NUMBER
					,DM.SOURCED_ASSOCIATION_ID
					,DM.ACTIVE_STATUS_ID
					,DM.PHYSICAL_CARD_TYPE_ID
					,DM.MEMBER_CARD_TYPE_ID
					,DM.PROGRAM_ID
					,DM.SALUTATION
					,DM.gender
					,DM.address_line1
					,DM.address_line2
					,DM.address_line3
					,DM.address_line4
					,DM.city
					,DM.zip
					,DM.state_province
					,DM.email
					,DM.mobile_phone
					,DM.phone1
					,DM.MEMBER_ID
					,DM.EARN_ACTION_POINTS
					,DM.BURN_REV_ACTION_POINTS
					,DM.PREALL_EARN_ACTION_POINTS
					,DM.BURN_ACTION_POINTS
					,DM.EARN_REV_ACTION_POINTS
					,DM.PREALL_BURN_ACTION_POINTS
					,DM.POINTS_UNDER_PROCESS
					,DM.CARD_ISSUED_DATE
					,DM.SIGNUP_DATE
					,DM.IS_MEMBER_DISABLED
					,DM.IS_DUMMY_MEMBER
					,DM.IS_DELETED
					,DM.FULL_NAME
					,DM.DATE_OF_BIRTH
					,DMA.PROMO_CODE_ID
					,DM.UPDATE_DATE
/*					,DCD.STATUS_FLAG*/
				from 
					(DIM_MEMBER_BKP dm 
						INNER JOIN DET_member_card_acc_map DMA 
							ON DM.LOY_CARD_NUMBER = DMA.LOY_CARD_NUMBER)
/*						LEFT JOIN DET_CARD_DELIVERY DCD ON DM.MEMBER_ID = DCD.MEMBER_ID*/
		) by dwh;

/*		execute (*/
/*			create view LKP_CARD_DEL_STATUS as*/
/*			select MEMBER_id, status_flag from DET_CARD_DELIVERY*/
/*		) by dwh;*/

		DISCONNECT from dwh;
quit;

/* Isolate the AGGREGATED MEMBER list for flagging later */

proc sql noprint; 
	create table secondary_cards as
	select distinct secondary_acc as member_account_number from supplib.AGG_TREE_WITH_POINTS
	;
quit;

/*
proc sql noprint;
	create table work.points_expiry_members as
	select member_account_number, loy_card_number, expiry_points from SUPPLIB.Points_expiry_member_info
	WHERE 
		expiry_points not in (.,0) 
		and
		member_account_number ~= ""
		and
		loy_card_number ~= ""
	;	
quit;
*/

/*************************************************************
Propagate the updates to DWHLIB.DIM_MEMBER across to 
WHOUSE.MEMBER.
*************************************************************/

PROC SQL NOPRINT;
	select max(activity_date) into: max_activity_dttm from dwhlib.det_activity_bkp;
quit;

data _null_;
	call symput("points_as_on_dttm", put("&max_activity_dttm."dt, datetime20.)); 
run;
	
%put points_as_on_dttm: &points_as_on_dttm.;

data whouse.member_updt(
		rename=(
			zip = member_zip
			email = member_email	
			active_status_id = member_active_status_id
			mobile_phone = member_mobile_phone
			member_name1 = member_name
			mobile_no = cured_mobile
		) 
	)
/*	WORKLIB.FG_enrolled*/
/*	(*/
/*		keep=member_id*/
/*	)*/
	;

/*	format promo_code_id 8.;*/
	FORMAT CORRECTED_EMAIL_ADDRESS $100.;
	FORMAT EMAIL $100.;
	FORMAT MOBILE_NO $40.;

	FORMAT	EARN_ACTION_POINTS 8.;
	FORMAT	BURN_REV_ACTION_POINTS 8.;
	FORMAT	PREALL_EARN_ACTION_POINTS 8.;
	FORMAT	BURN_ACTION_POINTS 8.;
	FORMAT	EARN_REV_ACTION_POINTS 8.;
	FORMAT 	PREALL_BURN_ACTION_POINTS 8.;
	FORMAT	POINTS_UNDER_PROCESS 8.;
/*	FORMAT 	POINTS_TO_EXPIRE 8.;*/
	FORMAT  TRUE_ACTIVE_FLAG $15.;
	FORMAT  EVER_ACTIVE_FLAG $15.;

	retain pattern;

	if _n_ = 1 then do;	
/*		declare hash cthash(hashexp: 16, dataset: "WORK.MEMBER_CARD_TYPE_INFO");*/
/*		cthash.definekey("member_id");*/
/*		cthash.definedata("PROMO_CODE_ID");*/
/*		cthash.definedone();*/

/*		declare hash exphash(hashexp: 16, dataset:"WHOUSE.Expiry_points");*/
/*		exphash.definekey("MEMBER_ACCOUNT_NUMBER");*/
/*		exphash.definedata("POINTS_TO_EXPIRE");*/
/*		exphash.definedone();*/

		declare hash agghash(hashexp: 16, dataset:"SECONDARY_CARDS");
		agghash.definekey("MEMBER_ACCOUNT_NUMBER");
		agghash.definedone();

		declare hash pagghash(hashexp: 16, dataset:"WHOUSE.AGGREGATED_MEMBERS_PRIMARY");
		pagghash.definekey("MEMBER_ACCOUNT_NUMBER");
		pagghash.definedata(
				'EARN_ACTION_POINTS',
				'BURN_REV_ACTION_POINTS',
				'PREALL_EARN_ACTION_POINTS',
				'BURN_ACTION_POINTS',
				'EARN_REV_ACTION_POINTS',
				'PREALL_BURN_ACTION_POINTS',
				'POINTS_UNDER_PROCESS'
				/* , 'POINTS_TO_EXPIRE'*/
		);
		pagghash.definedone();

		declare hash emlhash(hashexp: 16, dataset:"SUPPLIB.EMAIL_REACHABLE");
		emlhash.definekey("EMAIL");
		emlhash.definedone();

		declare hash mblhash(hashexp: 16, dataset:"SUPPLIB.MBL_REACHABLE");
		mblhash.definekey("LOY_CARD_NUMBER");
		mblhash.definedata("MOBILE_NO");
		mblhash.definedone();

		declare hash evrhash(hashexp: 16, dataset:"supplib.EVER_ACTV_DATA");
		evrhash.definekey("MEMBER_ID");
		evrhash.definedata("EVER_ACTIVE_FLAG");
		evrhash.definedone();

		declare hash truhash(hashexp: 16, dataset:"supplib.TRUE_ACTV_DATA");
		truhash.definekey("member_ID");
		truhash.definedata("TRUE_ACTIVE_FLAG");
		truhash.definedone();

/*		declare hash cdhash(hashexp: 16, dataset: "DWHLIB.LKP_CARD_DEL_STATUS");*/
/*		cdhash.definekey("MEMBER_ID");*/
/*		cdhash.definedata("STATUS_FLAG");*/
/*		cdhash.definedone();*/

		declare hash tsthash(hashexp: 16, dataset: "SUPPLIB.BAD_LCN_MEMLIST");
		tsthash.definekey("LOY_CARD_NUMBER");
		tsthash.definedone();

		pattern = prxparse("s/[ \'\,\.\-]+/ /");
	end;

	set dwhlib.DIM_MEMBER_updt_VW
	;
	
	format sourced_association_id SID2DESC.;
	format promo_code_id PID2DESC.;
	format PHYSICAL_CARD_TYPE_ID CARD_TYPE.;
	format member_city $100.;
	format CARD_DEL_STATUS $5.;

/*	RCCT = cthash.find();*/
/*	rc0 = exphash.find();*/

	agg_flag = 0;
	rc3 = agghash.find();

	pagg_flag = 0;
	rc4 = pagghash.find();

	if rc3 = 0 then agg_flag = 1;
	if rc4 = 0 then pagg_flag = 1;

	rc5 = emlhash.find();
	if rc5 = 0 then CORRECTED_EMAIL_ADDRESS = EMAIL;

	rc6 = mblhash.find();

	TRUE_ACTIVE_FLAG="NOT-ACTIVE";
	EVER_ACTIVE_FLAG="NOT-ACTIVE";

	rc7 = evrhash.find();
	rc8 = truhash.find();

/*	rc9 = cdhash.find();*/

	CARD_DEL_STATUS = STATUS_FLAG;

	rc10 = tsthash.find();

	if rc10 = 0 then BAD_LCN_FLAG = 1;


	NL_DATA_FLAG = 0;

	IF	is_member_disabled ~= 1 
		and
		is_deleted ~= 1 
		and
		program_id ~= 2
		and
		active_status_id not in (5,11,14)
		and 
		bad_lcn_flag ~= 1
	THEN DO; 
		NL_DATA_FLAG = 1;
	END;


	array address (4) address_line1-address_line4;

	bad_mobile_phone = 0;
	bad_address = 0;
	bad_dob = 0;
	bad_email = 0;
	bad_zip = 0;

	member_city = compress(UPCASE(CITY),,'kA');

	IF 
		indexw(UPCASE(member_city), "DUMMY")
		OR 
		INDEXw(UPCASE(member_city), "TEST")
		OR
		INDEXw(UPCASE(member_CITY), "IMINT")
	then member_city = "";
	if strip(upcase(member_city)) in ('BANGALORE','BENGALURU','BENGALOORU','BANGLORE') then member_city = "BANGALORE";
	if strip(upcase(member_city)) in ('NEWDELHI','NEW-DELHI','NEW DELHI','DELHI','GURGAON', 'GHAZIABAD', 'GREATER NOIDA','NOIDA','FARIDABAD') then member_city = 'DELHI';
	if strip(upcase(member_city)) in ('HYDERABAD','HYD','HYDERBAD','SECUNDERABAD','SECUDERABAD','SECUNDARABAD','SECUNDERABAD','SECUNDERBAD','SECUNDRABAD','SECUNDRABAD8') then member_city = 'HYDERABAD';
	if strip(upcase(member_city)) in ('MUMBAI','NAVIMUMBAI','NEWMUMBAI','VASHI','THANE') then member_city = 'MUMBAI';
	if strip(upcase(member_city)) in (
		'CENNAI'
		'CHAENNAI'
		'CHENAAI'
		'CHENAI'
		'CHENNAI'
		'CHENNAI - 47'
		'CHENNAI - 600059'
		'CHENNAI - 600113'
		'CHENNAI 1'
		'CHENNAI -41'
		'CHENNAI,'
		'CHENNAI.'
		'CHENNAI-116'
		'CHENNAI-17'
		'CHENNAI-29'
		'CHENNAI-41'
		'CHENNAI-42'
		'CHENNAI-44'
		'CHENNAI-45'
		'CHENNAI-59'
		'CHENNAI-73'
		'CHENNAI-73.'
		'CHENNAI-96'
		'CHENNAIFFF'
		'CHENNAO'
		'CHENNIA'
		'CHENNNAI'
		'PERAMBURCHENNAI'
		'PORUR  CHENNAI'
		'SHOZINGANALLUR CHENNAI'
	) then member_city = 'CHENNAI';

	format member_name1 $100.;
	member_name=propcase(strip(full_name));

	member_name1 = prxchange(pattern, -1, member_name);

	if strip(upcase(member_name1)) IN ("", "IMINT MEMBER") 
		or INDEXw(upcase(member_NAME1), "NULL")
		or INDEXw(upcase(member_NAME1), "DUMMY")
		or INDEXw(upcase(member_NAME1), "TEST")
		OR INDEX(UPCASE(MEMBER_NAME1),'LTD')
		OR INDEX(UPCASE(MEMBER_NAME1),'LIMITED')
		OR INDEX(UPCASE(MEMBER_NAME1),'ENTERPRISE')
		OR INDEX(UPCASE(MEMBER_NAME1),'AGENCY')
		OR INDEX(UPCASE(MEMBER_NAME1),'INDIA')
		OR INDEX(UPCASE(MEMBER_NAME1),'TRADE')
		OR INDEX(UPCASE(MEMBER_NAME1),'PVT')
		OR INDEX(UPCASE(MEMBER_NAME1),'PRIVATE')
		OR INDEX(UPCASE(MEMBER_NAME1),'WORKS')
		OR INDEX(UPCASE(MEMBER_NAME1),'ENGINEERING')
		OR INDEX(UPCASE(MEMBER_NAME1),'HOSPITAL')
		OR INDEX(UPCASE(MEMBER_NAME1),'NURSING')
		OR INDEX(UPCASE(MEMBER_NAME1),'M/S. COMPANY')
		OR INDEX(UPCASE(MEMBER_NAME1),'AND CO')
		OR INDEX(UPCASE(MEMBER_NAME1),'SALES')
		OR INDEX(UPCASE(MEMBER_NAME1),'INDUS')
		OR INDEX(UPCASE(MEMBER_NAME1),'ROADWAYS')
		OR INDEX(UPCASE(MEMBER_NAME1),'DISTRIBUTORS')
		OR INDEX(UPCASE(MEMBER_NAME1),'FERTILIZERS')
		OR INDEX(UPCASE(MEMBER_NAME1),'DEVELOPERS')
		OR INDEX(UPCASE(MEMBER_NAME1),'FURNISHES')
		OR INDEX(UPCASE(MEMBER_NAME1),'CORP')
		OR INDEX(UPCASE(MEMBER_NAME1),'BANK')
		OR INDEX(UPCASE(MEMBER_NAME1),'SERVICE')
		OR INDEX(UPCASE(MEMBER_NAME1),'PRODUCT')
		OR INDEX(UPCASE(MEMBER_NAME1),'TYRES')
		OR INDEX(UPCASE(MEMBER_NAME1),'BROS')
		OR INDEX(UPCASE(MEMBER_NAME1),'BUILDERS')
		OR INDEX(UPCASE(MEMBER_NAME1),'LINKS')
		OR INDEX(UPCASE(MEMBER_NAME1),'INTL')
		OR INDEX(UPCASE(MEMBER_NAME1),'INTERNATIONAL')
		OR INDEX(UPCASE(MEMBER_NAME1),'ASSOCIATE')
		OR INDEX(UPCASE(MEMBER_NAME1),'TEXTILE')
		OR INDEX(UPCASE(MEMBER_NAME1),'HOUSE')
		OR INDEX(UPCASE(MEMBER_NAME1),'CHEMICALS')
		OR INDEX(UPCASE(MEMBER_NAME1),'LABOUR')
		OR INDEX(UPCASE(MEMBER_NAME1),'NATIONAL')
		OR INDEX(UPCASE(MEMBER_NAME1),'PUBLIC')
		OR INDEX(UPCASE(MEMBER_NAME1),'SONS')
		OR INDEX(UPCASE(MEMBER_NAME1),'MEDICAL')
		OR INDEX(UPCASE(MEMBER_NAME1),'AUTO')
		OR INDEX(UPCASE(MEMBER_NAME1),'BROTHER')
		OR INDEX(UPCASE(MEMBER_NAME1),'INVEST')
		OR INDEX(UPCASE(MEMBER_NAME1),'SHOP')
		OR INDEX(UPCASE(MEMBER_NAME1),'TRAVEL')
		OR INDEX(UPCASE(MEMBER_NAME1),'CONSTRUCT')
		OR INDEX(UPCASE(MEMBER_NAME1),'BUILD')
		OR INDEX(UPCASE(MEMBER_NAME1),'IMPEX')
		OR INDEX(UPCASE(MEMBER_NAME1),'HOLD')
		OR INDEX(UPCASE(MEMBER_NAME1),'PHARMA')
		OR INDEX(UPCASE(MEMBER_NAME1),'PLAST')
		OR INDEX(UPCASE(MEMBER_NAME1),'ACAD')
		OR INDEX(UPCASE(MEMBER_NAME1),'TRANS')
		OR INDEX(UPCASE(MEMBER_NAME1),'KENDRA')
		OR INDEX(UPCASE(MEMBER_NAME1),'CENTER')
		OR INDEX(UPCASE(MEMBER_NAME1),'STORE')
		OR INDEX(UPCASE(MEMBER_NAME1),'WINES')
		OR INDEX(UPCASE(MEMBER_NAME1),'JEWEL')
		OR INDEX(UPCASE(MEMBER_NAME1),'SILK')
		OR INDEX(UPCASE(MEMBER_NAME1),'SAREE')
		OR INDEX(UPCASE(MEMBER_NAME1),'SHIRT')
		OR INDEX(UPCASE(MEMBER_NAME1),'PANT')
		OR INDEX(UPCASE(MEMBER_NAME1),'METAL')
		OR INDEX(UPCASE(MEMBER_NAME1),'CLUB')
		OR INDEX(UPCASE(MEMBER_NAME1),'PAPER')
		OR INDEX(UPCASE(MEMBER_NAME1),'EMPLOY')
		OR INDEX(UPCASE(MEMBER_NAME1),'ASSN')
		OR INDEX(UPCASE(MEMBER_NAME1),'SYSTEM')
		OR INDEX(UPCASE(MEMBER_NAME1),'FASHION')
		OR INDEX(UPCASE(MEMBER_NAME1),'HOTEL')
		OR INDEX(UPCASE(MEMBER_NAME1),'EXIM')
		OR INDEX(UPCASE(MEMBER_NAME1),'PAINT')
		OR INDEX(UPCASE(MEMBER_NAME1),'CHEM')
		OR INDEX(UPCASE(MEMBER_NAME1),'HARDWARE')
		OR INDEX(UPCASE(MEMBER_NAME1),'SOFTWARE')
		OR INDEX(UPCASE(MEMBER_NAME1),'WEAR')
		OR INDEX(UPCASE(MEMBER_NAME1),'SCHOOL')
		OR INDEX(UPCASE(MEMBER_NAME1),'COLLAGE')
		OR INDEX(UPCASE(MEMBER_NAME1),'COLLEGE')
		OR ANYDIGIT(member_NAME1) > 0	
		OR ANYPUNCT(COMPRESS(member_NAME1,",'.- ")) > 0 
	then do;
		MEMBER_NAME1 = "Member";
	end;

	/* Member Gender */
	gender = strip(upcase(gender));
	if strip(gender) not in ("MALE", "FEMALE") then gender = "OTHER";

	net_total_points = sum(
			coalesce(EARN_ACTION_POINTS,0)
			, coalesce(BURN_REV_ACTION_POINTS,0)
			, coalesce(PREALL_EARN_ACTION_POINTS,0)
			, -coalesce(BURN_ACTION_POINTS,0)
			, -coalesce(EARN_REV_ACTION_POINTS,0)
			, -coalesce(PREALL_BURN_ACTION_POINTS,0)
			, -coalesce(POINTS_UNDER_PROCESS,0)
	);

	total_earn_points = SUM(			
			coalesce(EARN_ACTION_POINTS,0)
			, coalesce(BURN_REV_ACTION_POINTS,0)
			, coalesce(PREALL_EARN_ACTION_POINTS,0)
			);

	total_burn_points = SUM(
			coalesce(BURN_ACTION_POINTS,0)
			, coalesce(EARN_REV_ACTION_POINTS,0)
			, coalesce(PREALL_BURN_ACTION_POINTS,0)
			)
;

/*	if strip(mobile_phone) in (*/
/*						"9999999999"*/
/*						"8888888888"*/
/*						"7777777777"*/
/*						"6666666666"*/
/*						"5555555555"*/
/*						"4444444444"*/
/*						"3333333333"*/
/*						"2222222222"*/
/*						"1111111111"*/
/*						"0000000000"*/
/*						"") or length(strip(mobile_phone)) < 10 */
/*	then bad_mobile_phone=1;*/

	if strip(mobile_no) = "" then bad_mobile_phone = 1;

	if anyalpha(strip(zip)) 
		or anypunct(strip(zip))
		or	strip(zip) IN 
			("999999" "888888" "777777" "666666" "555555" "444444" "333333" "222222" "111111")    
		or input(strip(zip), 8.) < 100000
		or input(strip(zip), 8.) > 999999
		or length(strip(zip)) ~= 6
	then bad_zip=1;

/*	if index(email, "@") = 0 */
/*		or length(strip(email)) < 6 */
/*		or index(email, ".") = 0 */
/*		or index(upcase(email), "DUMMY") > 0*/
/*		or index(upcase(email), "NULL") > 0*/
/*		or index(upcase(email), "TEST") > 0*/
/*	then do;*/
/*		bad_email=1;*/
/*	end;*/

	if strip(corrected_email_address) = "" then bad_email = 1;

	do i = 1 to dim(address);
		if 
			length(strip(address(1))) < 2 
			or index(strip(upcase(address(i))), "DUMMY") > 0 
			or index(strip(upcase(address(i))), "TEST") > 0 
			or index(strip(upcase(address(i))), "NULL") > 0 
		then bad_address = 1;
	end;

	DOB = datepart(date_of_birth);
	age = INTCK("year", DOB, "&SYSDATE."D);

	if NOT (1952 <= year(DOB) <= 1994) then bad_dob = 1;

	if strip(member_account_number) ~= "" and strip(loy_card_number) ~= ""; 

	if _ERROR_ = 1 then _ERROR_ = 0;

	precedence = put(physical_card_type_id, card_type_prec.);

	reachability = "NONE";
	if strip(MOBILE_NO) ~= "" then reachability="SMS";
	if strip(CORRECTED_EMAIL_ADDRESS) ~= "" then reachability = "EMAIL";
	if strip(mobile_no) ~= "" and strip(corrected_email_address) ~= "" then reachability = "BOTH";

	PB_IMINT_FLAG="IMINT";
	if SIGNUP_DATE >= "01JUN2011:00:00:01"DT then PB_IMINT_FLAG="PB";

	format points_as_on date9.;
	points_as_on = DATEPART("&MAX_ACTIVITY_DTTM."dt);  

	keep
		member_account_number
		loy_card_number
		CARD_DEL_STATUS
		SOURCED_ASSOCIATION_ID
		ACTIVE_STATUS_ID
		PHYSICAL_CARD_TYPE_ID
		MEMBER_CARD_TYPE_ID
		PROMO_CODE_ID
		PROGRAM_ID
		MEMBER_NAME1
		FULL_NAME
/*		SALUTATION*/
		dob
		AGE
		gender
/*		address_line1-address_line4*/
		city
		member_city
		state_province
		zip
		email
		mobile_phone
		phone1
		PB_IMINT_FLAG
		AGG_FLAG
		PAGG_FLAG
		NL_DATA_FLAG
		TRUE_ACTIVE_FLAG
		EVER_ACTIVE_FLAG
		MEMBER_ID
		NET_TOTAL_POINTS
		EARN_ACTION_POINTS
		BURN_REV_ACTION_POINTS
		PREALL_EARN_ACTION_POINTS
      	BURN_ACTION_POINTS
		EARN_REV_ACTION_POINTS
		PREALL_BURN_ACTION_POINTS
		TOTAL_EARN_POINTS
		TOTAL_BURN_POINTS
/*		POINTS_TO_EXPIRE*/
     	POINTS_UNDER_PROCESS
		CARD_ISSUED_DATE
		SIGNUP_DATE
		bad_address
		bad_dob
		bad_email
		bad_mobile_phone
		bad_zip
		IS_MEMBER_DISABLED
		IS_DUMMY_MEMBER
		IS_DELETED
		PRECEDENCE
		CORRECTED_EMAIL_ADDRESS
		MOBILE_NO
		REACHABILITY
		POINTS_AS_ON
		bad_lcn_flag
		update_date
	;
run;

PROC SORT DATA = WHOUSE.MEMBER_UPDT;
	by member_id member_account_number loy_card_number;
run;

data whouse.member_updt
(
	rename=(
		CARD_DEL_STATUS_RET=	CARD_DEL_STATUS				
		SOURCED_ASSOCIATION_ID_RET=	SOURCED_ASSOCIATION_ID				
		MEMBER_ACTIVE_STATUS_ID_RET=	MEMBER_ACTIVE_STATUS_ID				
		PHYSICAL_CARD_TYPE_ID_RET=	PHYSICAL_CARD_TYPE_ID				
		MEMBER_CARD_TYPE_ID_RET=	MEMBER_CARD_TYPE_ID				
		PROMO_CODE_ID_RET=	PROMO_CODE_ID				
		PROGRAM_ID_RET=	PROGRAM_ID				
		MEMBER_NAME_RET=	MEMBER_NAME				
		FULL_NAME_RET=	FULL_NAME				
		dob_RET=	dob				
		AGE_RET=	AGE				
		gender_RET=	gender				
		city_RET=	city				
		member_city_RET=	member_city				
		state_province_RET=	state_province				
		member_zip_RET=	member_zip				
		member_email_RET=	member_email				
		member_mobile_phone_RET=	member_mobile_phone				
		phone1_RET=	phone1				
		PB_IMINT_FLAG_RET=	PB_IMINT_FLAG				
		AGG_FLAG_RET=	AGG_FLAG				
		PAGG_FLAG_RET=	PAGG_FLAG				
		NL_DATA_FLAG_RET=	NL_DATA_FLAG				
		TRUE_ACTIVE_FLAG_RET=	TRUE_ACTIVE_FLAG				
		EVER_ACTIVE_FLAG_RET=	EVER_ACTIVE_FLAG				
		NET_TOTAL_POINTS_RET=	NET_TOTAL_POINTS				
		EARN_ACTION_POINTS_RET=	EARN_ACTION_POINTS				
		BURN_REV_ACTION_POINTS_RET=	BURN_REV_ACTION_POINTS				
		PREALL_EARN_ACTION_POINTS_RET=	PREALL_EARN_ACTION_POINTS				
		BURN_ACTION_POINTS_RET=	BURN_ACTION_POINTS				
		EARN_REV_ACTION_POINTS_RET=	EARN_REV_ACTION_POINTS				
		PREALL_BURN_ACTION_POINTS_RET=	PREALL_BURN_ACTION_POINTS				
		TOTAL_EARN_POINTS_RET=	TOTAL_EARN_POINTS				
		TOTAL_BURN_POINTS_RET=	TOTAL_BURN_POINTS				
		POINTS_UNDER_PROCESS_RET=	POINTS_UNDER_PROCESS				
		CARD_ISSUED_DATE_RET=	CARD_ISSUED_DATE				
		SIGNUP_DATE_RET=	SIGNUP_DATE				
		bad_address_RET=	bad_address				
		bad_dob_RET=	bad_dob				
		bad_email_RET=	bad_email				
		bad_mobile_phone_RET=	bad_mobile_phone				
		bad_zip_RET=	bad_zip				
		IS_MEMBER_DISABLED_RET=	IS_MEMBER_DISABLED				
		IS_DUMMY_MEMBER_RET=	IS_DUMMY_MEMBER				
		IS_DELETED_RET=	IS_DELETED				
		PRECEDENCE_RET=	PRECEDENCE				
		CORRECTED_EMAIL_ADDRESS_RET=	CORRECTED_EMAIL_ADDRESS				
		CURED_MOBILE_RET=	CURED_MOBILE				
		REACHABILITY_RET=	REACHABILITY				
		POINTS_AS_ON_RET=	POINTS_AS_ON				
		bad_lcn_flag_RET=	bad_lcn_flag				
	))
;

	set whouse.member_updt;
		by member_id member_account_number loy_card_number
	;
	
	retain
		CARD_DEL_STATUS_RET		
		SOURCED_ASSOCIATION_ID_RET		
		MEMBER_ACTIVE_STATUS_ID_RET		
		PHYSICAL_CARD_TYPE_ID_RET		
		MEMBER_CARD_TYPE_ID_RET		
		PROMO_CODE_ID_RET		
		PROGRAM_ID_RET		
		MEMBER_NAME_RET		
		FULL_NAME_RET		
		dob_RET		
		AGE_RET		
		gender_RET		
		city_RET		
		member_city_RET		
		state_province_RET		
		member_zip_RET		
		member_email_RET		
		member_mobile_phone_RET		
		phone1_RET		
		PB_IMINT_FLAG_RET		
		AGG_FLAG_RET		
		PAGG_FLAG_RET		
		NL_DATA_FLAG_RET		
		TRUE_ACTIVE_FLAG_RET		
		EVER_ACTIVE_FLAG_RET		
		NET_TOTAL_POINTS_RET		
		EARN_ACTION_POINTS_RET		
		BURN_REV_ACTION_POINTS_RET		
		PREALL_EARN_ACTION_POINTS_RET		
		BURN_ACTION_POINTS_RET		
		EARN_REV_ACTION_POINTS_RET		
		PREALL_BURN_ACTION_POINTS_RET		
		TOTAL_EARN_POINTS_RET		
		TOTAL_BURN_POINTS_RET		
		POINTS_UNDER_PROCESS_RET		
		CARD_ISSUED_DATE_RET		
		SIGNUP_DATE_RET		
		bad_address_RET		
		bad_dob_RET		
		bad_email_RET		
		bad_mobile_phone_RET		
		bad_zip_RET		
		IS_MEMBER_DISABLED_RET		
		IS_DUMMY_MEMBER_RET		
		IS_DELETED_RET		
		PRECEDENCE_RET		
		CORRECTED_EMAIL_ADDRESS_RET		
		CURED_MOBILE_RET		
		REACHABILITY_RET		
		POINTS_AS_ON_RET		
		bad_lcn_flag_RET		
	;		

	if first.loy_card_number then do;
		CARD_DEL_STATUS_RET=	CARD_DEL_STATUS	;
		SOURCED_ASSOCIATION_ID_RET=	SOURCED_ASSOCIATION_ID	;
		MEMBER_ACTIVE_STATUS_ID_RET=	MEMBER_ACTIVE_STATUS_ID	;
		PHYSICAL_CARD_TYPE_ID_RET=	PHYSICAL_CARD_TYPE_ID	;
		MEMBER_CARD_TYPE_ID_RET=	MEMBER_CARD_TYPE_ID	;
		PROMO_CODE_ID_RET=	PROMO_CODE_ID	;
		PROGRAM_ID_RET=	PROGRAM_ID	;
		MEMBER_NAME_RET=	MEMBER_NAME	;
		FULL_NAME_RET=	FULL_NAME	;
		dob_RET=	dob	;
		AGE_RET=	AGE	;
		gender_RET=	gender	;
		city_RET=	city	;
		member_city_RET=	member_city	;
		state_province_RET=	state_province	;
		member_zip_RET=	member_zip	;
		member_email_RET=	member_email	;
		member_mobile_phone_RET=	member_mobile_phone	;
		phone1_RET=	phone1	;
		PB_IMINT_FLAG_RET=	PB_IMINT_FLAG	;
		AGG_FLAG_RET=	AGG_FLAG	;
		PAGG_FLAG_RET=	PAGG_FLAG	;
		NL_DATA_FLAG_RET=	NL_DATA_FLAG	;
		TRUE_ACTIVE_FLAG_RET=	TRUE_ACTIVE_FLAG	;
		EVER_ACTIVE_FLAG_RET=	EVER_ACTIVE_FLAG	;
		NET_TOTAL_POINTS_RET=	NET_TOTAL_POINTS	;
		EARN_ACTION_POINTS_RET=	EARN_ACTION_POINTS	;
		BURN_REV_ACTION_POINTS_RET=	BURN_REV_ACTION_POINTS	;
		PREALL_EARN_ACTION_POINTS_RET=	PREALL_EARN_ACTION_POINTS	;
		BURN_ACTION_POINTS_RET=	BURN_ACTION_POINTS	;
		EARN_REV_ACTION_POINTS_RET=	EARN_REV_ACTION_POINTS	;
		PREALL_BURN_ACTION_POINTS_RET=	PREALL_BURN_ACTION_POINTS	;
		TOTAL_EARN_POINTS_RET=	TOTAL_EARN_POINTS	;
		TOTAL_BURN_POINTS_RET=	TOTAL_BURN_POINTS	;
		POINTS_UNDER_PROCESS_RET=	POINTS_UNDER_PROCESS	;
		CARD_ISSUED_DATE_RET=	CARD_ISSUED_DATE	;
		SIGNUP_DATE_RET=	SIGNUP_DATE	;
		bad_address_RET=	bad_address	;
		bad_dob_RET=	bad_dob	;
		bad_email_RET=	bad_email	;
		bad_mobile_phone_RET=	bad_mobile_phone	;
		bad_zip_RET=	bad_zip	;
		IS_MEMBER_DISABLED_RET=	IS_MEMBER_DISABLED	;
		IS_DUMMY_MEMBER_RET=	IS_DUMMY_MEMBER	;
		IS_DELETED_RET=	IS_DELETED	;
		PRECEDENCE_RET=	PRECEDENCE	;
		CORRECTED_EMAIL_ADDRESS_RET=	CORRECTED_EMAIL_ADDRESS	;
		CURED_MOBILE_RET=	CURED_MOBILE	;
		REACHABILITY_RET=	REACHABILITY	;
		POINTS_AS_ON_RET=	POINTS_AS_ON	;
		bad_lcn_flag_RET=	bad_lcn_flag	;
	end;

	if last.loy_card_number;

	keep
		CARD_DEL_STATUS_RET		
		SOURCED_ASSOCIATION_ID_RET		
		MEMBER_ACTIVE_STATUS_ID_RET		
		PHYSICAL_CARD_TYPE_ID_RET		
		MEMBER_CARD_TYPE_ID_RET		
		PROMO_CODE_ID_RET		
		PROGRAM_ID_RET		
		MEMBER_NAME_RET		
		FULL_NAME_RET		
		dob_RET		
		AGE_RET		
		gender_RET		
		city_RET		
		member_city_RET		
		state_province_RET		
		member_zip_RET		
		member_email_RET		
		member_mobile_phone_RET		
		phone1_RET		
		PB_IMINT_FLAG_RET		
		AGG_FLAG_RET		
		PAGG_FLAG_RET		
		NL_DATA_FLAG_RET		
		TRUE_ACTIVE_FLAG_RET		
		EVER_ACTIVE_FLAG_RET		
		NET_TOTAL_POINTS_RET		
		EARN_ACTION_POINTS_RET		
		BURN_REV_ACTION_POINTS_RET		
		PREALL_EARN_ACTION_POINTS_RET		
		BURN_ACTION_POINTS_RET		
		EARN_REV_ACTION_POINTS_RET		
		PREALL_BURN_ACTION_POINTS_RET		
		TOTAL_EARN_POINTS_RET		
		TOTAL_BURN_POINTS_RET		
		POINTS_UNDER_PROCESS_RET		
		CARD_ISSUED_DATE_RET		
		SIGNUP_DATE_RET		
		bad_address_RET		
		bad_dob_RET		
		bad_email_RET		
		bad_mobile_phone_RET		
		bad_zip_RET		
		IS_MEMBER_DISABLED_RET		
		IS_DUMMY_MEMBER_RET		
		IS_DELETED_RET		
		PRECEDENCE_RET		
		CORRECTED_EMAIL_ADDRESS_RET		
		CURED_MOBILE_RET		
		REACHABILITY_RET		
		POINTS_AS_ON_RET		
		bad_lcn_flag_RET	
		MEMBER_ID
		MEMBER_ACCOUNT_NUMBER
		LOY_CARD_NUMBER	
	;		
run;

proc sort data = whouse.member_UPDT;
	by member_id member_account_number loy_card_number;
run;

/*PROC SORT DATA = WHOUSE.MEMBER PRESORTED;*/
/*	by member_id member_account_number loy_card_number;*/
/*run;*/

DATA WHOUSE.zz_MEMBER; 
	MERGE WHOUSE.MEMBER WHOUSE.MEMBER_UPDT;
		by member_id member_account_number loy_card_number;
run;

DATA whouse.zz_member
		(
			RENAME=
				(
					MOBILE_NO=CURED_MOBILE
				)
		);

	if 0 then set supplib.mbl_Reachable;

	if _n_ = 1 then do;

		declare hash emlhash(hashexp: 16, dataset:"SUPPLIB.EMAIL_REACHABLE(rename=(email=MEMBER_EMAIL))");
		emlhash.definekey("MEMBER_EMAIL");
		emlhash.definedone();

		declare hash mblhash(hashexp: 16, dataset:"SUPPLIB.MBL_REACHABLE");
		mblhash.definekey("LOY_CARD_NUMBER");
		mblhash.definedata("MOBILE_NO");
		mblhash.definedone();

		declare hash tsthash(hashexp: 16, dataset: "SUPPLIB.BAD_LCN_MEMLIST");
		tsthash.definekey("LOY_CARD_NUMBER");
		tsthash.definedone();

	end;

	set WHOUSE.zz_MEMBER(drop=CURED_MOBILE CORRECTED_EMAIL_ADDRESS reachability bad_email bad_mobile_phone);
		by member_id member_account_number loy_card_number;

	rc1 = emlhash.find();
	if rc1 = 0 then CORRECTED_EMAIL_ADDRESS = MEMBER_EMAIL;
	rc2 = mblhash.find();
	rc3 = tsthash.find();

	bad_mobile_phone = 0;
	bad_email = 0;
	bad_lcn_flag = 0;

	if rc3 = 0 then bad_lcn_flag = 1;
	if strip(mobile_no) = "" then bad_mobile_phone = 1;
	if strip(corrected_email_address) = "" then bad_email = 1;

	reachability = "NONE";
	if strip(MOBILE_NO) ~= "" then reachability="SMS";
	if strip(CORRECTED_EMAIL_ADDRESS) ~= "" then reachability = "EMAIL";
	if strip(mobile_no) ~= "" and strip(corrected_email_address) ~= "" then reachability = "BOTH";

	drop rc:;
run;

PROC DATASETS LIBRARY = WHOUSE NOLIST;
	MODIFY	
		zz_MEMBER (sortedby=member_id member_account_number loy_card_number)
	;
	INDEX CREATE LOY_CARD_NUMBER;
	INDEX CREATE MEMBER_ACCOUNT_NUMBER;
	INDEX CREATE MEMBER_ID;
/*	INDEX CREATE CURED_MOBILE;*/
/*	INDEX CREATE CORRECTED_EMAIL_ADDRESS;*/
/*	INDEX CREATE MEMBER_ZIP;*/
/*	INDEX CREATE NET_TOTAL_POINTS;*/
/*	INDEX CREATE MEMBER_CITY;*/
/*	INDEX CREATE REACHABILITY;*/
/*	INDEX CREATE NL_DATA_FLAG;*/
QUIT;

/*PROC DATASETS LIBRARY = WHOUSE NOLIST;*/
/*	DELETE*/
/*		YY_MEMBER*/
/*	;*/
/*	%IF %SYSFUNC(EXIST(WHOUSE.MEMBER)) %THEN %DO;*/
/*	MODIFY*/
/*		MEMBER*/
/*	;*/
/*	CHANGE*/
/*		MEMBER = YY_MEMBER*/
/*	;	*/
/*	%END;*/
/*	MODIFY*/
/*		ZZ_MEMBER*/
/*	;*/
/*	CHANGE*/
/*		ZZ_MEMBER = MEMBER*/
/*	;*/
/*QUIT;*/


%mend create_member_mart_updt;
