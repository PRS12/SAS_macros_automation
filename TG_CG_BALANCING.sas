%include '/sasdata/core_etl/prod/sas/includes/init_env.sas' /source2;

%MACRO MC_TG_CG_BALANCING
(
TG_LIBNAME=
,TG_DATASET=
,BAL_VAR_LIST=
,BAL_TUNING=
,CG_LIBNAME=
,CG_DATASET=
,PRIMARY_KEY=
);

   OPTIONS NOPRINT NOMLOGIC NOSYMBOLGEN;



%let cnt = %eval(%sysfunc(countc("&BAL_VAR_LIST.",'|'))+1);

     %do q = 1 %to &cnt.;
           %let VAR&q. = %cmpres(%scan(&BAL_VAR_LIST.,&q.,"|"));
           %put VAR&q. := &&VAR&q..;
     %end;

title "DISTRIBUTION OF TARGET GROUP (INSTALLED APP)";
proc means data=&TG_LIBNAME..&TG_DATASET. N mean p1 p25 p50 p75 p99;
var 
%do q = 1 %to &cnt.;
           &&VAR&q..
%end;
;
output out=&TG_DATASET._MEAN MIN= p1= p5= p10= p25= p50= p75= p90= p95= p99= MAX= / autoname;
run;


title "DISTRIBUTION OF POPULATION (NOT INSTALLED APP)";
proc means data=&CG_LIBNAME..&CG_DATASET. N mean p1 p25 p50 p75 p99;
var 
%do q = 1 %to &cnt.;
           &&VAR&q..
%end;
;
output out=&CG_DATASET._MEAN MIN= p1= p5= p10= p25= p50= p75=p90= p95=p99= MAX= / autoname;
run;

%do q = 1 %to &cnt.;
     
proc sql noprint;

select &&VAR&q.._P25 into :&&VAR&q.._P25 
from &TG_DATASET._MEAN ;

select &&VAR&q.._P50 into :&&VAR&q.._P50 
from &TG_DATASET._MEAN ;


select &&VAR&q.._P75 into :&&VAR&q.._P75 
from &TG_DATASET._MEAN ;


quit; 

%end;


data &TG_DATASET._STRING;
set &TG_LIBNAME..&TG_DATASET.;
%do q = 1 %to &cnt.;
format     &&VAR&q.._FLAG string $10.;
%end;


     %do q = 1 %to &cnt.;

           if &&VAR&q..< &&&&&&VAR&q.._P25. then &&VAR&q.._FLAG="1";
           else if &&VAR&q..< &&&&&&VAR&q.._P50. then &&VAR&q.._FLAG="2";
           else if &&VAR&q..< &&&&&&VAR&q.._P75. then &&VAR&q.._FLAG="3";
           else &&VAR&q.._FLAG="4";

     %end;

string=catx("_" %do q = 1 %to &cnt.;
     
     , &&VAR&q.._flag

%end;
);

run;

data &CG_DATASET._STRING;
set &CG_LIBNAME..&CG_DATASET.;
%do q = 1 %to &cnt.;
format     &&VAR&q.._FLAG string $10.;
%end;

     %do q = 1 %to &cnt.;

           if &&VAR&q..< &&&&&&VAR&q.._P25 then &&VAR&q.._FLAG="1";
           else if &&VAR&q..< &&&&&&VAR&q.._P50 then &&VAR&q.._FLAG="2";
           else if &&VAR&q..< &&&&&&VAR&q.._P75 then &&VAR&q.._FLAG="3";
           else &&VAR&q.._FLAG="4";

     %end;

string=catx("_" %do q = 1 %to &cnt.;
     
     , &&VAR&q.._flag

%end;
);

run;


title "TYPE OF CUSTOMERS IN TARGET GROUP (INSTALLED APP)";
proc freq data=&TG_DATASET._STRING order=freq;
table string/out=&TG_DATASET._STRING_FREQ outcum;
run;

title "TYPE OF CUSTOMERS IN POPULATION (NOT INSTALLED APP)";
proc freq data=&CG_DATASET._STRING order=freq;
table string/out=&CG_DATASET._STR_FREQ;
run;

proc sql;
create table &CG_DATASET._STRING1 as
select l.*, r1.percent as act_percent, r1.count as count, r.percent as reqd_percent,
r.percent/(r1.percent*&BAL_TUNING.) as sampling_rate, ranuni(1234) as random,
r.cum_pct
from &CG_DATASET._STRING as l 
left join &TG_DATASET._STRING_FREQ as r
on l.string=r.string and r.cum_pct<99
left join &CG_DATASET._STR_FREQ as r1
on l.string=r1.string
order by &PRIMARY_KEY.;
quit;

data &CG_LIBNAME..&CG_DATASET._BALANCE;*This is the control group;
set &CG_DATASET._STRING1;
if random le sampling_rate and sampling_rate ne . then output;
run;

title "DISTRIBUTION OF TARGET GROUP (INSTALLED APP)";
proc means data=&TG_DATASET._STRING N mean p1 p25 p50 p75 p99;
var 
%do q = 1 %to &cnt.;
           &&VAR&q..
%end;
;
run;

title "DISTRIBUTION OF POPULATION (NOT INSTALLED APP)";
proc means data=&CG_DATASET._STRING N mean p1 p25 p50 p75 p99;
var
%do q = 1 %to &cnt.;
           &&VAR&q..
%end; 
;
run;

title "DISTRIBUTION OF CONTROL GROUP SAMPLED FROM POPULATION (NOT INSTALLED APP)";
proc means data=&CG_LIBNAME..&CG_DATASET._BALANCE N mean p1 p25 p50 p75 p99;
var 
%do q = 1 %to &cnt.;
           &&VAR&q..
%end; 
;
run;

%mend;
