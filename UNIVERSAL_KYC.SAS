/************************************************************************************
*       Program      : Universal_KYC.SAS											*
*		Owner        : Analytics, LSRPL                                 			*
*                                                                       			*
*       Author       : LSRL/324                                            			*
*                                                                       			*
*                                                                      				*
*       Description  : Extracts the KYC &Other data for Universal enrolled customers*
*																					*
*       Usage        :          													*
*                         															*
*                                                                       			*
*       History      :                                                  			*
*       (Analyst)     	(Date)    	(Changes)                               		*
*                                                                       			*
*        LSRL/324					Created                                         
************************************************************************************/


/* ------ Promo_code_id = 175 for Universal filter ------ */

%macro Univercell();

proc sql;
connect to oracle as dwh ( user = dwh password = manager path = 'dwhfo');
create table Univercell_kyc as
select * from connection to dwh
(
select
	 to_char(a.Loy_card_number) as loy_card_number 
	,a.EMAIL 
	,a.MOBILE_PHONE 
	,a.DATE_OF_BIRTH 
	,a.ADDRESS_LINE1 
	,a.ADDRESS_LINE2 
	,a.ADDRESS_LINE3 
	,a.ADDRESS_LINE4 
	,a.CITY 
	,a.STATE_PROVINCE 
	,a.ZIP 
	,a.MARITAL_STATUS 
	,a.ANNIVERSARY_DATE 
	,a.OCCUPATION_FUNCTION 
	,a.EMPLOYMENT_STATUS 
	,a.GENDER
	,a.PHYSICAL_CARD_TYPE_ID
	,a.FULL_NAME
	,a.member_Account_number
	,a.member_id

from dim_member a join DET_MEMBER_CARD_ACC_MAP b 
	 on a.loy_card_number = b.loy_card_number

where b.promo_code_id = 175 and a.PHYSICAL_CARD_TYPE_ID = 1
);
disconnect from dwh;
quit;

%let status1 = &sqlrc.;
%let msg1 = &syserrortext.;

%if &status1. ne %eval(0) %then 
	%do;
		%GOTO Error_stat;
	%end;

data templib.Univercell_kyc;
if 0 then set Univercell_kyc;
	IF _N_ = 1 THEN DO;
		DECLARE HASH demos(DATASET: "Univercell_kyc");
		demos.DEFINEKEY("loy_card_number");
		demos.definedata(all:'yes');
		demos.definedone();
	end;

set dwhlib.member_vw(keep=loy_card_number cured_mobile CORRECTED_EMAIL_ADDRESS final_acc final_lcn);
rc = demos.find();
if rc = 0;
run;

%let status2 = &Syserr.;
%let msg2 = &syserrortext.;

%if &status2. ne %eval(0) %then 
	%do;
		%GOTO Error_stat;
	%end;


proc sql;
create table universal_kyc_trans_data as
select
		 a.*
		,b.activity_Date
		,b.activity_Value
		,b.allocated_points
		,b.p_commercial_name
		,b.transaction_type_id
		,b.activity_action_id

from templib.Univercell_kyc a join dwhlib.pb_trans_fact_master b on
a.loy_card_number = b.loy_Card_number
and b.p_commercial_name = "UNIVERCELL";
quit;

proc sql;
create table templib.universal_trans_summary as
select
	 loy_card_number
	,sum(case when transaction_type_id in (8,295) then 1 else 0 end) as NO_OF_TRANS
	,sum(case when transaction_type_id in (8,295) then activity_value else 0 end) as TOTAL_SALES
	,sum(case when transaction_type_id in (8,295) then allocated_points else 0 end) as POINTS
from 
universal_kyc_trans_data
group by loy_card_number;
quit;

proc sql;
create table templib.universal_kyc_Trans_final as
select
		 a.*
		,b.NO_OF_TRANS
		,b.TOTAL_SALES
		,b.POINTS

from templib.Univercell_kyc a left outer join templib.universal_trans_summary b on
a.loy_Card_number = b.loy_card_number
;
quit;

data _null_;
a = put(today(),DDMMYYN8.);
call symput('run_dt',a);
run;

%put &run_dt.;

proc sql;
select nobs into :nrows from sashelp.vtable where memname = "UNIVERSAL_KYC_TRANS_FINAL" and libname = "TEMPLIB";
quit;


filename Univer "G:\sas\OUTPUT\Univercell_kyc_&run_Dt..txt";

data _null_;
file Univer dlm='|';
set templib.universal_kyc_Trans_final;
if _n_ = 1 then
	do;
		put "Loy_card_number,FULL_NAME,EMAIL,CORRECTED_EMAIL_ADDRESS,MOBILE_PHONE,CURED_MOBILE,DATE_OF_BIRTH,ADDRESS_LINE1,ADDRESS_LINE2,ADDRESS_LINE3,ADDRESS_LINE4,CITY,STATE_PROVINCE,ZIP,MARITAL_STATUS,ANNIVERSARY_DATE,OCCUPATION_FUNCTION,EMPLOYMENT_STATUS,GENDER,NO_OF_TRANS,TOTAL_SALES"; 
	end;

put Loy_card_number FULL_NAME EMAIL CORRECTED_EMAIL_ADDRESS MOBILE_PHONE CURED_MOBILE DATE_OF_BIRTH ADDRESS_LINE1 ADDRESS_LINE2 ADDRESS_LINE3 ADDRESS_LINE4 CITY STATE_PROVINCE ZIP MARITAL_STATUS ANNIVERSARY_DATE OCCUPATION_FUNCTION EMPLOYMENT_STATUS GENDER NO_OF_TRANS TOTAL_SALES;
run;


%let status3 = &syserr.;

%if &STATUS3. ne %eval(0) %then 
	%do;
		%GOTO Error_stat;
	%end;

%sftp_file_move(
		PATH=%str(G:\sas\OUTPUT\Univercell_kyc_&run_Dt..txt)
		,destination=%str(/BIU Report/REPORTING/OFFLINE/UNIVERCELL/)
		,host=%STR(10.200.1.7)
        ,user=%str(Vikas.Sinha)
        ,pswd=%str(Lope?cUrie*ditsy15)
		,email=%str(sunil.pinupolu@payback.net)
		,cc=%str(sunil.pinupolu@payback.net)	
		);
/*Jis.Joy@payback.net sumit.puri@payback.net*/
/*		sumit.kumar@payback.net anantharaman.mr@payback.net*/
%generate_email(
	to=  Jis.Joy@payback.net sumit.puri@payback.net,
	CC=  sunil.pinupolu@payback.net anantharaman.mr@payback.net sumit.kumar@payback.net, 
	Subject= Univercell kyc data with Transactions details, 
	Body1=%str(Hi,), 
	Body2=%str(Univercell kyc data file for &rundate. has been completed and placed in the below path),
	Body4=%str( Path and Filename	-	/BIU Report/REPORTING/OFFLINE/UNIVERCELL/Univercell_kyc_&run_Dt..csv),
	Body5=%str( Rows 				-	&nrows. )
				);

%goto finsh;


%Error_stat:


%generate_email(
	to=sunil.pinupolu@payback.net,
	cc=anantharaman.mr@payback.net,
	Subject= %str(Error: - Univercell kyc data file) , 
	Body1=%str(Hi,), Body2=%str(Univercell kyc data extraction status -  &status1.)
	
	);

proc datasets lib=WORK nolist;
delete Univercell_kyc;
QUIT;

%finsh:

%mend;



%Univercell();

/* ---------------------------------------------------------- */
/* ------------------- End of the Program ------------------- */
/* ---------------------------------------------------------- */
