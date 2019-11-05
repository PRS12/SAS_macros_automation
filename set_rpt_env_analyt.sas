/************************************************************************
* Program      : set_rpt_env_analyt							            *
*                                                                       *
* Owner        : Analytics, LSRPL                                 		*
*                                                                       *
* Author       : Bhagat Singh                          					*
*                                                                       *
* Input        :  NONE                         							*
*                                                                       *
* Output       : PERFECT SAS ENVIRONMENT								*
*                                                                       *
* Dependencies : NONE                                             		*
*                                                                       *
* Description  : This macro can be used to SET THE BASIC SAS ENV  		*
*                      at eachh invocation of SAS Session  				*
*																		*
* Path		   :/sasdata/core_etl/prod/sas/sasautos/set_rpt_env_analyt.sas   *  
*																		*
*                                                                       *
* Usage        : 														*
*                                                                       *
* History      :                                                  		*                     
*LSRPL-540 Chnage the Format location to access formats for SASAnalytics *
*			   Server													*
************************************************************************/                            

options MAUTOSOURCE SASAUTOS=(
					"/sasdata/core_etl/prod/FG/sasautos/reporting steps"
					"/sasdata/core_etl/prod/FG/sasautos"
					"/sasdata/core_etl/prod/sas/sasautos"
                                         /*C0001 */
				);


%macro set_rpt_env_analyt;

options compress=Char Reuse=yes; /* C0004 */
options mprint mlogic symbolgen fmtsearch=(formats);

/* Date related macro variables to be available throughout the session */
data _null_;
	call symput("rundate", put(today(), date9.));
run;

%put &rundate.;

/* Earliest date to pick up data from */
%LET epoch=01JUL2010;

/* Last months last working day */
%LET START_DATE_LAST_MON = INTNX("MONTH", "&SYSDATE"D, -1, "B");
%LET END_DATE_LAST_MON = INTNX("MONTH", "&SYSDATE"D, -1, "E");
%LET START_DATE_CURR_MON = INTNX("MONTH", "&SYSDATE"D, -0, "B");
%LET END_DATE_CURR_MON = INTNX("MONTH", "&SYSDATE"D, -0, "E");

/* SAS Native libraries */
/*libname CUBELIB "/sasdata/core_etl/prod/libraries/CUBELIB";*/
libname AUDITLIB "/sasdata/core_etl/prod/libraries/AUDITLIB/";
libname SASMART "/sasdata/core_etl/prod/libraries/SASMART";
libname SUPPLIB "/sasdata/core_etl/prod/libraries/SUPPLIB";
libname WHOUSE "/sasdata/core_etl/prod/libraries/WHOUSE";
libname TEMPLIB "/sasdata/core_etl/prod/libraries/TEMPLIB";
libname OPSLIB "/sasdata/core_etl/prod/libraries/OPSLIB";
libname ECOUPON "/sasdata/core_etl/prod/libraries/ECOUPON";
libname REPORT "/sasdata/bi/REPORT";
/* C0008 */
libname SUMMLIB "/sasdata/core_etl/prod/libraries/SUMMLIB";
libname CIMLIB "/sasdata/ci/CIMPLIB";
libname CAMPLIB "/sasdata/campaign/CAMPLIB";
libname DIDLIB "/sasdata1/did/DIDLIB";
libname DID_STG "/sasdata1/did/DID_STG";

libname BI_STG "/sasdata1/bi/BI_STG";
libname BI_AUDIT "/sasdata1/bi/BI_AUDIT";

/* C0011 */
LIBNAME AMX_STG "/sasdata1/amex/AMX_STG";
LIBNAME WIPMART "/sasdata/core_etl/prod/libraries/WIPMART";



/* 
	20130917: Currently, core_etl admin (etl_adm user does not have write access to the following folder.
	Moving formats creation to a localized folder within core_etl area. 

*/


/* C0009 */
/*(C0012)*/
/*LIBNAME FORMATS "/sasdata/core_etl/prod/libraries/FORMATS_TMP"; */
/*LIBNAME FORMATS "/sasconf/serverconfig/Lev1/SASApp/SASEnvironment/SASFormats/";*/
LIBNAME FORMATS "/sasconf/serverconfig/Lev1/SASAnalytics/SASEnvironment/SASFormats/";


/* ORACLE libraries */
%include "/sasdata/core_etl/prod/sas/includes/set_conn_biu_dwh_rw.sas" / source2;



/*C0010*/
/* Construction of standardized PB formats. Runs only if core_etl administrator invokes the SAS-session and file existence of formats_signal_DDMONYYYY.txt file*/

	%IF %cmpres(%upcase(&sysuserid.))=%cmpres(ETL_ADM) %then
		%do; /* ----- Checks the existence of file -- FORMATS_SIGNAL_DDMONYYYY.txt -----*/
			%if %sysfunc(fileexist(/sasdata/core_etl/prod/conf/signals_analyt/formats_signal_&sysdate9..txt)) = 0 %then 
				%do;
					/* ----- If file doesn't exist, create the file and run the formats creation ----- */
				Data _null_;
				file "/sasdata/core_etl/prod/conf/signals_analyt/formats_signal_&sysdate9..txt";
				put "------------------";
				run;
				
				%create_pb_std_formats_analyt;

				%end;
			%else
				%do;
					/* ----- If file exist, check the file creation time is 2 minutes before ----- */
					/* ----- If file creation time is less than 2 minutes, system will wait for 2 minutes ------ */
					filename stat pipe "ls -ltr /sasdata/core_etl/prod/conf/signals_analyt/formats_signal_&sysdate9..txt"	;			

					data time;
					infile stat truncover;
					input var $200.;
					Cr_time1 = scan(var,8,'');
					cr_time  = ( scan(cr_time1,1,':')*60 ) + (scan(cr_time1,2,':')*1); 
					curtime1 = put(timepart(datetime()),HHMM5.);
					a = scan(curtime1,1,':')*60;
					b = scan(curtime1,2,':')*1;
					curtime  = a + b; 
					call symputx('Mac_crt_time',cr_time);
					call symputx('Mac_cur_time',curtime);
					run;

					%put Creatime Time ----> &Mac_crt_time. -- Current Time ------>  &Mac_cur_time.;

					%if %eval(&Mac_crt_time. + 2) > &Mac_cur_time. %then
						%do;
							Data _null_;
							a =sleep(120,1);
							run;
						%end;

				%end;
			%end;
		%else
				%do;
					/* ----- If login user is not ETL_ADM and checking status file existence ----- */
					/* ----- If file exist, check the file creation time is 2 minutes before ----- */
					/* ----- If file creation time is less than 2 minutes, system will wait for 2 minutes ------ */

					filename stat pipe "ls -ltr /sasdata/core_etl/prod/conf/signals_analyt/formats_signal_&sysdate9..txt"	;			

					data time;
					infile stat truncover;
					input var $200.;
					Cr_time1 = scan(var,8,'');
					cr_time  = ( scan(cr_time1,1,':')*60 ) + (scan(cr_time1,2,':')*1); 
					curtime1 = put(timepart(datetime()),HHMM5.);
					a = scan(curtime1,1,':')*60;
					b = scan(curtime1,2,':')*1;
					curtime  = a + b; 
					call symputx('Mac_crt_time',cr_time);
					call symputx('Mac_cur_time',curtime);
					run;

					%put Creatime Time ----> &Mac_crt_time. -- Current Time ------>  &Mac_cur_time.;

					%if %eval(&Mac_crt_time. + 2) > &Mac_cur_time. %then
						%do;
							Data _null_;
							a =sleep(120,1);
							run;
						%end;

				%end;

%mend set_rpt_env_analyt;


