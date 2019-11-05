/***********************************************************************\
*       Program      : DRF_email										*
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Vikas Sinha                          			*
*                                                                       *
*       Input        :                               					*
*                                                                       *
*       Output       :              									*
*                                                                       *
*       Dependencies : NONE                                             *
*                                                                       *
*       Description  : This macro can be used to create and export the  *
*                      the dataset as per the DRF requst once the data  *
*                      data set has been created.                       *
*                                                                       *
*      Path	     :  G:\SAS\COMMON\SASAUTOS\DRF_Email_Macro_V1.sas   	*
*                                                                       *
*       Usage        :													*
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*       LSRL-273	13-Jul-2012	Created.                       *
*       								*
*        Imran       : 28-August-2012    /*c0001*/ 		      *
*  Limiting to 2 communications per week from wed to tue per channel    *
\***********************************************************************/


options mcompilenote=all;
%macro DRF_email 	(   
                       dsn_emal   =                                                         ,
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
                       VarB 		  = 
                     );

     proc sort data=&dsn_emal;
     by &by_emal &by_othr;
     run;

     proc sort data=&dsn_emal. nodupkey;
     by &by_emal;
     run;

     proc sort data=&dsn_emal. nodupkey ;
     by &by_card;
     run;

%include "G:\sas\common\sasautos\get_observation_count.sas" ;
%GET_OBSERVATION_COUNT(dsn=&dsn_emal.);
%let MAIL_COUNT = &nobs.;
%put total obs before 7 days rule &MAIL_COUNT;


/*Apply seven day rule on above dataset by following code - Week boundary (Wednesday to Tuesday) 
-------------------------------------------------------------------------------------------------*/

     DATA _NULL_ ;
     start_dt = intnx("week.4", "&DEP_DATE"d, 0, "B");
     CALL SYMPUT("start_dt", put(start_dt, date9.));
     RUN;
     %PUT &start_dt;


%include "G:\sas\common\sasautos\gen_excl_lst_by_dep_dt.sas" ;
   								/*c0001*/ 
%gen_excl_lst_by_dep_dt(dep_dt=&start_dt, channel=EML,limit=2,test_data=&dsn_emal); 

%get_observation_count(dsn=&dsn_emal._FINAL);
%let MAIL_COUNT_FINAL = &nobs.;
%PUT total obs after 7 days rule  &MAIL_COUNT_FINAL.;


/*Select & Rearrange the variable position in the Final data set as per the DRF Request) 
---------------------------------------------------------------------------------------------*/

Data &dsn_emal._FINAL(KEEP=&VARB.) ;
Retain &varB.;
set &dsn_emal._FINAL End=last;
if last then put "After Rearangement of Var sequence of Var is : &VarB ";
run;



/*Calculate the 10% count of the total number of Obs from the data after applying 7 Days rule
to create the control group dataset Using Proc Surveyselect .
---------------------------------------------------------------------------------------------*/

%LET N_cntl=%sysfunc(int(%sysevalf(&MAIL_COUNT_FINAL.*0.1)));
%put Before Surveyselect total count of obs &N_cntl;

proc surveyselect data= &dsn_emal._FINAL method=srs n= &N_cntl 
out= &dsn_emal._FINAL_ctrl;
run;

%PUT Outcome from surveyselect : &dsn_emal._FINAL_ctrl;

/*Create the Test_Group data after excluding the control group from the scrubbed data after 7 days rule .
---------------------------------------------------------------------------------------------*/
proc sql;
create table &dsn_emal._FINAL_test as
select * from &dsn_emal._FINAL
where loy_card_number not in (select loy_card_number from &dsn_emal._FINAL_ctrl);
quit;

%PUT Outcome from Proc SQL : &dsn_emal._FINAL_test;


/*Export Data of Control Group in Text File 
--------------------------------------------*/
proc export data = &dsn_emal._FINAL_ctrl
OUTFILE="&cntl_pth.&cntl_file."
dbms=dlm
replace;
delimiter="|";
run;

/*Export Data of Test Group in Text File 
-------------------------------------------*/
proc export data = &dsn_emal._FINAL_test
OUTFILE="&tst_path.&tst_file."
dbms=dlm
replace;
delimiter="|";
run;

/* Following code would append the above data to SUPPLIB.DRF_EML to calculate this data for next seven days for next DRF 
-------------------------------------------------------------------------------------------------------------------------*/

PROC SQL;
CREATE TABLE WORK.DRF_EML(CAMPAIGN_NAME CHAR(200),CORRECTED_EMAIL_ADDRESS CHAR(100),
DEP_DATE NUM(10), MAILING_LIST CHAR(8));
QUIT;

PROC APPEND   BASE=  WORK.DRF_EML
                DATA=  &dsn_emal._FINAL_test FORCE ;
RUN;

DATA WORK.DRF_EML ;
   SET WORK.DRF_EML;
   CAMPAIGN_NAME="&CMPGN_NM.";
   DEP_DATE="&DEP_DATE"D;
   MAILING_LIST ='T';
RUN;

PROC APPEND   BASE= SUPPLIB.DRF_EML 
                DATA=  WORK.DRF_EML    FORCE ;
RUN;


PROC DATASETS LIB=WORK NOLIST;
DELETE DRF_EML;
QUIT;

%mend DRF_email;


