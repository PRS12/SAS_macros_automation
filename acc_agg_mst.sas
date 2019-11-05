%include '/sasdata/core_etl/prod/sas/includes/init_env.sas' /source2;

proc sql noprint;
    %connecttooracle;
   /*connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000); */
   EXECUTE(
			CREATE TABLE TREE_CN1 AS 
    		SELECT 
				DISTINCT 
					TO_CHAR(MEMBER_ACCOUNT_NEW) AS SECONDARY_ACC
					, TO_CHAR(MEMBER_ACCOUNT_NEW) AS FINAL_ACC
					, 1 AS LEVELNO
					, ADD_DATE
					, ADDED_BY
			FROM 
				CMSDWH.MAP_ACC_AGGREGATION 
			WHERE 
				MEMBER_ACCOUNT_NEW NOT IN (SELECT MEMBER_ACCOUNT_OLD FROM MAP_ACC_AGGREGATION)
	) BY DWH; 


	EXECUTE (
		CREATE TABLE TREE_CN2 AS 
	 	SELECT 
			CONNECT_BY_ROOT 
				TO_CHAR(AG.MEMBER_ACCOUNT_OLD) AS SECONDARY_ACC
	            , TO_CHAR(AG.MEMBER_ACCOUNT_NEW) AS FINAL_ACC
				, LEVEL AS LEVELNO 
				, ADD_DATE
				, ADDED_BY
	     FROM CMSDWH.MAP_ACC_AGGREGATION AG
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
              AGG_MEM_TREE1
	;
quit;


proc sql noprint;
   %connecttooracle;
   /*connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo' preserve_comments buffsize=10000); */
   EXECUTE (
      CREATE TABLE AGG_MEM_TREE1 COMPRESS NOLOGGING AS 
      SELECT A.*,
             TO_NUMBER(SECONDARY_ACC) AS SEC_AC
      FROM AGG_MEM_TREE A
   ) BY DWH;

   EXECUTE ( CREATE INDEX SEC_AC_IDX ON AGG_MEM_TREE1 (SEC_AC)) BY DWH;

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
		AGG_MEM_TREE1 A
		, CMSDWH.DIM_MEMBER B
		, CMSDWH.DET_MEMBER_CARD_ACC_MAP C
	WHERE
		A.SEC_AC=B.MEMBER_ACCOUNT_NUMBER
		and
		A.SEC_AC=C.MEMBER_ACCOUNT_NUMBER
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

	output out = AGGREGATED_MEMBERS_PRIMARY (
		RENAME=(_freq_=NO_OF_ACCTS) DROP = _TYPE_)
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
			CMSDWH.dim_member dm
			, prim_acc pa
		where
			dm.member_account_number = pa.member_account_number
	) by dwh;
	disconnect from dwh;
quit;


/* Deriving the best contact info for aggregated members */
proc sort data = supplib.agg_tree_with_points out=agg_tree_data (keep=loy_card_number secondary_acc levelno add_date final_acc);
	by loy_card_number add_date levelno;
run;

data sec_accounts_with_contact;
	
	format corrected_email_address $100.;
	format cured_mobile $40.;

	if _n_ = 1 then do;
		declare hash emlhash(DATASET:"DWHLIB.eml_rchable_meminfo");
		emlhash.definekey("loy_card_number");
		emlhash.definedata("corrected_email_Address");
		emlhash.definedone();

		declare hash mblhash(DATASET:"DWHLIB.mbl_reachable (rename=(mobile_no = cured_mobile))");
		mblhash.definekey("loy_card_number");
		mblhash.definedata("cured_mobile");
		mblhash.definedone();
	end;


	set agg_tree_data;
		by loy_card_number add_date levelno;

	rc1 = emlhash.find();
	rc2 = mblhash.find();

	retain first_agg_date;
	format first_agg_date datetime20.;

	if first.loy_card_number then do;
			first_agg_date = add_date;
	end;

	prim_ind = 0;	
	if final_acc = secondary_acc then prim_ind = 1;

	if last.loy_card_number;

	keep 
		FINAL_ACC
		secondary_acc
		first_agg_date
		corrected_email_address
		cured_mobile
		prim_ind
	;
run;

proc sort data = sec_accounts_with_contact;
	by final_Acc prim_ind first_agg_date;
run;

data templib.primary_with_effective_contacts;
	set sec_accounts_with_contact;
		by final_acc prim_ind first_agg_date;

	format cust_corrected_email_address $100.;
	format cust_cured_mobile $40.;

	retain cust_corrected_email_address;
	retain cust_cured_mobile;

	if first.final_acc then do;
		cust_corrected_email_address = '';
		cust_cured_mobile = '';
	end;

	if corrected_email_Address ~= '' then do;
		cust_corrected_email_address = corrected_email_address;
	end;

	if cured_mobile ~= '' then do;
		cust_cured_mobile = cured_mobile;
	end;

	if last.final_acc;

	keep final_acc cust_corrected_email_address cust_cured_mobile;
run;

data SASMART.ACCOUNT_AGGREGATION_MASTER;
	
	format FINAL_LCN $16.;
	format primary_member_id 12.;

	format cust_corrected_email_address $100.;
	format cust_cured_mobile $40.;
	format first_agg_date datetime20.;

	if 0 then do;

			set WHOUSE.AGGREGATED_MEMBERS_PRIMARY
			(
				keep=
					MEMBER_ACCOUNT_NUMBER 
					EARN_ACTION_POINTS
					BURN_REV_ACTION_POINTS
					PREALL_EARN_ACTION_POINTS
					BURN_ACTION_POINTS
					EARN_REV_ACTION_POINTS
					PREALL_BURN_ACTION_POINTS
					POINTS_UNDER_PROCESS
				rename=(
					member_account_number = final_acc
					EARN_ACTION_POINTS = EARN_ACTION_POINTS_agg 
					BURN_REV_ACTION_POINTS = BURN_REV_ACTION_POINTS_AGG
					PREALL_EARN_ACTION_POINTS = PREALL_EARN_ACTION_POINTS_AGG
					BURN_ACTION_POINTS = BURN_ACTION_POINTS_AGG
					EARN_REV_ACTION_POINTS = EARN_REV_ACTION_POINTS_AGG
					PREALL_BURN_ACTION_POINTS = PREALL_BURN_ACTION_POINTS_AGG
					POINTS_UNDER_PROCESS = POINTS_UNDER_PROCESS_AGG
				)
			);
	end;

	if _n_ = 1 then do;
		declare hash primhash(dataset:"dwhlib.get_prim_lcn");
		primhash.definekey("FINAL_ACC");
		primhash.definedata("FINAL_LCN");
		primhash.definedone();

		declare hash pmemhash(dataset:"SUPPLIB.AGG_TREE_WITH_POINTS (keep=member_id secondary_acc final_acc rename=(member_id=primary_member_id) where=(final_acc = secondary_acc))");
		pmemhash.definekey("FINAL_ACC");
		pmemhash.definedata("PRIMARY_MEMBER_ID");
		pmemhash.definedone();

		declare hash chnlhash(dataset:"templib.primary_with_effective_contacts");
		chnlhash.definekey("FINAL_ACC");
		chnlhash.definedata("CUST_CORRECTED_EMAIL_ADDRESS", "CUST_CURED_MOBILE");
		chnlhash.definedone();

		declare hash datehash(dataset:"sec_accounts_with_contact");
		datehash.definekey("secondary_acc");
		datehash.definedata("first_agg_date");
		datehash.definedone();

		declare hash summhash
		(
			dataset: "WHOUSE.AGGREGATED_MEMBERS_PRIMARY(keep=
					MEMBER_ACCOUNT_NUMBER 
					EARN_ACTION_POINTS
					BURN_REV_ACTION_POINTS
					PREALL_EARN_ACTION_POINTS
					BURN_ACTION_POINTS
					EARN_REV_ACTION_POINTS
					PREALL_BURN_ACTION_POINTS
					POINTS_UNDER_PROCESS
				rename=(
					member_account_number = final_acc
					EARN_ACTION_POINTS = EARN_ACTION_POINTS_agg 
					BURN_REV_ACTION_POINTS = BURN_REV_ACTION_POINTS_AGG
					PREALL_EARN_ACTION_POINTS = PREALL_EARN_ACTION_POINTS_AGG
					BURN_ACTION_POINTS = BURN_ACTION_POINTS_AGG
					EARN_REV_ACTION_POINTS = EARN_REV_ACTION_POINTS_AGG
					PREALL_BURN_ACTION_POINTS = PREALL_BURN_ACTION_POINTS_AGG
					POINTS_UNDER_PROCESS = POINTS_UNDER_PROCESS_AGG
				)
			)"
		);
		summhash.definekey("FINAL_ACC");
		summhash.definedata(ALL: "yes");
		summhash.definedone();
	end;

	set SUPPLIB.AGG_TREE_WITH_POINTS;
		by secondary_acc descending levelno;
	RC1 = primhash.find();

	rc1_mem = pmemhash.find();

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
        	);


	rc2 = summhash.find();
	
	net_total_points_AGG = sum(
			coalesce(EARN_ACTION_POINTS_agg,0)
			, coalesce(BURN_REV_ACTION_POINTS_agg,0)
			, coalesce(PREALL_EARN_ACTION_POINTS_agg,0)
			, -coalesce(BURN_ACTION_POINTS_agg,0)
			, -coalesce(EARN_REV_ACTION_POINTS_agg,0)
			, -coalesce(PREALL_BURN_ACTION_POINTS_agg,0)
			, -coalesce(POINTS_UNDER_PROCESS_agg,0)
	);

    total_earn_points_agg = SUM(			
        	coalesce(EARN_ACTION_POINTS,0)
        	, coalesce(BURN_REV_ACTION_POINTS,0)
        	, coalesce(PREALL_EARN_ACTION_POINTS,0)
               );

    total_burn_points_agg = SUM(
        	coalesce(BURN_ACTION_POINTS,0)
        	, coalesce(EARN_REV_ACTION_POINTS,0)
        	, coalesce(PREALL_BURN_ACTION_POINTS,0)
        	);


	rc_chnl = chnlhash.find();
	
	rc_dt = datehash.find();
		
	if first.secondary_acc;

	keep 
		ADD_DATE
		ADDED_BY
		final_acc
		FINAL_LCN
		LEVELNO
		LOY_CARD_NUMBER
		MEMBER_ID
		net_total_points
		net_total_points_AGG
		total_Earn_points
		total_earn_points_agg
		total_burn_points
		total_burn_points_agg
		POINTS_UNDER_PROCESS
		POINTS_UNDER_PROCESS_AGG
		primary_member_id
		PROMO_CODE_ID
		SECONDARY_ACC
		SOURCED_ASSOCIATION_ID
		cust_cured_mobile
		cust_corrected_email_Address
		FIRST_AGG_DATE
	;
run;

