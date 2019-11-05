%include "/sasdata/core_etl/prod/sas/includes/init_env.sas" /source2;
libname dq "/sasdata/core_etl/sudhakar/Test";
libname etl_new "/sasdata/core_etl/prod/libraries/WIPMART";

PROC DATASETS LIBRARY = WHOUSE NOLIST;
	DELETE
		YY_DND_MEMBER
	;
	MODIFY
		DND_MEMBER
	;
	CHANGE
		DND_MEMBER = YY_DND_MEMBER
	;
QUIT;

proc sql noprint;
       select distinct sourced_association_id into: excl_sidlist separated by "," 
              from dwhlib.sid2partner 
              where upcase(strip(exclude)) = "EXCLUDE";
quit;
%PUT Default exclusion list of sourced_association_ids: &excl_sidlist.;

PROC SQL;
CREATE TABLE WHOUSE.DND_MEMBER_1 AS
       SELECT A.*, B.BAD_MOBILE_FLAG, B.dq_mobile_phone
              FROM WHOUSE.MEMBER A
              INNER JOIN etl_new.member_mart B
              ON A.MEMBER_ID=B.MEMBER_ID
              WHERE B.BAD_MOBILE_FLAG="NDNC" and a.is_deleted=0 ;
/*AND A.SOURCED_ASSOCIATION_ID NOT IN  (&excl_sidlist.);*/
QUIT;


data dd;
set WHOUSE.DND_MEMBER_1;
if length(dq_mobile_phone)=10 then cured_mobile1=cats("91",dq_mobile_phone);
else cured_mobile1=dq_mobile_phone;
if SOURCED_ASSOCIATION_ID IN  (&excl_sidlist.) then B2E_FLAG=1; else B2E_FLAG=0;
run;


data WHOUSE.DND_MEMBER;
set dd(drop=dq_mobile_phone);
where length(cured_mobile1)=12 and substr(cured_mobile1,1,3) not in("910","911","912","913","914","915");
/*if length(cured_mobile1)=12 then output;*/
/*else delete;*/
rename cured_mobile1=dq_mobile_phone;
run;


%include "/sasdata/core_etl/prod/sas/sasautos/send_mail.sas" / source2;

      %send_mail(
	  to_list=%str('dharmendrasinh.chavda@payback.in''sudhakar.srinivas@payback.in')
	, cc_list=%str('prashanth.reddy@payback.in' 'ramachandra.u_ext@payback.in')
    , sub=%str(Sucessfully completed Whouse.DND_MEMBER)
    , body=%str(Dear Team,|Whouse.DND_MEMBER File created is Created Sucessfully.|
			-Thank You,|
			Sudhakar S.)
	);

