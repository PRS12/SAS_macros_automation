/************************************************************************
*       Program      : Check the compilation or execution error			*
*		Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Vikas Sinha                                      *
*                                                                       *
*       Input        : N/A									            *
*                                                                       *
*       Output       : Checks the error and sends failure mail if error	*
*                                                                       *
*       Description  : A utility macro for complete automation of code	*
*																		*
*       Usage        : This is helpful in making completely automated   *
*                      process with mail notification for any error.    *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
************************************************************************/

%macro checkNrun;
;run;quit;
%global Error_Code_data Error_Code_sql Error_msg Warn_msg;
%let Error_Code_data  = %str();
%let Error_Code_sql  = %str();
%let Error_msg =%str();
%let Warn_msg = %str();
%if (%eval(&syserr.) gt 4)  or (%eval(&sqlrc.) gt 4) %then %do;
	%let Error_Code_data = SYSERR : %eval(&syserr.);
	%let Error_Code_sql = SQLRC : %eval(&sqlrc.);
	%let Error_msg = SYSMSG : &SYSERRORTEXT.;
	%let Warn_msg = WARNING : &SYSWARNINGTEXT.;
	
	Data _null_;
		if "%upcase(&sysuserid)" = "VIKASSINHA" then call symput ("email","vikas.sinha@payback.net");
		Else if "%upcase(&sysuserid)" = "RPWAR" then call symput ("email","raghavendra.pawar@payback.net");
		Else if "%upcase(&sysuserid)" = "SPINUPOLU" then call symput ("email","sunil.pinupolu@payback.net");
		Else if "%upcase(&sysuserid)" = "SANNAM" then call symput ("email","srinivas.annam_ext@payback.net");
		Else if "%upcase(&sysuserid)" = "RAVEENDRAR" then call symput ("email","raveendra.reddy_ext@payback.net");
		Else if "%upcase(&sysuserid)" = "AMITPATTNAIK" then call symput ("email","amit.pattnaik@payback.net");
		Else if "%upcase(&sysuserid)" = "IMRANANWAR" then call symput ("email","imran.anwar_ext@payback.net");
		Else if "%upcase(&sysuserid)" = "RAJEEVSINHA" then call symput ("email","rajeev.sinha@payback.net");
		Else if "%upcase(&sysuserid)" = "SUMITK" then call symput ("email","sumit.kumar@payback.net");
		Else if "%upcase(&sysuserid)" = "AMR" then call symput ("email","anantharaman.mr@payback.net");
		Else if "%upcase(&sysuserid)" = "PMANGAL" then call symput ("email","Punit.Mangal@payback.net");
		Else if "%upcase(&sysuserid)" = "ATALWAR" then call symput ("email","ankush.talwar@payback.net");
	run;

	options emailsys=smtp  emailhost=smtp3.netcore.co.in emailport=25 ;
	options emailID = "notifications@payback.in";
	options  EMAILAUTHPROTOCOL=LOGIN;
	options emailpw= 'PB@iNd2012';
	filename mailuser email "&email." cc="vikas.sinha@payback.net" 
	subject= "BIU- MACRO FAILURE NOTIFICATION (MACRO NAME: ECOUPON_ANALYSIS) by CheckNRun";
	Data _null_;
		%LET C = 1;
		FILE MAILUSER ;
		PUT #&c. @3 "Hi &sysuserid.,";
		%if %length(&syserr.) > 1 %then %do;
			%LET C = %EVAL(&C + 2);
			put #&c. @8 "&Error_Code_data.";
		%end;
		%if %length(&sqlrc.) > 1 %then %do;
			%LET C = %EVAL(&C + 1);
			put #&c. @8 "&Error_Code_sql.";
		%end;
		%if %length(&SYSERRORTEXT.) > 1 %then %do;
			%LET C = %EVAL(&C + 1);	
			put #&c. @8 "&Error_msg.";
		%end;
		%if %length(&SYSWARNINGTEXT.) > 1 %then %do;
			%LET C = %EVAL(&C + 1);
			put #&c. @8 "&Warn_msg.";
			put #%eval(&c.+1) @8 "%sysfunc(sysmsg())";
		%end;

		%LET C = %EVAL(&C + 1);
		PUT #%EVAL(&C. + 2) @2 "Thanks,";
		PUT #%EVAL(&C. + 3) @2 "Data Innovation & Delivery,";
		PUT #%EVAL(&C. + 4) @2 "Business Intelligence Unit,";
		PUT #%EVAL(&C. + 5) @2 "PAYBACK INDIA";
	RUN;
	proc sql;quit;
	data _null_;run;
	%abort;
%end;
%mend checkNrun;

/*Reset all macro variables to zero*/

data _null_ ;run;
proc sql; quit;

