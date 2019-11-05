/***********************************************************************\
*       Program      : DRF_SMS							            *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Imran KHan                          *
*                                                                       *
*       Input        :                               *
*                                                                       *
*       Output       :                *
*                                                                       *
*       Dependencies : NONE                                             *
*                                                                       *
*       Description  : This macro can be used to create and export the  *
*                      the dataset as per the DRF without applying      *
*					   2 day rule .										*
* 		Path		 :  G:\SAS\COMMON\SASAUTOS\BYPASS_2DAY_SMS.sas		*  
*																		*
*                                                                       *
*       Usage        : 							*
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*       LSRL-273	13-Jul-2012	Created.                       	*
*       								*
*       Imran       : 28-August-2012    /*c0001*/			*	
* Limiting to 2 communications per week from wed to tue per channel     *
\***********************************************************************/





/*Followign query is to get the list of required variable with standard exclusions 

*/

/*working on NL DATA FIRST*/
options mcompilenote=all;
%macro BYPASS_2DAY_SMS		(   
                       DSN_SMS   =                                                         ,
                       by_emal    = CORRECTED_EMAIL_ADDRESS                       			,
                       by_mob     = CURED_MOBILE                                       		,
                       by_othr    = precedence descending net_total_points     				,
                       by_card    = loy_card_number                                    		,
                       cntl_pth   =                                                         ,
                       cntl_file  =                                                         ,
                       tst_path   =                                                         ,
                       tst_file   =                                                         ,
                       CMPGN_NM   =                                                         ,
                       DEP_DATE   =          /*in format of 18jul2012 */					,
                       VarB = 
                     );

     proc sort data=&DSN_SMS;
     by &by_mob &by_othr;
     run;

     proc sort data=&DSN_SMS. nodupkey;
     by &by_mob;
     run;

     proc sort data=&DSN_SMS. nodupkey ;
     by &by_card;
     run;

%include "G:\sas\common\sasautos\get_observation_count.sas" ;
%GET_OBSERVATION_COUNT(dsn=&DSN_SMS.);
%let MAIL_COUNT = &nobs.;
%put total obs before 7 days rule &MAIL_COUNT;



/*Select & Rearrange the variable position in the Final data set as per the DRF Request) 
---------------------------------------------------------------------------------------------*/

Data &DSN_SMS.(KEEP=&VarB.) ;
Retain &VarB.;
set &DSN_SMS. End=last;
if last then put "After Rearangement of Var sequence of Var is : &VarB ";
run;



/*Calculate the 10% count of the total number of Obs from the data after applying 7 Days rule
to create the control group dataset Using Proc Surveyselect .
---------------------------------------------------------------------------------------------*/

%LET N_cntl=%sysfunc(int(%sysevalf(&MAIL_COUNT.*0.1)));
%put Before Surveyselect total count of obs &N_cntl;

proc surveyselect data= &DSN_SMS. method=srs n= &N_cntl 
out= &DSN_SMS._ctrl;
run;

%PUT Outcome from surveyselect : &DSN_SMS._ctrl;

/*Create the Test_Group data after excluding the control group from the scrubbed data after 7 days rule .
---------------------------------------------------------------------------------------------*/
proc sql;
create table &DSN_SMS._test as
select * from &DSN_SMS.
where loy_card_number not in (select loy_card_number from &DSN_SMS._ctrl);
quit;

%PUT Outcome from Proc SQL : &DSN_SMS._test;


/*Uploade the data to Auditlib library 
---------------------------------------*/
/**/
/*data auditlib.%SCAN(&DSN_SMS.,2,".")_FINAL_test;*/
/*set &DSN_SMS._FINAL_test;*/
/*run;*/


/*Export Data of Control Group in Text File 
--------------------------------------------*/
proc export data = &DSN_SMS._ctrl
OUTFILE="&cntl_pth.&cntl_file."
dbms=dlm
replace;
delimiter="|";
run;

/*Export Data of Test Group in Text File 
-------------------------------------------*/
proc export data = &DSN_SMS._test
OUTFILE="&tst_path.&tst_file."
dbms=dlm
replace;
delimiter="|";
run;

/* Following code would append the above data to SUPPLIB.DRF_EML to calculate this data for next seven days for next DRF 
-------------------------------------------------------------------------------------------------------------------------*/

PROC SQL;
CREATE TABLE WORK.DRF_SMS(CAMPAIGN_NAME CHAR(200),CURED_MOBILE CHAR(100),
DEP_DATE NUM(10), MAILING_LIST CHAR(8));
QUIT;

PROC APPEND   BASE=  WORK.DRF_SMS
                DATA=  &DSN_SMS._test FORCE ;
RUN;

DATA WORK.DRF_SMS ;
   SET WORK.DRF_SMS;
   CAMPAIGN_NAME="&CMPGN_NM.";
   DEP_DATE="&DEP_DATE"D;
   MAILING_LIST ='T';
RUN;

PROC APPEND   BASE= SUPPLIB.DRF_SMS 
                DATA=  WORK.DRF_SMS    FORCE ;
RUN;


PROC DATASETS LIB=WORK NOLIST;
DELETE DRF_SMS;
QUIT;

%mend BYPASS_2DAY_SMS;

     
