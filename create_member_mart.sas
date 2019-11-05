/********************************************************************************
*       Program      :   create_member_mart.sas                         			*
*                                                                       			*
*                                                                       			*
*       Owner        : Analytics, LSRPL                                 			*
*                                                                       			*
*       Author       :    LSRL-273                                      			*
*                                                                       			*
*       Input        : DWHLIB.MAP_ACC_AGGREGATION                       			*
*                      DWHLIB.DIM_MEMBER                                			*
*                                                                       			*
*                                                                       			*
*       Output       : SUPPLIB.AGG_TREE_WITH_POINTS                     			*
*                       WHOUSE.AGGREGATED_MEMBERS_PRIMARY                			*
*                                                                       			*
*                                                                       			*
*       Dependencies :                                                  			*
*                                                                       			*
*       Description  :                                                  			*
*                                                                       			*
*                                                                       			*
*       Usage        :                                                  			*
*                                                                       			*
*                                                                       			*
*                                                                       			*
*                                                                       			*
*       History      :                                                  			*
*       (Analyst)     (Date)    (Changes)                               			*
*      LSRL-273    09AUG2012    Added a step to de-dup aggregated a/c to			*
*                               have only one parent for a sec acct.    			*
*                               (C0001)                                 			*
*      LSRL-273    09AUG2012    Added additional columns from DIM_MEMBER			*
*                               for secondary_acc (C0002)               			*
*      LSRL-273    06NOV2012    changed is_deleted and                  			*
*                               is_member_disabled from ~=1 to <=0      			*
*                               (C0003)      										*
*      LSRL-C006    06NOV2012   Suppression of Index creation on       				*
*                               the Mart as per business requirement    			*
*                               (C0004)  											*	
*      LSRL-273     07JUN2013   Comparison of email reachability by    				*
*                               comparing upcased emails. (C0005)       			*
*      LSRL-273     11OCT2013   Added lookup for association details of 			*
*                               a given account from SUPPLIB.ICICI_AMEX_MI_FLAGGING *
*                               (C0006)                                 			*
*      LSRL-273     26OCT2013   Modified the formats for some of the long variables *
*                               to avoid Segmentation fault issues during load of hash *
*                               tables (C0007)                                 			*
*      LSRL-334    05NOV2013    Added an array step to convert missing values to zero *
*                               in the output for ICICI_AMEX_MI_FLAGGING variables *
*                                (C0008) 
*      LSRL-334    20NOV2013    Added an email notification step to address points *
*                               available as on date.								*
*                                (C0009) 
*      LSRL-334    16DEC2013    Added ASSN_FLAG to differenciate between ICICI and 	*
*                               AMEX members.										*
*                                (C0010) 
*      LSRL-334    25FEB2014    Added vodafone_flag to exclude vodafone enrolled  	*
*                               members specified by business    					*
*                                (C0011) 
*      LSRL-334    04MAR2014    Enabled indexes on whouse.member   					*
*                                (C0012) 											*
*      LSRL-334    04APR2014    Disable indexes on whouse.member as priority    	*
*                                (C0013) 											*
*      LSRL-334    14APR2014    changed the vf enrolled signup date ge 09feb2014  	*
*                               as required by business         					*
*                                (C0014) 
*      LSRL-334    22APR2014    reomved the vf flag as per business requirement  	*
*                               (C0015) 											*
*      LSRL-334    13MAY2014    creating a exclusion_flag for icici email/mobiles  	*
*                               as per business requirement , flags are created as	*
*        						icici_mbl_exclusion_flag and icici_eml_exclusion_flag*
*                              	(C0016) 											*
*      LSRL-334    13JUN2014    Adding a module to capture first entollment date customer wise*
*                              	(C0017) 
*      LSRL-324    12AUG2014    Removed module to capture first entollment date customer wise *
*                              	as it has added in another schedule (C0017)					  * 
************************************************************************************/

%macro create_member_mart;

/*

%INCLUDE "G:\sas\common\sasautos\compute_expiry_points.sas" / source2;
%compute_expiry_points;

%INCLUDE "G:\sas\common\sasautos\create_agg_mem_dsn_with_points.sas" / source2;
%create_agg_mem_dsn_with_points;

%INCLUDE "G:\sas\common\sasautos\compute_mem_active_flag.sas" / source2;
%compute_mem_active_flag;

*/

/* Creating one monolithic code to avoid failures */

/**************************************** Compute expiry points ***************************************************/

/*

data _null_;
	rundate="&rundate."d;
	CALL SYMPUT("date_cutoff", put(intnx("YEAR", intnx("QUARTER", RUNDATE, -0,"E"), -3, "S"), ddmmyyn8.));
run;

proc datasets library = dwhlib nolist;
	delete
		MEMBER_EXPIRY_POINTS
	;
quit;

proc sql noprint;
connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000); 
   %connecttooracle;
   EXECUTE(
   	create table member_expiry_points as
	select DISTINCT SUM(NVL(EARN_BURN_RESIDUE,ALLOCATED_POINTS)) AS POINTS_TO_EXPIRE, to_char(member_account_number) as member_account_number
	from DET_ACTIVITY
	WHERE ACTIVITY_DATE <= %cmpres(to_date(%NRBQUOTE('&date_cutoff.'), 'ddmmyyyy'))
	and activity_action_id in (1,5)
	group by member_account_number
   	) by dwh;
quit;

data %cmpres(WHOUSE.expiry_points);
	SET dwhlib.MEMBER_EXPIRY_POINTS;
run;

proc sql noprint;
 connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000);  
%connecttooracle;
   EXECUTE( 
   	DROP TABLE MEMBER_EXPIRY_POINTS
	) BY DWH;
quit; 

*/

/**************************************** Compute expiry points ENDS ***************************************************/


*%include '/sasdata/core_etl/prod/sas/programs/prog_update_reachability_frm_cmsdwh.sas';

/************************************** create_agg_mem_dsn_with_points *************************************************/

PROC DATASETS LIBRARY=DWHLIB NOLIST;
	delete
		TREE_CN1
		TREE_CN2
		AGG_MEM_TREE
	;
QUIT;


proc sql noprint;
   %connecttooracle;
   /*connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000); */
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
   %connecttooracle;
   /*connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000); */

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

proc datasets lib=dwhlib nolist;
	delete	
		prim_acc
		get_prim_lcn
	;
quit;

PROC SQL NOPRINT;
	CREATE TABLE DWHLIB.PRIM_ACC AS
	SELECT DISTINCT FINAL_ACC AS MEMBER_ACCOUNT_NUMBER FROM SUPPLIB.AGG_TREE_WITH_POINTS;
QUIT;

PROC SQL NOPRINT; 
    %connecttooracle;
	/*CONNECT TO ORACLE AS DWH (USER=DWH PASSWORD=manager path=DWHFO);*/
	execute (
		create view get_prim_lcn as
		select 
			to_char(dm.loy_card_number) as final_lcn
			, pa.member_account_number as final_acc
		from
			dim_member dm
			, prim_acc pa
		where
			dm.member_account_number = pa.member_account_number
	) by dwh;
	disconnect from dwh;
quit;

data SUPPLIB.AGG_TREE_WITH_POINTS;
	
	format FINAL_LCN $16.;

	if _n_ = 1 then do;
		declare hash primhash(dataset:"dwhlib.get_prim_lcn");
		primhash.definekey("FINAL_ACC");
		primhash.definedata("FINAL_LCN");
		primhash.definedone();
	end;

	set SUPPLIB.AGG_TREE_WITH_POINTS;
		by secondary_acc descending levelno;
	RC = primhash.find();

	if first.secondary_acc;

	drop rc;
run;

proc datasets lib=dwhlib nolist;
	delete	
		prim_acc
		get_prim_lcn
	;
quit;

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
    %connecttooracle;
   	/*connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000);*/ 
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

/*437*/
/*data whouse.member_1;
	set whouse.member;
run;*/

proc datasets lib=dwhlib nolist;
	delete 
		dim_member_vw
		LKP_CARD_DEL_STATUS
	;
quit;

proc datasets lib=whouse nolist;
	delete 
		member
/*		fg_enrolled_members*/
	;
quit;

proc sql noprint;
       %connecttooracle;
	  /* connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000);*/ 
	   execute (
				create view dim_MEMBER_vw as
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
/*					,DCD.STATUS_FLAG*/
				from 
					(cmsdwh.DIM_MEMBER dm 
						LEFT JOIN cmsdwh.DET_member_card_acc_map DMA ON DM.LOY_CARD_NUMBER = DMA.LOY_CARD_NUMBER)
/*						LEFT JOIN DET_CARD_DELIVERY DCD ON DM.MEMBER_ID = DCD.MEMBER_ID*/
/*				order by*/
/*					to_char(dm.member_account_number)*/
/*					, dm.member_id*/
/*					, to_char(loy_card_number)*/
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
		expiry_points not in (.,0)  
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

/* C00006 */

%INCLUDE "/sasdata/core_etl/prod/sas/includes/member_assoc_flagging.sas" / source2;

%global max_activity_dttm;

PROC SQL NOPRINT;
	select max(activity_date) into: max_activity_dttm from dwhlib.det_activity
		where activity_date lt "&rundate:00:00:00"dt ;
quit;




data _null_;
	call symput("points_as_on_dttm", put("&max_activity_dttm."dt, datetime20.)); 
run;
	
%put points_as_on_dttm: &points_as_on_dttm.;

data whouse.member(
		rename=(
			zip = member_zip
			/* C0005 */
			email_bkp = member_email	
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
	FORMAT MOBILE_NO $25.;

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

	/* C0006 */

	/* C0007 */
        format ICICICREDIT 8.;
        format ICICIDEBIT 8.;
        format ICICIOTHERS 8.;
        format AMEX 8.;
        format AMEX_ICICI 8.;
        format MI 8.;
	 format MI_UNIQ_ID2 $15.;

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

		/* C00006 */
		declare hash assochash(dataset:"SUPPLIB.ICICI_AMEX_MI_FLAGGING");
		assochash.definekey("MEMBER_ID");
		assochash.definedata("ICICICREDIT","ICICIDEBIT","ICICIOTHERS","AMEX","AMEX_ICICI","MI", "MI_UNIQ_ID2");
		assochash.definedone();

		declare hash tsthash(hashexp: 16, dataset: "SUPPLIB.BAD_LCN_MEMLIST");
		tsthash.definekey("LOY_CARD_NUMBER");
		tsthash.definedone();
/*C0016*/
		declare hash mblehash(hashexp: 16, dataset: "SUPPLIB.ICICI_MBL_Exclusion_List_12May14");
		mblehash.definekey("MOBILE_NO");
		mblehash.definedone();
/*C0016*/
		declare hash emlehash(hashexp: 16, dataset: "SUPPLIB.ICICI_EML_Exclusion_List_12May14");
		emlehash.definekey("EMAIL");
		emlehash.definedone();


		pattern = prxparse("s/[ \'\,\.\-]+/ /");
	end;

	set dwhlib.DIM_MEMBER_VW
	;
/*		by member_account_number member_id loy_card_number*/
/*	;*/

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

	/* C0005 */
	EMAIL_BKP = EMAIL;
	EMAIL = STRIP(UPCASE(EMAIL));
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

	IF /* C0003 */

		is_member_disabled <= 0 
		and
		is_deleted <= 0 
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
	member_name=compress(propcase(strip(full_name)),"0D0A"x);

	member_name1 = prxchange(pattern, -1, member_name);

	if strip(upcase(member_name1)) IN ("", "IMINT MEMBER") 
		or INDEXw(upcase(member_NAME1), "NULL")
		or INDEXw(upcase(member_NAME1), "DUMMY")
		or INDEXw(upcase(member_NAME1), "TEST")
		OR ANYDIGIT(member_NAME1) > 0	
		OR ANYPUNCT(COMPRESS(member_NAME1,",'.- ")) > 0 
	then do;
		MEMBER_NAME1 = "Member";
	end;

	if strip(upcase(member_name1)) IN ("", "IMINT MEMBER") 
		or INDEXw(upcase(member_NAME1), "NULL")
		or INDEXw(upcase(member_NAME1), "DUMMY")
		or INDEXw(upcase(member_NAME1), "TEST")
		OR INDEXw(UPCASE(MEMBER_NAME1),'LTD')
		OR INDEXw(UPCASE(MEMBER_NAME1),'LIMITED')
		OR INDEXw(UPCASE(MEMBER_NAME1),'ENTERPRISE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'AGENCY')
		OR INDEXw(UPCASE(MEMBER_NAME1),'INDIA')
		OR INDEXw(UPCASE(MEMBER_NAME1),'TRADE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'PVT')
		OR INDEXw(UPCASE(MEMBER_NAME1),'PRIVATE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'WORKS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'ENGINEERING')
		OR INDEXw(UPCASE(MEMBER_NAME1),'HOSPITAL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'NURSING')
		OR INDEXw(UPCASE(MEMBER_NAME1),'M/S. COMPANY')
		OR INDEXw(UPCASE(MEMBER_NAME1),'AND CO')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SALES')
		OR INDEXw(UPCASE(MEMBER_NAME1),'INDUS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'ROADWAYS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'DISTRIBUTORS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'FERTILIZERS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'DEVELOPERS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'FURNISHES')
		OR INDEXw(UPCASE(MEMBER_NAME1),'CORP')
		OR INDEXw(UPCASE(MEMBER_NAME1),'BANK')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SERVICE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'PRODUCT')
		OR INDEXw(UPCASE(MEMBER_NAME1),'TYRES')
		OR INDEXw(UPCASE(MEMBER_NAME1),'BROS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'BUILDERS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'LINKS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'INTL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'INTERNATIONAL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'ASSOCIATE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'TEXTILE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'HOUSE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'CHEMICALS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'LABOUR')
		OR INDEXw(UPCASE(MEMBER_NAME1),'NATIONAL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'PUBLIC')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SONS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'MEDICAL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'AUTO')
		OR INDEXw(UPCASE(MEMBER_NAME1),'BROTHER')
		OR INDEXw(UPCASE(MEMBER_NAME1),'INVEST')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SHOP')
		OR INDEXw(UPCASE(MEMBER_NAME1),'TRAVEL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'CONSTRUCT')
		OR INDEXw(UPCASE(MEMBER_NAME1),'BUILD')
		OR INDEXw(UPCASE(MEMBER_NAME1),'IMPEX')
		OR INDEXw(UPCASE(MEMBER_NAME1),'HOLD')
		OR INDEXw(UPCASE(MEMBER_NAME1),'PHARMA')
		OR INDEXw(UPCASE(MEMBER_NAME1),'PLAST')
		OR INDEXw(UPCASE(MEMBER_NAME1),'ACAD')
		OR INDEXw(UPCASE(MEMBER_NAME1),'TRANS')
		OR INDEXw(UPCASE(MEMBER_NAME1),'KENDRA')
		OR INDEXw(UPCASE(MEMBER_NAME1),'CENTER')
		OR INDEXw(UPCASE(MEMBER_NAME1),'STORE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'WINES')
		OR INDEXw(UPCASE(MEMBER_NAME1),'JEWEL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SILK')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SAREE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SHIRT')
		OR INDEXw(UPCASE(MEMBER_NAME1),'PANT')
		OR INDEXw(UPCASE(MEMBER_NAME1),'METAL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'CLUB')
		OR INDEXw(UPCASE(MEMBER_NAME1),'PAPER')
		OR INDEXw(UPCASE(MEMBER_NAME1),'EMPLOY')
		OR INDEXw(UPCASE(MEMBER_NAME1),'ASSN')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SYSTEM')
		OR INDEXw(UPCASE(MEMBER_NAME1),'FASHION')
		OR INDEXw(UPCASE(MEMBER_NAME1),'HOTEL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'EXIM')
		OR INDEXw(UPCASE(MEMBER_NAME1),'PAINT')
		OR INDEXw(UPCASE(MEMBER_NAME1),'CHEM')
		OR INDEXw(UPCASE(MEMBER_NAME1),'HARDWARE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SOFTWARE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'WEAR')
		OR INDEXw(UPCASE(MEMBER_NAME1),'SCHOOL')
		OR INDEXw(UPCASE(MEMBER_NAME1),'COLLAGE')
		OR INDEXw(UPCASE(MEMBER_NAME1),'COLLEGE')
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

	if not (age >= 18 and age < 100) then bad_dob = 1;

	if strip(member_account_number) ~= "" and strip(loy_card_number) ~= ""; 

	if _ERROR_ = 1 then _ERROR_ = 0;

	precedence = put(physical_card_type_id, card_type_prec.);

	length reachability $6;
	reachability = "NONE";
	if strip(MOBILE_NO) ~= "" then reachability="SMS";
	if strip(CORRECTED_EMAIL_ADDRESS) ~= "" then reachability = "EMAIL";
	if strip(mobile_no) ~= "" and strip(corrected_email_address) ~= "" then reachability = "BOTH";

	PB_IMINT_FLAG="IMINT";
	if SIGNUP_DATE >= "01JUN2011:00:00:01"DT then PB_IMINT_FLAG="PB";

	format points_as_on date9.;
	points_as_on = DATEPART("&MAX_ACTIVITY_DTTM."dt);  
	
	/* C0006 */
	rc_assoc=assochash.find();

	/* C0008 */
	array testmiss(6) ICICICREDIT ICICIDEBIT ICICIOTHERS AMEX AMEX_ICICI MI;                                            
	  do i = 1 to 6;                                              
	    if testmiss(i)=. then testmiss(i)=0;                                    
	  end;
	drop i; 

/*C0010*/
	format ASSN_FLAG $10.;
	if ((icicicredit = 1 or icicidebit = 1 or iciciothers = 1) and (amex ~= 1 and amex_icici ~= 1))
			then ASSN_FLAG = 'ICICI';

	else if (amex = 1 and ((icicicredit = 0 or icicidebit = 0 or iciciothers = 0) and amex_icici = 0))
			then ASSN_FLAG = 'AMEX';
	else if ((icicicredit = 1 or icicidebit = 1 or iciciothers = 1) and amex = 1)
			then ASSN_FLAG = 'AMEX_ICICI';

	else ASSN_FLAG =  'PB';
/*C0016*/
	rc_mble=mblehash.find();
	if rc_mble=0 then icici_mbl_exclusion_flag=1;
	else icici_mbl_exclusion_flag=0;
/*C0016*/
	rc_emle=emlehash.find();
	if rc_emle=0 then icici_eml_exclusion_flag=1;
	else icici_eml_exclusion_flag=0;

/*C0011*/
/*create a flag to filter vodafone enrolled customers from 15jan2014 as required by business*/
	/*C0014*/
/*create a flag to filter vodafone enrolled customers from 09feb2014 as required by business*/

	/*C0015*/

/*	if sourced_association_id = 84 and signup_date >= '09FEB2014:00:00:00'dt*/
/*			then vf_exclude_flag =1; */
/*	else vf_exclude_flag = 0;*/

	output whouse.member;
       FULL_NAME= compress(FULL_NAME,'09'x);
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
		email_bkp
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
/*C0011*/
	       ICICICREDIT
		ICICIDEBIT
              ICICIOTHERS
              AMEX
		AMEX_ICICI
		MI
		MI_UNIQ_ID2
		ASSN_FLAG
		/*C0011*/
		/*C0015*/
/*		vf_exclude_flag*/
/*C0016*/
		icici_mbl_exclusion_flag
		icici_eml_exclusion_flag
	;
run;


proc sql;
create table whouse.points_as_on
as
select
max(points_as_on) as points_as_on format=date9.

from whouse.member
;
quit;


/*PROC SORT DATA = WHOUSE.MEMBER;*/
/*	BY MEMBER_ACCOUNT_NUMBER;*/
/*RUN;*/
/* (C0004) */
/*C0012*/
;;
/*C0013*/
/*PROC DATASETS LIBRARY = WHOUSE NOLIST;*/
/*	MODIFY	*/
/*		MEMBER*/
/*	;*/
/*	INDEX CREATE LOY_CARD_NUMBER;*/
/*	INDEX CREATE MEMBER_ACCOUNT_NUMBER;*/
/*	INDEX CREATE MEMBER_ID;*/
/*	INDEX CREATE MEMBER_CITY;*/
/*	INDEX CREATE CURED_MOBILE;*/
/*	INDEX CREATE CORRECTED_EMAIL_ADDRESS;*/
/*	INDEX CREATE MEMBER_ZIP;*/
/*	INDEX CREATE NET_TOTAL_POINTS;*/
/*	INDEX CREATE REACHABILITY;*/
/*	INDEX CREATE NL_DATA_FLAG;*/
/*QUIT;*/

/*(C0009)*/

%include "/sasdata/core_etl/prod/sas/sasautos/send_mail.sas" / source2;

      %send_mail(
	  to_list=%str('dharmendrasinh.chavda@payback.in'
						'pradeep.tripathi_ext@payback.in'
						'sudhakar.srinivas@payback.in'
						'nagendra.j@payback.net'
						
					)
	, cc_list=%str('prashanth.reddy@payback.in' 'ramachandra.u_ext@payback.in')
    , sub=%str(Status of Points as on in Whouse.Member Mart)
    , body=%str(Hi All,|Data in Whouse.Member Mart is having Points_As_On &MAX_ACTIVITY_DTTM.|
			Thanks.)
	);


/*(C0017)*/

*%include "/sasdata/core_etl/prod/sas/includes/inc_compute_cust_enrolment_date.sas" / source2;

%mend create_member_mart;


