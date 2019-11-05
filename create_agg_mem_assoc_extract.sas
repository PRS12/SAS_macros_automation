%macro create_agg_mem_assoc_extract;

options MAUTOSOURCE 
		MRECALL
		SASAUTOS=(
					"G:\FG\sasautos\reporting steps"
					"G:\FG\sasautos"
					"G:\sas\common\sasautos"
				)
		obs=max 
		fmtsearch=(formats)
		mprint 
		mlogic 
		symbolgen
;

%SET_RPT_ENV;

OPTIONS MPRINT MLOGIC SYMBOLGEN;

/* 
	Dependencies:
		create_agg_mem_dsn_with_points
*/

proc datasets library = DWHLIB NOLIST;
	DELETE 	AGG_TREE_WITH_POINTS;
	DELETE 	AGG_TREE_TEMP1;
	DELETE	AGG_TREE_TEMP2;
	DELETE 	AGG_TREE_SEC;
	DELETE  AGG_TREE_PRIM;
quit;

data dwhlib.agg_tree_with_points;
	set supplib.agg_tree_with_points;
run;

proc sql noprint;
   	connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
	execute 
	(
		create table agg_tree_temp1 as
		select 
			A.*
			, B.MEMBER_ID as MEMBER_ID_SEC
			, FULL_NAME AS FULL_NAME_SEC
			, DATE_OF_BIRTH AS DATE_OF_BIRTH_SEC
			, EMAIL AS EMAIL_ID_SEC
			, MOBILE_PHONE AS MOBILE_PHONE_SEC
			, MEMBER_CARD_TYPE_ID AS MEMBER_CARD_TYPE_ID_SEC
			, SOURCED_ASSOCIATION_ID AS ENROLLMENT_SID_SEC 
		from 
			agg_tree_with_points A
			, DIM_MEMBER B 
		WHERE
			to_char(B.member_account_number) = A.SECONDARY_ACC
	) by dwh;

	execute (
		create table agg_tree_sec as
		select 
			A.*
			, B.MEMBER_ASSOCIATION_ID AS MEMBER_ASSOC_ID_SEC 
			, B.ASSOCIATION_ID AS ASSOC_NO_SEC
			, B.IS_DELETED AS IS_SEC_ASSOC_DELETED
			, B.DELETE_REMARKS AS SEC_ASSOC_DELETE_REMARKS
			, B.DELETE_DATE AS SEC_ASSOC_DELETED_DATE
			from 
				agg_tree_temp1 A
				, dim_member_association B

		where
		A.member_id_sec = B.member_id
	) by dwh;

	execute 
	(
		create table agg_tree_temp2 as
		select 
			A.*
			, B.MEMBER_ID as MEMBER_ID_PRIM
			, FULL_NAME AS FULL_NAME_PRIM
			, DATE_OF_BIRTH AS DATE_OF_BIRTH_PRIM
			, EMAIL AS EMAIL_ID_PRIM
			, MOBILE_PHONE AS MOBILE_PHONE_PRIM
			, MEMBER_CARD_TYPE_ID AS MEMBER_CARD_TYPE_ID_PRIM
			, SOURCED_ASSOCIATION_ID AS ENROLLMENT_SID_PRIM 
		from 
			agg_tree_with_points A,
			DIM_MEMBER B 
		WHERE
			to_char(B.member_account_number) = a.final_acc
	) by dwh;

	execute (
		create table agg_tree_prim as
		select 
			A.*
			, B.MEMBER_ASSOCIATION_ID AS MEMBER_ASSOC_ID_PRIM 
			, B.ASSOCIATION_ID AS ASSOC_NO_PRIM
			, B.IS_DELETED AS IS_PRIM_ASSOC_DELETED
			, B.DELETE_REMARKS AS PRIM_ASSOC_DELETE_REMARKS
			, B.DELETE_DATE AS PRIM_ASSOC_DELETED_DATE
			from 
				agg_tree_temp2 A
				, DIM_MEMBER_ASSOCIATION B
		where
		A.MEMBER_ID_PRIM = B.member_id
	) by dwh;

	disconnect from dwh;
run;
quit;

data templib.agg_tree_prim;
	set dwhlib.agg_tree_prim;
run;

data templib.agg_tree_sec;
	set dwhlib.agg_tree_sec;
run;

proc sort data = templib.agg_tree_prim 
	(
	keep=
		FINAL_ACC 
		ASSOC_NO_PRIM
		IS_PRIM_ASSOC_DELETED
		PRIM_ASSOC_DELETE_REMARKS
		PRIM_ASSOC_DELETED_DATE
		FULL_NAME_PRIM
		DATE_OF_BIRTH_PRIM
		EMAIL_ID_PRIM
		MOBILE_PHONE_PRIM
		ASSOC_NO_PRIM
		IS_PRIM_ASSOC_DELETED
		MEMBER_ASSOC_ID_PRIM
		ENROLLMENT_SID_PRIM
	)
		nodupkey
	;
	by final_acc;
run;

proc sort data = templib.agg_tree_sec 
	(
	keep=
		SECONDARY_ACC
		MEMBER_ASSOC_ID_SEC
		ASSOC_NO_SEC
		IS_SEC_ASSOC_DELETED
		SEC_ASSOC_DELETE_REMARKS
		SEC_ASSOC_DELETED_DATE	
		MEMBER_ID_SEC
		FULL_NAME_SEC
		DATE_OF_BIRTH_SEC
		EMAIL_ID_SEC
		MOBILE_PHONE_SEC
		MEMBER_CARD_TYPE_ID_SEC
		ENROLLMENT_SID_SEC 
	)
		nodupkey
	;
	by secondary_acc;
run;


PROC SORT DATA = SUPPLIB.AGG_TREE_WITH_POINTS out=agg_tree_with_points;
	by secondary_acc;
RUN;

DATA agg_tree_with_sec_info;
	MERGE AGG_TREE_WITH_POINTS (in = in1) templib.agg_tree_sec (in = in2);
		by SECONDARY_ACC;
	IF IN1 AND IN2;

	ENROLMENT_SOURCE_SEC = put(ENROLLMENT_SID_SEC, SID2DESC.);
	MEMBER_CARD_TYPE_SEC = put(MEMBER_CARD_TYPE_ID_SEC, MCT2DESC.);

	DROP ENROLLMENT_SID_SEC MEMBER_CARD_TYPE_ID_SEC;
RUN;

PROC SORT DATA = AGG_TREE_WITH_SEC_INFO;
	BY FINAL_ACC;
RUN;

DATA TEMPLIB.FINALDATA;
	MERGE agg_tree_with_sec_info (in = in1) templib.agg_tree_prim (in = in2);
		by FINAL_ACC;
	IF IN1 AND IN2;

	ENROLMENT_SOURCE_PRIM = put(ENROLLMENT_SID_PRIM, SID2DESC.);

	drop ENROLLMENT_SID_PRIM;
RUN;

PROC DATASETS LIBRARY=DWHLIB NOLIST;
	DELETE AGG_TMP_DATA;
	DELETE AGG_ASSOC_DATA;
QUIT;

data dwhlib.AGG_TMP_DATA;
	set templib.FINALDATA;
RUN;

PROC SQL NOPRINT;
   	connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
	execute 
	(
		CREATE TABLE AGG_ASSOC_DATA AS
		SELECT 
			A.*
			, B.ADD_DATE AS DTTM_OF_AGG
			, B.ADDED_BY AS AGG_DONE_BY
		FROM
			AGG_TMP_DATA A
			, MAP_ACC_AGGREGATION B
		WHERE
			A.SECONDARY_ACC = TO_CHAR(B.MEMBER_ACCOUNT_OLD)
			AND
			A.FINAL_ACC = TO_CHAR(B.MEMBER_ACCOUNT_NEW)
			AND
			B.ADD_DATE >= to_date('01-nov-2011')
	) by dwh;

	disconnect from dwh;
quit;

proc sql noprint;
	create table member_card_type_info as
	select 
		put(member_account_number, 16.) as secondary_acc
		, put(promo_code_id, PID2DESC.) AS PROMO_CODE_SEC
	from 
		dwhlib.det_member_card_acc_map
	;
quit;


data SUPPLIB.AGG_MEMBERS_ASSOCIATION;

	RETAIN	SECONDARY_ACC;
	RETAIN	FULL_NAME_SEC;
	RETAIN	DATE_OF_BIRTH_SEC;
	RETAIN	EMAIL_ID_SEC;
	RETAIN	MOBILE_PHONE_SEC;
	RETAIN	ASSOC_NO_SEC;
	RETAIN	MEMBER_ASSOC_ID_SEC;
	RETAIN  ASSOC_CODE_SEC;
	RETAIN	IS_SEC_ASSOC_DELETED;
	RETAIN	SEC_ASSOC_DELETED_DATE;
	RETAIN 	MEMBER_CARD_TYPE_SEC;
	RETAIN	ENROLMENT_SOURCE_SEC;
	RETAIN	PROMO_CODE_SEC;
	RETAIN 	SEC_ASSOC_DELETE_REMARKS;
	RETAIN 	AGG_DONE_BY;
	RETAIN 	DATE_OF_AGG;
	RETAIN	FINAL_ACC;
	RETAIN	FULL_NAME_PRIM;
	RETAIN	DATE_OF_BIRTH_PRIM;
	RETAIN	EMAIL_ID_PRIM;
	RETAIN	MOBILE_PHONE_PRIM;
	RETAIN	ASSOC_NO_PRIM;
	RETAIN	IS_PRIM_ASSOC_DELETED;
	RETAIN	MEMBER_ASSOC_ID_PRIM;
	RETAIN 	ENROLMENT_SOURCE_PRIM;

	FORMAT PROMO_CODE_SEC $10.;

	if _n_ = 1 then do;
		declare hash prmhash(hashexp:16, dataset:"MEMBER_CARD_TYPE_INFO");
		prmhash.definekey("SECONDARY_ACC");
		prmhash.definedata("PROMO_CODE_SEC");
		prmhash.definedone();
	end;	
	
	SET DWHLIB.AGG_ASSOC_DATA (RENAME=
										(
											SEC_ASSOC_DELETED_DATE=SEC_ASSOC_DELETED_DTTM 
											DATE_OF_BIRTH_SEC = DTTM_OF_BIRTH_SEC
											DATE_OF_BIRTH_PRIM = DTTM_OF_BIRTH_PRIM
										)
								);

	rc = prmhash.find();

	FORMAT DATE_OF_AGG DDMMYYD10.;
	FORMAT SEC_ASSOC_DELETED_DATE DDMMYYD10.;
	FORMAT DATE_OF_BIRTH_SEC DDMMYYD10.;
	FORMAT DATE_OF_BIRTH_PRIM DDMMYYD10.;


	ASSOC_CODE_SEC = PUT(ASSOC_NO_SEC, AID2CODE.);
	DATE_OF_AGG = DATEPART(DTTM_OF_AGG);
	SEC_ASSOC_DELETED_DATE = DATEPART(SEC_ASSOC_DELETED_DTTM);
	DATE_OF_BIRTH_SEC = DATEPART(DTTM_OF_BIRTH_SEC);
	DATE_OF_BIRTH_PRIM = DATEPART(DTTM_OF_BIRTH_PRIM);

	keep
		SECONDARY_ACC
		FULL_NAME_SEC
		DATE_OF_BIRTH_SEC
		EMAIL_ID_SEC
		MOBILE_PHONE_SEC
		ASSOC_NO_SEC
		MEMBER_ASSOC_ID_SEC
	  	ASSOC_CODE_SEC
		IS_SEC_ASSOC_DELETED
		SEC_ASSOC_DELETED_DATE
	 	MEMBER_CARD_TYPE_SEC
		ENROLMENT_SOURCE_SEC
		PROMO_CODE_SEC
	 	SEC_ASSOC_DELETE_REMARKS
	 	AGG_DONE_BY
	 	DATE_OF_AGG
		FINAL_ACC
		FULL_NAME_PRIM
		DATE_OF_BIRTH_PRIM
		EMAIL_ID_PRIM
		MOBILE_PHONE_PRIM
		ASSOC_NO_PRIM
		IS_PRIM_ASSOC_DELETED
		MEMBER_ASSOC_ID_PRIM
		ENROLMENT_SOURCE_PRIM
	;

RUN;

proc export 
	data = SUPPLIB.AGG_MEMBERS_ASSOCIATION
	outfile = "G:\sas\output\AGG_MEMBERS\ops_agg_mem_assoc_info_&rundate..txt"
	dbms = dlm
	replace
	;
	delimiter = "|";
run;

proc datasets library = DWHLIB NOLIST;
	DELETE AGG_TREE_WITH_POINTS;
	DELETE AGG_TREE_TEMP1;
	DELETE AGG_TREE_TEMP2;
	DELETE AGG_TREE_PRIM;
	DELETE AGG_TREE_SEC;
	DELETE AGG_TMP_DATA;
	DELETE AGG_ASSOC_DATA;
quit;


proc sql;
	create table TEMPLIB.EFFECTIVE_AGGREGATIONS_&rundate. as
	select A.secondary_acc, A.final_acc from SUPPLIB.AGG_TREE_WITH_POINTS a, WHOUSE.AGGREGATED_MEMBERS_PRIMARY b where
	a.final_Acc = B.member_account_number;
quit;

proc export data = TEMPLIB.EFFECTIVE_AGGREGATIONS_&RUNDATE.
	outfile = "G:\sas\output\AGG_MEMBERS\ops_effective_aggregation_list_&rundate..txt"
	dbms = dlm
	replace;
	delimiter = "|";
run;

%mend create_agg_mem_assoc_extract;
