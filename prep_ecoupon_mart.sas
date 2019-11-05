/************************************************************************
*       Program      : prep_ecoupon_mart								*
*		Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Amit Pattnaik                                      *
*                                                                       *
*       Input        : 			            *
*                                                                       *
*       Output       : /sasdata/core_etl/prod/sas/programs/prep_ecoupon_mart*
*                                                                       *
*       Description  : It is scheduled job for everyday 7 am         	*
*																		*
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
* 334(Imran Anwar): 05FEB2014 C0001 added ecoupon_first_transactions by amit*
* 334(Imran Anwar): 05MAR2014 C0001 removed since not required by amit *
*                                                                       *
*                                                                       *
************************************************************************/

%macro prep_ecoupon_mart;

proc datasets lib=ecoupon2 nolist nowarn;
	delete ECOUPONE_MART EC_MART PARTNER_LIST;
quit;


proc copy in=dwhlib out=ecoupon2;
	select PARTNER_LIST;
run;
quit;
PROC SQL;
CONNECT TO ORACLE AS ecoupon2 (user=ecoupon2 password="{sas002}30A3A7464DCD9CC727DA4AF75736010D" path='DWHFO');
execute (
	CREATE view EC_MART AS /* C0001 */
	SELECT    DISTINCT
		   	  TO_CHAR (MCC.LOY_CARD_NUMBER) AS LOY_CARD_NUMBER
			, MCC.GROUPING_ID
			, MCC.COUPON_STATUS
			, MCC.VIEWED_DATE
			, MCC.ACTIVATED_DATE
			, MCC.ACTIVATED_CHANNEL
			, MCC.VIEWED_CHANNEL
			, MST.CAMPAIGN_NAME
			, MST.STATUS_ID
			, MCS.STATUS_NAME
			, MST.VALID_FROM
			, MST.VALID_TO
			, MST.VISIBLE_FROM
			, MST.OFFER_TYPE
			, CASE
				 WHEN OFFER_TYPE = 2 THEN 'Online Offer'
				 WHEN OFFER_TYPE = 1 THEN 'Offline Offer'
				 ELSE 'Other Offer'
			  END AS OFFER_DESCRIPTION
			, MST.PARTNER_NAME
			, MST.PARTNER_ID AS LOYALTY_PARTNER_ID
			, MST.UPDATED_AT
			, CPSNG.CALCULATION_METHOD
			, CPSNG.EXTRA_XFACTOR
			, CPSNG.THRESHOLD
			, CPSNG.POINT_CALCULATION_BASE
			, CPSNG.APPLIES_FOR
/*			, CASE*/
/*				WHEN MCC.GROUPING_ID = CCG.GROUPING_ID THEN 1*/
/*				ELSE 0*/
/*				END AS EC_CONTROL_FLAG*/
			, PL.P_COMMERCIAL_NAME 
			, CP.DYNAMIC_CONTROL_GROUP as PERSONALIZATION
			, DCT.TEXT
 FROM 
	  (
	   (
		(
		  (
		    (
		      (
		  		(
				 MAP_CARD_COUPON MCC LEFT JOIN MST_COUPON MST 
	             ON 
				 MCC.GROUPING_ID = MST.GROUPING_ID
				 )
				 LEFT JOIN PARTNER_LIST PL 
	             ON 
				 MST.PARTNER_ID = PL.LOYALTY_PARTNER_ID  
		         )
			     LEFT JOIN COUPON_PERSONALIZATION CP  
	        	 ON 
				 CP.GROUPING_ID =  MCC.GROUPING_ID 
		   	 )
			 LEFT JOIN COUPON_CONTROL_GROUP_MEMBERS CCG
				ON
			CCG.LOY_CARD_NUMBER = MCC.LOY_CARD_NUMBER
		   ) 
			LEFT JOIN
				COUPON_PROCESSING CPSNG
			ON
			MCC.GROUPING_ID = CPSNG.GROUPING_ID
		  ) 
			LEFT JOIN MST_COUPON_STATUS MCS
				ON
				MST.STATUS_ID = MCS.STATUS_ID
		 ) LEFT JOIN (select GROUPING_ID , TEXT 
						from DET_COUPON_TEXT DCT 
						where TEXT_ID = 7) dct
		 		ON
				MCC.GROUPING_ID =  DCT.GROUPING_ID
		 )

		) BY ecoupon2;
	DISCONNECT FROM ecoupon2;
	
QUIT;

Proc sql;
	create table ecoupon.EC_MART as select * from ecoupon2.EC_MART; 
	DROP TABLE ecoupon2.PARTNER_LIST;
	drop table ecoupon2.EC_MART; 
quit;

PROC SQL;
	CONNECT TO ORACLE AS ecoupon2 (user=ecoupon2 password="{sas002}30A3A7464DCD9CC727DA4AF75736010D" path='DWHFO');
	execute (
			create view COUPON_CONTROL_GROUP as /* C0001 */ 
			select to_char(loy_card_number) as loy_card_number , grouping_id, VIEWED_DATE
			from COUPON_CONTROL_GROUP_MEMBERS
		) BY ecoupon2;
	DISCONNECT FROM ecoupon2;
QUIT;

Proc sql;
	create table ecoupon.COUPON_CONTROL_GROUP as select distinct * from ecoupon2.COUPON_CONTROL_GROUP;
	DROP TABLE ecoupon2.COUPON_CONTROL_GROUP;
Quit;

options varlenchk=nowarn;

data ecoupon.EC_MART_control;
	Length 
		PARTNER_NAME		$100
		APPLIES_FOR			$32
		CAMPAIGN_NAME		$100
		EXTRA_XFACTOR		$50
		PERSONALIZATION		$16
		P_COMMERCIAL_NAME	$100
		CALCULATION_METHOD	$100
		POINT_CALCULATION_BASE	$16
		TEXT				$255
		;
	format 
		PARTNER_NAME		$100.
		APPLIES_FOR			$32.
		CAMPAIGN_NAME		$100.
		EXTRA_XFACTOR		$50.
		PERSONALIZATION		$16.
		P_COMMERCIAL_NAME	$100.
		CALCULATION_METHOD	$100.
		POINT_CALCULATION_BASE	$16.
		TEXT				$255.
		;

	if _n_ = 0  then set ecoupon.COUPON_CONTROL_GROUP;
	if _n_ = 1 then do;
		declare hash ec(dataset:"ecoupon.COUPON_CONTROL_GROUP");
		ec.definekey("GROUPING_ID","LOY_CARD_NUMBER");
		ec.definedone();
	end;

	set ecoupon.EC_MART;
	rc = ec.find();
	if rc = 0 then EC_CONTROL_FLAG = 1;
	else EC_CONTROL_FLAG = 0;
	drop rc;
run;

options varlenchk=warn;


/*Remove any Duplicates*/
proc sort data=ecoupon.EC_MART_control out=ECOUPON.unique_Ecuopon_mart nodupkey ;
	by Grouping_id loy_card_number VIEWED_DATE ACTIVATED_DATE COUPON_STATUS ACTIVATED_CHANNEL VIEWED_CHANNEL VALID_TO
	/*	 VALID_FROM VALID_TO;*/
;
RUN;

/*Create the Required Format*/
proc format;
	picture monyyd low-high = '%b`%0y' (datatype=date);
run;

data date_formats;
	do i = -365  to 366;
		date = intnx('day',today(), (I-1),'B');
		IF MONTH(DATE) EQ MONTH(INTNX('WEEK.5',date,0,'B')) THEN WK_START = INTNX('WEEK.5',date,0,'B');
		ELSE WK_START = INTNX('MONTH',date,0,'B');
		IF MONTH(DATE) EQ MONTH(INTNX('WEEK.5',date,0,'E')) THEN WK_END = INTNX('WEEK.5',date,0,'E');
		ELSE WK_END = INTNX('MONTH',date,0,'E');
		week = strip(put(WK_START,date7.))||" - "||strip(put(WK_END,date7.));
		OUTPUT;
	END;
	FORMAT DATE DATE9.;
	drop i 
	;
RUN;

DATA WK_FMT;
	SET date_formats (KEEP=DATE WEEK )END=LAST;
	start = date;
	LABEL = WEEK;

	RETAIN FMTNAME 'WK_FMT' TYPE 'N';
	OUTPUT;

	IF LAST THEN DO;
/*		START = 'OTHER';*/
		HLO = 'O';
		LABEL = 'OTHERS';
		OUTPUT;
	END;
	DROP DATE WEEK;
	format date start date9.;
RUN;

proc format lib=work cntlin=WK_FMT;
run;


/*Apply the above format to dataset*/

DATA ECOUPON.ECOUPONE_MART ;
	SET ECOUPON.unique_Ecuopon_mart;
	if not missing (VIEWED_DATE) then do;
		V_DATE = put(datepart(VIEWED_DATE),WK_FMT.);
	end;
	if not missing (ACTIVATED_DATE) then do;
		A_DATE = put(datepart(ACTIVATED_DATE),WK_FMT.);
	end;

	View_Month = intnx("Month",datepart(VIEWED_DATE),0,"b");
	format View_Month monyy6.;
run;


/*proc datasets lib=ecoupon nolist nowarn;*/
/*	modify ECOUPONE_MART ;*/
/*	index create grouping_id;*/
/*	index create loy_card_number;*/
/*	index create p_commercial_name;*/
/*quit;*/

Data _null_;
a = datetime();
format a datetime20.;
put "First Index Start Time ------ " a ;
run;

proc datasets lib=ecoupon nolist nowarn;
        modify ECOUPONE_MART ;
        index create grouping_id;
quit;

Data _null_;
a = datetime();
format a datetime20.;
put "First Index End Time ------ " a ;
put "---------------------------- ";
put "Second Index Start Time ------ " a ;
run;

proc datasets lib=ecoupon nolist nowarn;
        modify ECOUPONE_MART ;
        index create loy_card_number;
quit;

Data _null_;
a = datetime();
format a datetime20.;
put "Second Index End Time ------ " a ;
put "---------------------------- ";
put "Third Index Start Time ------ " a ;
run;
proc datasets lib=ecoupon nolist nowarn;
        modify ECOUPONE_MART ;
        index create p_commercial_name;
quit;

Data _null_;
a = datetime();
format a datetime20.;
put "Third Index End Time ------ " a ;
run;


/*/*C0001*/*/
/*proc sort data= ecoupon.ECOUPONE_MART out= TEMPLIB.Ecoupon_sorted force;*/
/*by loy_card_number ACTIVATED_DATE;*/
/*run;*/
/**/
/*Data REPORT.Ecoupon_First_Active;*/
/*set TEMPLIB.Ecoupon_sorted(where= (ACTIVATED_DATE ne .));*/
/*by loy_card_number ACTIVATED_DATE;*/
/*if first.LOY_CARD_NUMBER;*/
/*run;*/



/*Delete Temp Tables*/
/*;;*/
/*proc datasets library=templib nolist nowarn;*/
/*	delete*/
/*		ecoupon_sorted*/
/*	;*/
/*quit;*/
;;

proc datasets lib=ecoupon nolist nowarn;
delete 
			ec_mart
			ec_mart_control
			unique_ecuopon_mart
			COUPON_CONTROL_GROUP
			;
run;
quit;
PROC SQL;
	DROP TABLE 	  
				  WORK.DATE_FORMATS
				, WORK.WK_FMT
				;
QUIT;

/*********************end of mart preparation**************************************/

/*include statement which creates ecoupon activation 3 months built for stored process*/

/*%include "/sasdata/core_etl/prod/sas/includes/ecoupon_activation_3months_built.sas" / source2;*/

/*********************end of built preparation**************************************/

%mend prep_ecoupon_mart;
