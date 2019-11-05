
%SET_RPT_ENV;

data sasmart.zz_active_base_with_meminfo;
	set sasmart.active_base_with_meminfo;
	
	enrol_source = PUT(put(promo_code_id, pid2part.), $enrgrp.);
	member_city = compress(UPCASE(CITY),,'kA');
	IF 
		indexw(UPCASE(member_city), "DUMMY")
		OR 
		INDEXw(UPCASE(member_city), "TEST")
		OR
		INDEXw(UPCASE(member_CITY), "IMINT")
	then member_city = "";
	if strip(upcase(member_city)) in ('BANGALORE','BENGALURU','BENGALOORU','BANGLORE') then member_city = "BANGALORE";
	if strip(upcase(member_city)) in ('NEWDELHI','NEW-DELHI','NEW DELHI','DELHI','GURGAON', 'GHAZIABAD', 'GREATER NOIDA','NOIDA','FARIDABAD') then member_city = 'DELHI';
	if strip(upcase(member_city)) in ('HYDERABAD','HYD','HYDERBAD','SECUNDERABAD','SECUDERABAD','SECUNDARABAD','SECUNDERABAD','SECUNDERBAD','SECUNDRABAD','SECUNDRABAD8') then member_city = 'HYDERABAD';
	if strip(upcase(member_city)) in ('MUMBAI','NAVIMUMBAI','NEWMUMBAI','VASHI','THANE') then member_city = 'MUMBAI';
	if strip(upcase(member_city)) in (
		'CENNAI'
		'CHAENNAI'
		'CHENAAI'
		'CHENAI'
		'CHENNAI'
		'CHENNAI - 47'
		'CHENNAI - 600059'
		'CHENNAI - 600113'
		'CHENNAI 1'
		'CHENNAI -41'
		'CHENNAI,'
		'CHENNAI.'
		'CHENNAI-116'
		'CHENNAI-17'
		'CHENNAI-29'
		'CHENNAI-41'
		'CHENNAI-42'
		'CHENNAI-44'
		'CHENNAI-45'
		'CHENNAI-59'
		'CHENNAI-73'
		'CHENNAI-73.'
		'CHENNAI-96'
		'CHENNAIFFF'
		'CHENNAO'
		'CHENNIA'
		'CHENNNAI'
		'PERAMBURCHENNAI'
		'PORUR  CHENNAI'
		'SHOZINGANALLUR CHENNAI'
	) then member_city = 'CHENNAI';

	drop city;
run;


proc sql print;
	select distinct enrol_source from sasmart.zz_active_base_with_meminfo;
quit;
