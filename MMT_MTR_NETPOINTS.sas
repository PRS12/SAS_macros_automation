/************************************************************************************
*       Program      : MMT_MTR_NETBAL.SAS											*
*		Owner        : Analytics, LSRPL                                 			*
*                                                                       			*
*       Author       : LSRL/324                                            			*
*                                                                       			*
*                                                                      				*
*       Description  : Extracts the net points avilable for MMT-MTR Customers		*
*																					*
*       Usage        : To improve engagement of MTR customers on MakeMyTrip         *
*                      - It provides net points balance of MTR customers   			*
*                                                                       			*
*       History      :                                                  			*
*       (Analyst)     	(Date)    	(Changes)                               		*
*                                                                       			*
*        LSRL/324					Created                                         
************************************************************************************/


/* ------ Promo_code_id = 5 for MMT partner filter ------ */
/* ------ Member_card_type_id = 166,167 is to select ELITE & ROYALE  ------ */

%macro MTR_NET();


data Templib.MMT_MTR_NETBAL;
	Length Member_MTR_DESC $7.;
	set Dwhlib.Member_vw(	where=(member_card_type_id in (166,167) ) 
						keep=  Loy_card_number member_Account_number final_acc member_email member_mobile_phone member_card_type_id promo_code_id net_total_points net_total_points_agg);
	if member_card_type_id = 166 then
			Member_MTR_DESC = "ELITE";
	else 
		if member_card_type_id = 167 then
	        Member_MTR_DESC = "ROYALE";

	Net_total_points_dev = net_total_points;
	if final_acc ne "" then Net_total_points_dev = Net_total_points_agg;

	Drop member_card_type_id promo_code_id;

run;

%let status1 = &Syserr. &syserrortext.;

%if &syserr. ne %eval(0) %then 
	%do;
		%GOTO Error_stat;
	%end;


data _null_;
a = put(today(),DDMMYYN8.);
call symput('run_dt',a);
run;

%put &run_dt.;

proc sql;
select nobs into :nrows from sashelp.vtable where memname = "MMT_MTR_NETBAL" and libname = "TEMPLIB";
quit;


filename MMTmtr "G:\sas\OUTPUT\MMT_MTR_Netbal_&run_Dt..txt";

data _null_;
file MMTmtr dlm='|';
set Templib.MMT_MTR_Netbal;
if _n_ = 1 then
	do;
		put @1 "Loy_card_number " @20 "Member Email" @40 "Member Mobile Phone" @55 "MTR Tier Status" @62 "Net Points Avilable"; 
	end;

put Loy_card_number member_email member_mobile_phone Member_MTR_DESC net_total_points;
run;

%let status2 = &syserr. &syserrortext.;

%if &syserr. ne %eval(0) %then 
	%do;
		%GOTO Error_stat;
	%end;



%sftp_file_move(
		PATH=%str(G:\sas\OUTPUT\MMT_MTR_Netbal_&run_Dt..txt)
		,destination=%str(/BIU Report/REPORTING/MMT/)
		,host=%STR(10.200.1.7)
        ,user=%str(Vikas.Sinha)
        ,pswd=%str(Lope?cUrie*ditsy15)
		,email=%str(sunil.pinupolu@payback.net)
		,cc=%str(sunil.pinupolu@payback.net)	
		);

%generate_email(to= sunil.pinupolu@payback.net Shekhar.Shaktawat@payback.net Anoop.Nair@payback.net Anuj.Sahai@payback.net ,
				CC= sumit.kumar@payback.net anantharaman.mr@payback.net , 
				Subject= MMT - MTR Net Balance statementing file , 
				Body1=%str(Hi,), 
				Body2=%str(MMT - MTR Net Balance statementing file for &rundate. has been completed and placed in the below path),
				Body4=%str( Path	-	/BIU REPORT/REPORTING/MMT/MMT_MTR_Netbal_&run_Dt..txt),
				Body5=%str( Rows 	-	&nrows. )
			   );

%goto finsh;


%Error_stat:


%if %symexist(status2) ne 1 %then
		%let status2 =    ;


%generate_email(
	to=sunil.pinupolu@payback.net,
	cc=sunil.pinupolu@payback.net,
	Subject= %str(Error: - MTR Balance statementing file) , 
	Body1=%str(Hi,), Body2=%str(MMT - MTR member data extraction status -  &status1.),
	Body3=%str(Export - File statement status - &status2.)
	);

proc datasets lib=TEMPLIB nolist;
delete MMT_MTR_Netbal;
QUIT;

%finsh:

%mend;



%MTR_NET();

/* ---------------------------------------------------------- */
/* ------------------- End of the Program ------------------- */
/* ---------------------------------------------------------- */
