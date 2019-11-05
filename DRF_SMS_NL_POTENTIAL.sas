/************************************************************************
*       Program      :  Prep_campaign_activity_base.sas                	*
*                                                                       *
*                                                                       *
*       Owner        : 	Analytics, LSRPL                                *
*                                                                       *
*       Author       :  LSRL-324,273                                 	*
*                                                                       *
*       Input        : DWHLIB.PB_TRANS_FACT_MASTER (view)               *
*                      SUPPLIB.EMAIL_REACHABLE                          *
*                      SUPPLIB.MBL_REACHABLE                            *
*                                                                       *
*       Output       : WHOUSE.CAMPAIGN_ACTIVITY_SUMMARY                 *
*                                                                       *
*                                                                       *
*                                                                       *
*       Dependencies :                                                  *
*                                                                       *
*       Description  :                                                  *
*                                                                       *
*                                                                       *
*       Usage        :                                                  *
*                                                                       *
*                                                                       *
*                                                                       *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
************************************************************************/

proc printto log="G:\sas\common\logs\DRF_EARN_BURN_&sysdate9..txt";
run;

options obs=max;

data _null_;
a = put(datetime(),datetime18.);
put "start Time -   " a;
run;

/*	~~~~~~~ Formats for Partner short cuts and year n month from datetime ~~~~~~~ */

/* Based on P_COMMERCIAL_NAME, which is a result of formatted partner_id by PART2NM format */
PROC FORMAT LIBRARY = FORMATS;
	VALUE $ PARTGROUP

	"BIGBAZAAR" 	= "BIGBAZAAR"
	"FOODBAZAAR" 	= "FOODBAZAAR"
	"CENTRAL" 		= "CENTRAL"
	"BRANDFACTORY" 	= "BRANDFACTORY"
	"HOMETOWN" 		= "HOMETOWN"
	"EZONE" 		= "EZONE"
	"EZONEONLINE" 	= "EZONEONLINE"
	"FUTUREBAZAAR" 	= "FUTUREBAZAAR"
	"PANTALOONS" 	= "PANTALOONS"
	"FOODHALL" 		= "FOODHALL"
	"FOODRIGHT" 	= "FOODRIGHT"
	"FBB" 			= "FBB"
	"HPCL" 			= "HPCL"
	"MEGAMART" 		= "MEGAMART"

	"MMT_INTL_PKG"  = "MMT"
	"MMT_INTL_AIR_TCKT"   	=   "MMT"
	"MMT_CARS"   	= "MMT"
	"MMT"   		= "MMT"
	"MMT_BUS"   	= "MMT"
	"MMT_DOM_AIR_TCKT"		=   "MMT"
	"MMT_AIRTKT"   	= "MMT"
	"MMT_HOTELS"   	= "MMT"
	"MMT_DOM_PKG"  	= "MMT"
	"MAKEMYTRIP(INDIA)PVT.LTD."   =   "MMT"
	"MMT_FPH"   	= "MMT"

	"MKRETAIL" 		= "MKRETAIL"
	"UNIVERCELL" 	= "UNIVERCELL"
	"ICICIBANKCREDIT" 		= "ICICICREDIT"
	"ICICIBANKDEBIT"= "ICICIDEBIT"
	"ICICIOTHERS" 	= "ICICIOTHERS"
	"BOOKMYSHOW" 	= "BOOKMYSHOW"
	"PLANETSPORTS"  = "PLANETSPORTS"   /* added below 7 partners on 26-10-2012 */
	"BABYOYE"  		= "BABYOYE"
	"EDABBA"  		= "EDABBA"
	"FIRSTCRY"  	= "FIRSTCRY"
	"KOOVS"  		= "KOOVS"
	"PERFUME2ORDER" = "PERFUME2ORDER"
	"SURATDIAMOND"  = "SURATDIAMOND"
	"VALYOO"  		= "VALYOO"
	"FERNSNPETALS"  = "FERNSNPETALS"
	"LETSBUY"   	= "LETSBUY"
	"MAGZINEMALL"   = "MAGZINEMALL"
	"PLAYGROUNDONLINE"   =    "PLAYGROUNDONLINE"
	"PURPLLE"   	= "PURPLLE"
	OTHER 			= "PB N/W"
	;
run;


PROC FORMAT;
	picture dt2yrmm (default=10)
		other="%Y%0m" (datatype=datetime)
	;
VALUE $PART_ST
		"BIGBAZAAR"				=		"FG_BBZ"
		"FOODBAZAAR"			=		"FG_FOB"
		"CENTRAL"				=		"FG_CTL"
		"BRANDFACTORY"			=		"FG_BF"
		"HOMETOWN"				=		"FG_HTN"
		"EZONE"					=		"FG_EZ"
		"FUTUREBAZAAR"			=		"FG_FUB"
		"PANTALOONS"			=		"FG_PL"
		"FOODHALL"				=		"FG_FHL"
		"FOODRIGHT"				=		"FG_FRT"
		"FBB"					=		"FG_FBB"
		"PLANETSPORTS"  		=   	"FG_PLA"

		"HPCL"					=		"HPCL"
		"MEGAMART"				=		"MM"
		"MMT"					=		"MMT"
		"MKRETAIL"				=		"MKR"
		"UNIVERCELL"			=		"UNI"
		"ICICICREDIT"			=		"ICICR"
		"ICICIDEBIT"			=		"ICIDE"
		"ICICIOTHERS"			=		"PBN"  
		"BOOKMYSHOW"			=		"BMS"
		"PB N/W"				=		"PBN"

		"BABYOYE"   			=   	"ONLINE"
		"EDABBA"   				=   	"ONLINE"
		"FIRSTCRY"   			=   	"ONLINE"
		"KOOVS"   				=   	"ONLINE"
		"PERFUME2ORDER" 		= 		"ONLINE"  
		"SURATDIAMOND"  		=   	"ONLINE"
		"VALYOO"   				=   	"ONLINE"
		'AAPNORAJASTHANSHOP'	=   	'ONLINE'
		'ASMIEXCLUSIVE'	  		=   	'ONLINE'
		'BOOKMYKHANA'	  		=   	'ONLINE'
		'CHOCOLATEJUNCTION'	  	=   	'ONLINE'
		'FERNSNPETALS'	  		=   	'ONLINE'
		'GIFT360'	  			=   	'ONLINE'
		'GIFTCARDINDIA'	  		=   	'ONLINE'
		'GKVALE'	  			=   	'ONLINE'
		'INDIANCOOKERY'	  		=   	'ONLINE'
		'JAGSONS'	  			=   	'ONLINE'
		'LETSBUY'	  			=   	'ONLINE'
		'MAGZINEMALL'	  		=   	'ONLINE'
		'MYDALA'	  			=   	'ONLINE'
		'NAAPTOL'	  			=   	'ONLINE'
		'OTHERRETAIL'	  		=   	'ONLINE'
		'PLAYGROUNDONLINE'	  	=   	'ONLINE'
		'PLUGSNWIRES'	  		=   	'ONLINE'
		'PURPLLE'	  			=   	'ONLINE'
		'UTSAVFASHION'	  		=   	'ONLINE'
		'ZOOMIN'	  			=   	'ONLINE'

		'AMEX'    				=     	'B2E'
		'COGNIZANT'    			=     	'B2E'
		'DUPONT'    			=     	'B2E'
		'FIDELITY'    			=     	'B2E'
		'HCL'    				=     	'B2E'
		'INFOSYS'    			=     	'B2E'
		'KOTAKBANK'    			=     	'B2E'
		'METLIFE'    			=     	'B2E'
		'NESS'    				=     	'B2E'
;
quit;


DATA _NULL_;
	call symput("CUTOFF", put(intnx("month", "&rundate."d, -6, "S"), DATE9.));
run;

%PUT CUTOFF DATE = &cutoff. ;

PROC SORT DATA=DWHLIB.PB_TRANS_FACT_MASTER 
	(
		KEEP=
			LOY_CARD_NUMBER
			ACTIVITY_DATE
			P_COMMERCIAL_NAME
			ACTIVITY_VALUE
			ALLOCATED_POINTS
			ACTIVITY_ACTION_ID
	)
	OUT = templib.CMPGN_EARN_BASE 
;
	WHERE
		activity_date >= "01MAY2012"d and activity_date < '05DEC2012'd
		and
		ACTIVITY_ACTION_ID in (1,5)
	;
	by 
			LOY_CARD_NUMBER
			P_COMMERCIAL_NAME		
			ACTIVITY_DATE
	;
run;

Data templib.CMPGN_EARN_BASE(RENAME=(ACTIVITY_DATE1=ACTIVITY_DATE));
	set templib.CMPGN_EARN_BASE;
		PARTNER_COMMERCIAL = PUT(P_COMMERCIAL_NAME,$PARTGROUP.);
		ACTIVITY_DATE1 = DATEPART(ACTIVITY_DATE);
		FORMAT ACTIVITY_DATE1 DATE9.;
		DROP ACTIVITY_DATE;
RUN;


data templib.CMPGN_BURN_BASE;
set DWHLIB.PB_TRANS_FACT_MASTER(KEEP= 	LOY_CARD_NUMBER PROMO_CODE_ID ORDER_DATE ORDER_P_COMMERCIAL_NAME ORDER_PARTNER_TYPE ACTIVITY_VALUE
										ALLOCATED_POINTS ACTIVITY_ACTION_ID P_COMMERCIAL_NAME ACTIVITY_DATE PARTNER_TYPE
								WHERE= (	(		(activity_date >= "01MAY2012"d and activity_date < '05DEC2012'd) or (order_date >= "01MAY2012"d and order_date < '05DEC2012'd))
											 and
											 ACTIVITY_ACTION_ID in (2,6) )
								);
IF 	(
		ORDER_P_COMMERCIAL_NAME = "FUTUREBAZAAR"
		OR
		ORDER_PARTNER_TYPE ~= "FUTUREGROUP"
	)
	THEN
					IF ORDER_DATE NE . THEN
						DO;
							activity_date = ORDER_DATE;
							P_COMMERCIAL_NAME = ORDER_P_COMMERCIAL_NAME; 
						END;

PARTNER_COMMERCIAL = PUT(P_COMMERCIAL_NAME,$PARTGROUP.);

RUN;

data templib.CMPGN_BURN_BASE(RENAME=(ACTIVITY_DATE1=ACTIVITY_DATE));
	set templib.CMPGN_BURN_BASE;
		ACTIVITY_DATE1 = DATEPART(ACTIVITY_DATE);
		FORMAT ACTIVITY_DATE1 DATE9.;
		DROP ACTIVITY_DATE;
run;

PROC SUMMARY DATA=templib.CMPGN_BURN_BASE NWAY;
	CLASS LOY_CARD_NUMBER PARTNER_COMMERCIAL ACTIVITY_DATE;
	VAR ALLOCATED_POINTS ACTIVITY_VALUE;
	OUTPUT OUT=CMPGN_BURN_BASE_SUMM(DROP=_:) SUM(ALLOCATED_POINTS)=ALLOCATED_POINTS sum(ACTIVITY_VALUE)= ACTIVITY_VALUE
											 N=CNT_BURN_TRANS;
RUN;


PROC SUMMARY DATA=templib.CMPGN_EARN_BASE NWAY;
	CLASS LOY_CARD_NUMBER PARTNER_COMMERCIAL ACTIVITY_DATE;
	VAR ALLOCATED_POINTS ACTIVITY_VALUE;
	OUTPUT OUT=CMPGN_EARN_BASE_SUMM(DROP=_:) SUM(ALLOCATED_POINTS)=ALLOCATED_POINTS sum(ACTIVITY_VALUE)= ACTIVITY_VALUE
											 N=CNT_EARN_TRANS;
RUN;


Data CMPGN_EARN_BURN_BASE;

label 	Earn_allocated_points = "Earn_allocated_points" Earn_activity_value = "Earn_activity_value" CNT_EARN_TRANS="CNT_EARN_TRANS"
		Burn_allocated_points = "Burn_allocated_points" Burn_activity_value = "Burn_activity_value" CNT_BURN_TRANS="CNT_BURN_TRANS";

MERGE 	CMPGN_EARN_BASE_SUMM(in=a keep = LOY_CARD_NUMBER PARTNER_COMMERCIAL ACTIVITY_DATE ALLOCATED_POINTS ACTIVITY_VALUE CNT_EARN_TRANS
							 rename=(ALLOCATED_POINTS=Earn_allocated_points ACTIVITY_VALUE=Earn_activity_value)) 
		CMPGN_BURN_BASE_SUMM(in = b keep = LOY_CARD_NUMBER PARTNER_COMMERCIAL ACTIVITY_DATE ALLOCATED_POINTS ACTIVITY_VALUE CNT_BURN_TRANS
							 rename=(ALLOCATED_POINTS=Burn_allocated_points ACTIVITY_VALUE=Burn_activity_value));

by LOY_CARD_NUMBER PARTNER_COMMERCIAL ACTIVITY_DATE;
run;

/*proc summary data=*/

PROC FORMAT LIB=WORK CNTLOUT=TEMP_PART_NAMES;
	SELECT $PART_ST;
RUN;

OPTIONS MISSING=0;


%macro prt_dsn();
	DATA &PNR_SHT.
		(
			drop=
				Earn_allocated_points 
				burn_allocated_points 
				earn_activity_value 
				burn_activity_value 
				CNT_EARN_TRANS 
				CNT_BURN_TRANS 
				ACTIVITY_DATE 
				DT_3MTHS 
				PARTNER_COMMERCIAL

		);
		Format loy_card_number $40.;
		RETAIN
			NO_TRX_3m_%cmpres(&PNR_SHT.) 		
			NO_TRX_6m_%cmpres(&pnr_sht.) 		
			sales_3m_%cmpres(&pnr_sht.) 		
			sales_6m_%cmpres(&pnr_sht.)
			earn_points_3m_%cmpres(&pnr_sht.) 	
			earn_points_6m_%cmpres(&pnr_sht.) 	
			burn_points_3m_%cmpres(&pnr_sht.) 	
			burn_points_6m_%cmpres(&pnr_sht.)
		;

		SET CMPGN_EARN_BURN_BASE(WHERE=(PARTNER_COMMERCIAL in (%cmpres(&part_comm.))));
		by LOY_CARD_NUMBER PARTNER_COMMERCIAL ACTIVITY_DATE;

		dt_3mths = intnx("month", "&rundate."d, -3, "S");

		if first.LOY_CARD_NUMBER then DO;
			NO_TRX_3m_%cmpres(&PNR_SHT.) = 0;		
			NO_TRX_6m_%cmpres(&pnr_sht.) = 0;		
			sales_3m_%cmpres(&pnr_sht.) = 0;		
			sales_6m_%cmpres(&pnr_sht.) = 0;
			earn_points_3m_%cmpres(&pnr_sht.) = 0; 	
			earn_points_6m_%cmpres(&pnr_sht.) = 0;	
			burn_points_3m_%cmpres(&pnr_sht.) = 0;	
			burn_points_6m_%cmpres(&pnr_sht.) = 0;
		END;

		if activity_date GE dt_3mths then do;
			NO_TRX_3m_%cmpres(&pnr_sht.) = sum(NO_TRX_3m_%cmpres(&pnr_sht.) , CNT_EARN_TRANS); 
		 	sales_3m_%cmpres(&pnr_sht.)  = sum(sales_3m_%cmpres(&pnr_sht.) , Earn_activity_value);
			earn_points_3m_%cmpres(&pnr_sht.) = sum(earn_points_3m_%cmpres(&pnr_sht.) , Earn_allocated_points);
			burn_points_3m_%cmpres(&pnr_sht.) = sum(burn_points_3m_%cmpres(&pnr_sht.) , Burn_allocated_points);
		end;
		else do;
			NO_TRX_6m_%cmpres(&pnr_sht.) = sum(NO_TRX_6m_%cmpres(&pnr_sht.) 	, CNT_EARN_TRANS);
			sales_6m_%cmpres(&pnr_sht.)  = sum(sales_6m_%cmpres(&pnr_sht.) 	, Earn_activity_value);
			earn_points_6m_%cmpres(&pnr_sht.) = sum(earn_points_6m_%cmpres(&pnr_sht.) ,	Earn_allocated_points);
			burn_points_6m_%cmpres(&pnr_sht.) = sum(burn_points_6m_%cmpres(&pnr_sht.) ,	Burn_allocated_points);
		end;

		IF LAST.LOY_CARD_NUMBER;
run;

%mend;

%MACRO PARTNER_COUNT();

proc sql noprint;
	select count(distinct label) into :cnt_comm from TEMP_PART_NAMES;
	SELECT DISTINCT LABEL INTO :LBL1 - :LBL%CMPRES(&CNT_COMM.) FROM TEMP_PART_NAMES;
quit;


%DO I = 1 %TO &CNT_COMM.;

	%global prt_name part_comm;

	proc sql noprint;
	select start into :prt_name separated by "','" from temp_part_names where label="&&LBL&i"; 
	quit;

	%let part_comm = %str(%')%bquote(&prt_name)%str(%'); 
	%let pnr_sht = &&LBL&i.;

	%put ----------- %str(&part_comm.);
	%put ~~~~~~~~~~~ %str(&pnr_sht.);

	%prt_dsn();

%end;

data Templib.Cmpgn_earn_burn_base_partner;

merge

	%do i = 1 %to %eval(&CNT_COMM.);
			&&LBL&i.
	%end;
;

by loy_card_number;
run;

 %MEND;

%PARTNER_COUNT();





/* ---------------- Adding Demogs data to Activity dataset ---------------- */
/* ---------------- Creating NL and SMS potential tables   ---------------- */

/*Earn_burn_partner data is more than 32gb and can't fit into hash object*/



/*data */
/*	whouse.NL_POTENTIAL(DROP=cured_mobile) */
/*	whouse.SMS_POTENTIAL(DROP=CORRECTED_EMAIL_ADDRESS)*/
/*;*/
/**/
/*	if 0 then set TEMPLIB.Cmpgn_earn_burn_base_partner;*/
/**/
/*	IF _N_ = 1 THEN DO;*/
/*		DECLARE HASH demos(DATASET: "TEMPLIB.Cmpgn_earn_burn_base_partner");*/
/*		demos.DEFINEKEY("loy_card_number");*/
/*		demos.definedata(all:'yes');*/
/*		demos.definedone();*/
/*	end;*/
/**/
/*	set whouse.Member_cmpgn_subset;*/
/**/
/*	rc = demos.find();*/
/*	if rc = 0;*/
/**/
/*	IF CORRECTED_EMAIL_ADDRESS ne '' THEN OUTPUT whouse.NL_POTENTIAL;*/
/*	IF cured_mobile ne '' THEN OUTPUT whouse.SMS_POTENTIAL;*/
/**/
/*	drop rc;*/
/*run;*/

proc sql;
create table SMS_POTENTIAL(drop=LOY_CARD_NUMBER) as
select 
		
		A.LOY_CARD_NUMBER as LOY_CARD_NUMBER1,
		A.cured_mobile,
		A.TRUE_ACTIVE_FLAG,
		A.EVER_ACTIVE_FLAG,
		A.MEMBER_ACCOUNT_NUMBER,
		A.SOURCED_ASSOCIATION_ID,
		A.PHYSICAL_CARD_TYPE_ID,
		A.MEMBER_CARD_TYPE_ID,
		A.PROGRAM_ID,
		A.GENDER,
		A.member_zip,
		A.MEMBER_ID,
		A.SIGNUP_DATE,
		A.IS_MEMBER_DISABLED,
		A.IS_DELETED,
		A.PROMO_CODE_ID,
		A.member_city,
		A.agg_flag,
		A.pagg_flag,
		A.member_name,
		A.net_total_points,
		A.total_earn_points,
		A.total_burn_points,
		A.DOB,
		A.age,
		A.precedence,
		A.reachability,
		A.PB_IMINT_FLAG,
		B.*

from whouse.member_cmpgn_subset A left outer join TEMPLIB.Cmpgn_earn_burn_base_partner B on
a.loy_card_number = b.loy_card_number

where cured_mobile ne '';
quit;


proc datasets lib=work;
modify SMS_POTENTIAL ;
rename loy_card_number1 = loy_card_number;
quit;

data WHOUSE.SMS_POTENTIAL;

	if 0 then set WHOUSE.NEW_MEMBER_MASTER(keep=loy_card_number);

	IF _N_ = 1 THEN DO;
		DECLARE HASH WLCM(DATASET: "WHOUSE.NEW_MEMBER_MASTER(keep=loy_card_number)");
		WLCM.DEFINEKEY("loy_card_number");
		WLCM.definedata("loy_card_number");
		WLCM.definedone();
	end;

set SMS_POTENTIAL;

rc = WLCM.find(); 
if rc ne 0;

drop rc;
run;

proc sort data=WHOUSE.SMS_POTENTIAL ;
by cured_mobile precedence descending net_total_points;
run;


proc sql;
create table NL_POTENTIAL(drop=loy_card_number) as
select 
		
		A.loy_card_number as loy_card_number1,
		A.CORRECTED_EMAIL_ADDRESS,
		A.TRUE_ACTIVE_FLAG,
		A.EVER_ACTIVE_FLAG,
		A.MEMBER_ACCOUNT_NUMBER,
		A.SOURCED_ASSOCIATION_ID,
		A.PHYSICAL_CARD_TYPE_ID,
		A.MEMBER_CARD_TYPE_ID,
		A.PROGRAM_ID,
		A.GENDER,
		A.member_zip,
		A.MEMBER_ID,
		A.SIGNUP_DATE,
		A.IS_MEMBER_DISABLED,
		A.IS_DELETED,
		A.PROMO_CODE_ID,
		A.member_city,
		A.agg_flag,
		A.pagg_flag,
		A.member_name,
		A.net_total_points,
		A.total_earn_points,
		A.total_burn_points,
		A.DOB,
		A.age,
		A.precedence,
		A.reachability,
		A.PB_IMINT_FLAG,
		B.*

from whouse.member_cmpgn_subset A left outer join TEMPLIB.Cmpgn_earn_burn_base_partner B on
a.loy_card_number = b.loy_card_number

where CORRECTED_EMAIL_ADDRESS ne '';
quit;

proc datasets lib=work;
modify NL_POTENTIAL ;
rename loy_card_number1 = loy_card_number;
quit;


data WHOUSE.NL_POTENTIAL;

	if 0 then set WHOUSE.NEW_MEMBER_MASTER(keep=loy_card_number);

	IF _N_ = 1 THEN DO;
		DECLARE HASH WLCM(DATASET: "WHOUSE.NEW_MEMBER_MASTER(keep=loy_card_number)");
		WLCM.DEFINEKEY("loy_card_number");
		WLCM.definedata("loy_card_number");
		WLCM.definedone();
	end;

set NL_POTENTIAL;

rc = WLCM.find(); 
if rc ne 0;

drop rc;
run;

proc sort data=WHOUSE.NL_POTENTIAL ;
by CORRECTED_EMAIL_ADDRESS precedence descending net_total_points;
run;


proc datasets lib=work nolist;
delete SMS_POTENTIAL NL_POTENTIAL CMPGN_EARN_BURN_BASE;
quit;

data _null_;
a = put(datetime(),datetime18.);
put "End Time -   " a;
run;

proc printto log=log;
run;
