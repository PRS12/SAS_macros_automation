/************************************************************************
*       Program      : 													*
*                 /sasdata/core_etl/prod/sas/sasautos/check_sas_log.sas *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Imran Anwar                                      *
*                                                                       *
*       Input        : Log directory                                    *
*                      Module name                                      *
*                                                                       *
*                                                                       *
*       Output       : &nobs. macro variable (non-zero signifies ERROR) *
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

%macro check_sas_log(log_location=, module_name=);

%if &module_name=%str() %then %do;
	filename checklog pipe "grep -r '^ERROR:' &log_location.; 2>&1";
%end;
%else %do;
	filename checklog pipe "grep '^ERROR:' &log_location./&module_name..log; 2>&1";
%end;

DATA CHECKLOG;
	FORMAT INSTR $1000.;
	infile checklog;
	INPUT;
	instr=_infile_;
run;

%get_observation_count(dsn=checklog);

%mend check_sas_log;
