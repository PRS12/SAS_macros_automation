%macro compute_month_range(
	start=
	,end=
);

	%GLOBAL NMONTHS;
	data _null_;
		nmonths=intck("MONTH", "&START."D, "&end."d);
		call symput("NMONTHS", NMONTHS);
	run;

%mend compute_month_range;

