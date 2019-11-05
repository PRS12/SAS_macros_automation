/* Creation of a picture format converting datetime column into date or any of the higher periods */

PROC FORMAT;
	/* Datetime to Year-month */
	PICTURE dt2yrmon (default=10) other='%b%Y';
quit;

ods listing close;
ods results off;
ODS HTML FILE='G:\REPORTING\PB_HIGH_LEVEL\Oracle_view_demo_pb_X_format_rpt.xls' style=minimal;

/* A simple YTD Cross format report */
PROC TABULATE DATA = dwhlib.pb_trans_fact_mart;
	WHERE
		ACTIVITY_ACTION_ID IN (1,5)
		and
		ACTIVITY_DATE >= '01JAN2012'
	;

	CLASS
		ACTIVITY_DATE
		P_COMMERCIAL_NAME
		PROMO_CODE_ID
	;
	format activity_date dt2yrmon.;
	format promo_code_id pid2desc.;
	
	VAR
		ACTIVITY_VALUE
		ALLOCATED_POINTS
	;

	ACTIVITY_DATE=""*PROMO_CODE_ID="" ALL="Grand Total"
		, (P_COMMERCIAL_NAME="" ALL='Total')*
				(
					N="Total Activity Count"
					activity_value=""*SUM='Total Sales Value'
					ALLOCATED_POINTS=""*SUM='Total points issued'
				)
	/ box={label='Enrolment Source'};
run;
QUIT;

ods html close;
ods results on;
ods listing;
