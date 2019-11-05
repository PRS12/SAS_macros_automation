%macro create_icici_mthly_seg_report(rundate=);

options mprint mlogic symbolgen obs=max;

%put &rundate.;

%if %symexist(DATE_CUTOFF) %then %do;
	%symdel DATE_CUTOFF;
%end;

data _null_;
	rundate="&rundate"d;
	REFDATE = intnx("month", rundate, -0, "E");
	CALL SYMPUT("refdate", refdate);
	CALL SYMPUT("date_cutoff", put(INTNX("YEAR", REFDATE, -1, "S"), ddmmyyn8.));
run;

%put CUT-OFF DATE = &date_cutoff.;

data _null_;
	REFDATE = put(&refdate., date9.);
	PUT 'REFDATE=' REFDATE;
	call symput("ref_date", refdate);
RUN;

proc datasets library = worklib nolist;
	delete 
		icici_mem_mart
	;
quit;

proc sql noprint;
   connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
   EXECUTE(
		create table work.icici_mem_mart as
		select 
			da.allocated_points
			, da.activity_value
			, da.activity_action_id
			, da.activity_date as activity_dttm
			, da.partner_id
			, TO_CHAR(DM.LOY_CARD_NUMBER) as loy_card_number
			, to_char(dm.member_account_number) as member_account_number
			, dm.member_id
			, dm.sourced_association_id
			, dm.physical_card_type_id
			, dm.signup_date as signup_dttm
			, (NVL(DM.EARN_ACTION_POINTS,0)+ NVL(DM.BURN_REV_ACTION_POINTS,0)+ NVL(DM.PREALL_EARN_ACTION_POINTS,0)) TOTAL_POINTS_EARNED,
			(NVL(DM.BURN_ACTION_POINTS,0)+ NVL(DM.EARN_REV_ACTION_POINTS,0)+ NVL(DM.PREALL_BURN_ACTION_POINTS,0)) TOTAL_POINTS_BURNED,
			((NVL(DM.EARN_ACTION_POINTS,0)+ NVL(DM.BURN_REV_ACTION_POINTS,0)+ NVL(DM.PREALL_EARN_ACTION_POINTS,0)) -
			(NVL(DM.BURN_ACTION_POINTS,0)+ NVL(DM.EARN_REV_ACTION_POINTS,0)+ NVL(DM.PREALL_BURN_ACTION_POINTS,0)))
			-NVL(DM.POINTS_UNDER_PROCESS,0) AS NET_TOTAL_POINTS
		from 
			dim_member dm LEFT JOIN det_activity da
			on 
				dm.member_account_number = da.member_account_number
				and
				da.activity_date > %cmpres(to_date(%NRBQUOTE('&date_cutoff.'), 'ddmmyyyy')) 
				and
				da.activity_date <= %cmpres(to_date(%NRBQUOTE('&ref_date.'), 'ddmmyyyy')) 
		where
			dm.sourced_association_id in (1,2)
			and
			dm.is_deleted != 1
			and
			dm.is_member_disabled != 1
			and
			dm.is_dummy_member != 1
			and
			dm.program_id != 2
			and
			dm.active_status_id not in (5,11,14)
   ) by dwh;
   disconnect from dwh;
quit;

proc format;
	value FMTPTS
		LOW - 500 = '<=500'
		501-2000 = '501-2000'
		2001-5000 = '2001-5000'
		5000 - HIGH = '>=5001'
	;
run;

proc format;
	value 
		txncnt
	1 = "Only 1"
	2 = "Only 2"
	3-High = "> 2"
	;
run;

proc format;
	value 
		earnptslab
	low-100 = "<=100"
	101-200 = "101-200"
	201-High = ">=201"
	;
run;



proc format;
	value RFMTPTS
		LOW - 500 = '<=500'
		501-1000 = '501-1000'
		1001-1500 = '1001-1500'
		1501-2000 = '1501-2000'
		2001-2500 = '2001-2500'
		2501-3000 = '2501-3000'
		3001-3500 = '3001-3500'
		3501-4000 = '3501-4000'
		4001-4500 = '4001-4500'
		4501-5000 = '4501-5000'
		5001-5500 = '5001-5500'
		5501-6000 = '5501-6000'
		6001-6500 = '6001-6500'
		6501-7000 = '6501-7000'
		7001-7500 = '7001-7500'
		7501-high = '>=7501'
	;
run;

PROC SORT data = WORKLIB.icici_mem_mart out = SASMART.ICICI_MEMBER_MART_1YR;
	BY MEMBER_ID DESCENDING ACTIVITY_DTTM;
run;

DATA SASMART.ICICI_MEM_SUMM_MART;
	set SASMART.ICICI_MEMBER_MART_1YR;
		by MEMBER_ID descending activity_dttm;

	array ACTIVITY_FLAGS (13) $ M0-M12;

	IF _N_ = 1 THEN DO;
		RETAIN EARN_COUNT_30D;
		RETAIN EARN_POINT_30D;
		RETAIN ICICI_EARN_POINT_30D;

		RETAIN ICICI_ACTV_FLAG;
		RETAIN PB_ACTV_FLAG;

		RETAIN M0-M12;
	END;

	if first.member_ID then do;

		ICICI_ACTV_FLAG = "INACTIVE";
		PB_ACTV_FLAG = "INACTIVE";

		EARN_COUNT_30D = 0;
		EARN_POINT_30D = 0;
		ICICI_EARN_POINT_30D = 0;

		DO i = 1 to dim(activity_flags);
			activity_flags(i) = "NONE";
		END; 
	end;

	FORMAT ACTIVITY_DATE DATE9.;
	FORMAT SIGNUP_DATE DATE9.;
	activity_date = DATEPART(ACTIVITY_DTTM);
	signup_date = DATEPART(SIGNUP_DTTM);

	if ACTIVITY_ACTION_ID IN (1,5) then do;
		if INTNX("day", &refdate., -30)  <= activity_date <= INTNX("day", &refdate., -0) then do;

			EARN_COUNT_30D = SUM(EARN_COUNT_30D, 1);
			EARN_POINT_30D = SUM(EARN_POINT_30D, ALLOCATED_POINTS);

			if PARTNER_ID in (163238, 250643, 312341, 312927) then do;
				ICICI_ACTV_FLAG="30D";
				ICICI_EARN_POINT_30D = SUM(ICICI_EARN_POINT_30D, ALLOCATED_POINTS);
			end;
			else do;
				PB_ACTV_FLAG = "30D";
			end;
		end;
		else if INTNX("day", &refdate., -90)  <= activity_date <= INTNX("day", &refdate., -31) then do;
			if PARTNER_ID in (163238, 250643, 312341, 312927) then do;
				if ICICI_ACTV_FLAG = "INACTIVE" then ICICI_ACTV_FLAG = "31-90D";
			end;
			else do;
				IF PB_ACTV_FLAG = 'INACTIVE' then PB_ACTV_FLAG = "31-90D";
			end;
		end;
		else if INTNX("day", &refdate., -360)  <= activity_date <= INTNX("day", &refdate., -91) then do;
			if PARTNER_ID in (163238, 250643, 312341, 312927) then do;
				if ICICI_ACTV_FLAG = "INACTIVE" then ICICI_ACTV_FLAG = "91-360D";
			end;
			else do;
				IF PB_ACTV_FLAG = 'INACTIVE' then PB_ACTV_FLAG = "91-360D";
			end;
		end;
		
		/* For members signed up last year, capture indicators on their presence in ICICI & PB network for earns */
		IF signup_date > INTNX("YEAR", &REFDATE., -1, "S") AND SIGNUP_DATE ~= 0 then do;
			TXN_AGE = intck("MONTH", SIGNUP_DATE, ACTIVITY_DATE) + INTCK("month", INTNX("YEAR", &REFDATE., -1, "S"), SIGNUP_DATE);
			
			if txn_age >= 0 then do;

				IF partner_id in (163238, 250643, 312341, 312927) then do;
					if STRIP(UPCASE(activity_flags(TXN_AGE+1))) = "NONE" then do; 
						activity_flags(TXN_AGE+1) = "ICICI";
					end;
					else do;
						activity_flags(TXN_AGE+1) = "BOTH";
					end;
				END;
				ELSE DO;
					if STRIP(UPCASE(activity_flags(TXN_AGE+1))) = "NONE" then do; 
						activity_flags(TXN_AGE+1) = "PB";
					end;
					else do;
						activity_flags(TXN_AGE+1) = "BOTH";
					end;
				END;

			end;
		end;

	end;


	IF LAST.MEMBER_ID then do;

		/* DEBIT & CREDIT */
		if sourced_association_id = 1 THEN DO;
			enrollment = "CREDIT";
		end;
		else do;
			enrollment = "DEBIT";
		end; 

		/* CARDED & NON_CARDED */
		acct_type = put(physical_card_type_id, CARD_TYPE.);

		/* Points' slab creation */
		POINT_SLAB = PUT(NET_TOTAL_POINTS, fmtpts.);

		output;
	end;
	DROP ACTIVITY_DTTM SIGNUP_DTTM I;
RUN;

/* Reporting piece */
/*
ods listing close;
ods results off;
ods tagsets.excelxp file = "G:\sas\output\icici\monthly\ICICI_segmentation_report_&rundate..xls"
	style = sasweb;

ods tagsets.excelxp options(
		embedded_titles = 'yes'
		sheet_interval = 'none'
		sheet_name = 'Table 1'
		zoom = '80'
	);

	title '';

	proc tabulate data = SASMART.ICICI_MEM_SUMM_MART;
		class
			enrollment
			acct_type
			point_slab
			ICICI_ACTV_FLAG
			PB_ACTV_FLAG
		;
		var
			net_total_points
		;

		TITLE "Cross-tab of counts by recency of activity";
		table
			ENROLLMENT=""*ACCT_TYPE=""*ICICI_ACTV_FLAG="" ALL="GRAND TOTAL"
			,
			(
				PB_ACTV_FLAG*N=""
			)	/ BOX={LABEL="ICICI SEGMENTATION REPORT - table 1"}
		;

		TITLE1 "Cross-tab of net points balance by recency of activity";
		table 
			ENROLLMENT=""*ACCT_TYPE=""*ICICI_ACTV_FLAG="" ALL="GRAND TOTAL"
			,
			(
				PB_ACTV_FLAG*NET_TOTAL_POINTS=""*SUM=""
			)	/ BOX={LABEL="ICICI SEGMENTATION REPORT - table 2"}
		;

quit;

ods tagsets.excelxp options(
		embedded_titles = 'yes'
		sheet_interval = 'none'
		sheet_name = 'Table 2'
		zoom = '90'
	);

	proc tabulate data = SASMART.ICICI_MEM_SUMM_MART;
	TITLE "30D txn summary by frequency";

	where EARN_COUNT_30D >= 1;
		class
			enrollment
			acct_type
			earn_count_30D	
		;
		format earn_count_30D txncnt.;
		var
			net_total_points
		;

		tables 
			(ENROLLMENT="" ALL="Grand Total")
				*
					(ACCT_TYPE="" All="Total")
						*
							(EARN_COUNT_30D="" All="Total"),  
				(
					N="# of customers"
					net_total_points=""*SUM="Points Balance"
				)
			/ BOX={LABEL="ICICI SEGMENTATION REPORT"};
		;
quit;


ods tagsets.excelxp options(
		embedded_titles = 'yes'
		sheet_interval = 'none'
		sheet_name = 'Table 3'
		zoom = '90'
	);

	proc tabulate data = SASMART.ICICI_MEM_SUMM_MART;
	TITLE "30D txn summary by points earned";
	where EARN_POINT_30D >= 1;
		class
			enrollment
			acct_type
			earn_point_30D	
		;
		format earn_POINT_30D earnptslab.;
		var
			net_total_points
		;

		tables 
			(ENROLLMENT="" ALL="Grand Total")
				*
					(ACCT_TYPE="" All="Total")
						*
							(EARN_POINT_30D="" All="Total"),  
				(
					N="# of customers"
					net_total_points=""*SUM="Points Balance"
				)
			/ BOX={LABEL="ICICI SEGMENTATION REPORT"};
		;
quit;


ods tagsets.excelxp options(
		embedded_titles = 'yes'
		sheet_interval = 'none'
		sheet_name = 'Table 4'
		zoom = '90'
	);

	proc tabulate data = SASMART.ICICI_MEM_SUMM_MART;
	TITLE "30D txn summary: points earned & share of ICICI";
	where EARN_count_30D >= 1;
		class
			enrollment
			acct_type
		;
		format earn_POINT_30D earnptslab.;
		var
			earn_point_30D
			icici_earn_point_30D
		;

		tables 
			(ENROLLMENT="" ALL="Grand Total")
				*
					(ACCT_TYPE="" All="Total")
			,
				(
					EARN_POINT_30D=""*SUM="Total points collected"
					ICICI_EARN_POINT_30D=""*SUM="Points contributed by ICICI"
				)
			/ BOX={LABEL="ICICI SEGMENTATION REPORT"};
		;
quit;

ods tagsets.excelxp options(
		embedded_titles = 'yes'
		sheet_interval = 'none'
		sheet_name = 'Table 6'
		zoom = '80'
	);

	proc tabulate data = SASMART.ICICI_MEM_SUMM_MART;
	TITLE "Month-wise txn summary since enrollment";
		where signup_date > INTNX("YEAR", &REFDATE., -1, "S");
		class
			enrollment
			SIGNUP_DATE
			M0-M12
		;

		format signup_date MONYY7.;

		tables 
		ENROLLMENT=""
			* signup_date="" ALL="Grand Total"
			,
			ALL="Enrolments" (M0-M12)*N=""
				/ BOX={LABEL="Enrolment Month"};
		;
quit;

ods tagsets.excelxp close;
ods results on;
ods listing;
*/

proc datasets library = WORKLIB nolist;
	delete	
		icici_mem_mart
	;
quit;

%mend create_icici_mthly_seg_report;
