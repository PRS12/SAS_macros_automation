%macro chk_table_lock (dsn=);

data _null_;
	call symput("START_TIME", put(datetime(), datetime20.));
run;

%put NOTE: Current time: &START_TIME;

LOCK &DSN. QUERY;

%if &SYSLCKRC ~= -630099 %then %do;
	%put WARNING: Table &dsn. is locked already.;
%end;
%else %do;
	%put NOTE: Table &dsn. is available for locking.;
%end;

data _null_;
	call symput("END_TIME", put(datetime(), datetime20.));
run;

%put NOTE: Current time: &END_TIME;

%mend chk_table_lock;
