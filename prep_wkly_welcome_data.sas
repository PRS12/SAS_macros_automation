/************************************************************************
*       Program      :   											    *
*            $HOME/sas/common/programs/prep_wkly_welcome_data.sas       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       :                                                  *
*                                                                       *
*       Input        :                                                  *
*                                                                       *
*                                                                       *
*                                                                       *
*       Output       :                                                  *
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

data _null_;
	call symput("CUTOFF_PREV", PUT(intnx("WEEK", "&RUNDATE."D, -1, "B"), date9.)); 
run;

*;
DATA camplib.welcome_nl_sms_drf;

IF _N_= 0 THEN set whouse.new_member_master;
                           
IF _N_ = 1 THEN  DO;
     DECLARE HASH DA(DATASET: 'whouse.new_member_master(WHERE=(
		datepart(add_date) > "&cutoff_prev."d
		or
		datepart(demographics_updated_date) > "&cutoff_prev."d
		or
		datepart(first_demog_update_date) > "&cutoff_prev."d
		))');
     DA.DEFINEKEY("LOY_CARD_NUMBER");
     DA.defineData(ALL:"YES");
     DA.DEFINEDONE();
    END;
           
set whouse.member_cmpgn_subset  
     (
		keep=
			loy_card_number 
			member_name 
			promo_code_id 
			sourced_association_id 
			CORRECTED_EMAIL_ADDRESS
	        CURED_MOBILE 
			member_card_type_id 
			member_city
	);
    where member_card_type_id  not in (166,167)
                                  and promo_code_id in (194,179,182,183,185,193,184,188,180,190,191,192,124,152,168,174,176,175)
                                  or
                                  sourced_association_id in (1,2,13,21,77,80);

     rc0 = da.find();

     if rc0 = 0;

     drop rc0 ;
run;

*79426;
proc sql; create table CAMPLIB.welcome_drf1  as 
select * from camplib.welcome_nl_sms_drf
where loy_card_number not in select loy_card_number from supplib.drf_welcome;
quit; 
 *79426;
data CAMPLIB.WELCOME_DRF2;
set CAMPLIB.welcome_drf1;
length PARTNER $25;
if promo_code_id not in (194,179,182, 183,185,193,184,180,190,191,192,188)then PARTNER="OTHERS";
else PARTNER=put(promo_code_id,pid2part.) ;
run;


data CAMPLIB.nl_welcome(drop=cured_mobile )
          CAMPLIB.sms_welcome (drop= corrected_email_address );
retain loy_card_number member_name corrected_email_address cured_mobile promo_code_id ;

set CAMPLIB.WELCOME_DRF2 
(drop=member_id add_date demographics_updated_date email member_card_type_id full_name);
dep_date="&RUNDATE"d;
FORMAT PROMO_CODE_ID PID2PART.;
FORMAT SOURCED_ASSOCIATION_ID SID2PART.;
          if cured_mobile = "" and corrected_email_Address = "" then delete;
          if corrected_email_address ~= ""  then output CAMPLIB.nl_welcome ;
          if cured_mobile ~= "" then output CAMPLIB.sms_welcome;
run;
*;
%PUT &RUNDATE;

proc sort data=CAMPLIB.nl_welcome tagsort nodupkey;
by corrected_email_address;
run;
* ;
proc sort data=CAMPLIB.nl_welcome tagsort nodupkey;
by loy_card_number;
run;

proc sort data=CAMPLIB.sms_welcome tagsort nodupkey;
by cured_mobile;
run;
* ;
proc sort data=CAMPLIB.sms_welcome tagsort nodupkey;
by loy_card_number;
run;

PROC APPEND BASE= SUPPLIB.DRF_WELCOME
              DATA= CAMPLIB.nl_welcome FORCE;
RUN;

PROC APPEND BASE= SUPPLIB.DRF_WELCOME
              DATA= CAMPLIB.sms_welcome FORCE;
RUN;


PROC APPEND BASE= SUPPLIB.exclude_welcome_nl_sms
              DATA= CAMPLIB.nl_welcome FORCE;
RUN;

PROC APPEND BASE= SUPPLIB.exclude_welcome_nl_sms
              DATA= CAMPLIB.sms_welcome FORCE;
RUN;

* ;
DATA camplib.nl_welcome;
SET camplib.nl_welcome;
MEMBER_CITY=STRIP(UPCASE(MEMBER_CITY));
IF MEMBER_CITY IN ('BANGALORE','BENGALURU','BENGALOORU','BANGLORE') THEN MEMBER_CITY='BANGALORE';
ELSE IF MEMBER_CITY IN ('HYDERABAD','HYD','HYDERBAD','SECUNDERABAD') THEN MEMBER_CITY='HYDERABAD';
ELSE IF MEMBER_CITY IN ('CHENNAI') THEN MEMBER_CITY='CHENNAI';
ELSE IF MEMBER_CITY IN ('MUMBAI','NAVIMUMBAI','NEWMUMBAI') THEN MEMBER_CITY='MUMBAI';
ELSE IF MEMBER_CITY IN ('KOLKATA','CALCUTTA','KOLKATTA') THEN MEMBER_CITY='KOLKATA';
ELSE IF MEMBER_CITY IN ('NEWDELHI','DELHI','FARIDABAD','GHAZIABAD','NOIDA','GREATER NOIDA','GURGAON') THEN MEMBER_CITY='DELHI-NCR';
ELSE MEMBER_CITY='OTHER CITIES';
RUN;

PROC FREQ DATA=camplib.nl_welcome;
TABLES MEMBER_CITY / NOROW NOCOL NOPERCENT;
RUN;

* ;
DATA camplib.sms_welcome;
SET camplib.sms_welcome;
MEMBER_CITY=STRIP(UPCASE(MEMBER_CITY));
IF MEMBER_CITY IN ('BANGALORE','BENGALURU','BENGALOORU','BANGLORE') THEN MEMBER_CITY='BANGALORE';
ELSE IF MEMBER_CITY IN ('HYDERABAD','HYD','HYDERBAD','SECUNDERABAD') THEN MEMBER_CITY='HYDERABAD';
ELSE IF MEMBER_CITY IN ('CHENNAI') THEN MEMBER_CITY='CHENNAI';
ELSE IF MEMBER_CITY IN ('MUMBAI','NAVIMUMBAI','NEWMUMBAI') THEN MEMBER_CITY='MUMBAI';
ELSE IF MEMBER_CITY IN ('KOLKATA','CALCUTTA','KOLKATTA') THEN MEMBER_CITY='KOLKATA';
ELSE IF MEMBER_CITY IN ('NEWDELHI','DELHI','FARIDABAD','GHAZIABAD','NOIDA','GREATER NOIDA','GURGAON') THEN MEMBER_CITY='DELHI-NCR';
ELSE MEMBER_CITY='OTHER CITIES';
RUN;

PROC FREQ DATA=camplib.nl_welcome;
TABLES MEMBER_CITY / NOROW NOCOL NOPERCENT;
RUN;
PROC FREQ DATA=camplib.sms_welcome;
TABLES MEMBER_CITY / NOROW NOCOL NOPERCENT;
RUN;
* ;
proc export data =  camplib.nl_welcome
OUTFILE="G:\sas\common\output\Welcome_NL_OCT_2012_465d_&RUNDATE..txt"
dbms=dlm
replace;
delimiter="|";
run;

* ;
proc export data =  camplib.sms_welcome
OUTFILE="G:\sas\common\output\Welcome_SMS_OCT2012_465d_&RUNDATE..txt"
dbms=dlm
replace;
delimiter="|";
run;

