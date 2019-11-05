
%macro BYPASS_2DAY_EMAIL 	(   
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




/*Select & Rearrange the variable position in the Final data set as per the DRF Request) 
---------------------------------------------------------------------------------------------*/

Data &dsn_emal.(KEEP=&VARB.) ;
Retain &varB.;
set &dsn_emal. End=last;
if last then put "After Rearangement of Var sequence of Var is : &VarB ";
run;



/*Calculate the 10% count of the total number of Obs from the data after applying 7 Days rule
to create the control group dataset Using Proc Surveyselect .
---------------------------------------------------------------------------------------------*/

%LET N_cntl=%sysfunc(int(%sysevalf(&MAIL_COUNT.*0.1)));
%put Before Surveyselect total count of obs &N_cntl;

proc surveyselect data= &dsn_emal. method=srs n= &N_cntl 
out= &dsn_emal._ctrl;
run;

%PUT Outcome from surveyselect : &dsn_emal._ctrl;

/*Create the Test_Group data after excluding the control group from the scrubbed data after 7 days rule .
---------------------------------------------------------------------------------------------*/
proc sql;
create table &dsn_emal._test as
select * from &dsn_emal.
where loy_card_number not in (select loy_card_number from &dsn_emal._ctrl);
quit;

%PUT Outcome from Proc SQL : &dsn_emal._test;


/*Export Data of Control Group in Text File 
--------------------------------------------*/
proc export data = &dsn_emal._ctrl
OUTFILE="&cntl_pth.&cntl_file."
dbms=dlm
replace;
delimiter="|";
run;

/*Export Data of Test Group in Text File 
-------------------------------------------*/
proc export data = &dsn_emal._test
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
                DATA=  &dsn_emal._test FORCE ;
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

%mend BYPASS_2DAY_EMAIL;

