/* data templib.carded_base;
	set whouse.member
	(keep=
		member_id 
		member_account_number 
		loy_card_number 
		physical_card_type_id 
		reachability 
		member_email 
		member_mobile_phone 
		member_zip
		member_name 
		dob
		is_deleted
		is_member_disabled
		is_dummy_member
		sourced_association_id
		promo_code_id
	);
	where 
		physical_card_type_id in (1, 4)
		and 	
		is_deleted < 1
		and
		is_dummy_member < 1
		and 
		is_member_disabled < 1
	;
run;
*/

proc datasets lib=dwhlib nolist;
	delete
		carded_base
		active_base
	;
quit;

proc sql noprint;
	connect to oracle as dwh(user=dwh password=manager path=DWHFO);
	execute (
		create view carded_base as
		select 
			to_char(dm.loy_card_number) as loy_card_number
			, to_char(dm.member_account_number) as member_account_number
			, dm.member_id
			, dma.physical_card_type_id
			, dma.promo_code_id
			, dma.member_card_type_id
			, dm.sourced_association_id
			, dm.email
			, dm.mobile_phone
			, dm.zip
			, dm.phone1
			, dm.full_name
			, dm.date_of_birth
			, dm.address_line1
			, dm.address_line2
			, dm.address_line3
			, dm.address_line4
			, dm.city
			, dm.state_province
			, dm.active_status_id
			, dm.gender
			, (dm.earn_action_points-dm.burn_action_points-dm.points_under_process) as net_total_points
			, dm.IS_ADDRESS_UPDATED
			, dm.IS_MOBILE_UPDATED
			, dm.is_email_updated
			, dm.IS_MEMBER_SIGNED
			, dm.IS_EMAIL_HARDBOUNCED
			, dm.DEMOGRAPHICS_UPDATED_DATE
			, dm.EMAIL_UPDATE_DATE
			, dm.MOBILE_UPDATE_DATE
			, dm.UPDATE_DATE
			, dm.LATEST_DEMOG_UPDATE_DATE
			, dm.LATEST_PROFILE_UPDATE_DATE
			, dm.CARD_ISSUED_DATE
			, dm.SIGNUP_DATE
			, dm.ADD_DATE
			, dm.FIRST_DEMOG_UPDATE_DATE
			, dm.MARITAL_STATUS
			, dm.MEMBER_ANNUAL_INCOME 
		from
			det_member_card_Acc_map dma
			, dim_member dm
		where
			dma.loy_card_number = dm.loy_card_number
			and
/*			(*/
/*				dma.physical_card_type_id = 1 */
/*				or*/
/*				(*/
/*					dma.physical_card_type_id = 4 */
/*					and*/
/*					(*/
/*						dm.is_mobile_updated > 0*/
/*						or*/
/*						dm.is_Email_updated > 0*/
/*						or */
/*						dm.is_address_updated > 0*/
/*						or*/
/*						dm.is_member_signed > 0*/
/*					) */
/*				)*/
/*			)*/
/*			and 	*/
			dm.is_deleted < 1
			and
			dm.is_dummy_member < 1
			and 
			dm.is_member_disabled < 1
			and
			dm.program_id != 2
			and
			dm.active_status_id not in (5,11,14)		
	) by dwh;
	disconnect from dwh;
quit;

proc sql noprint;
	connect to oracle as dwh (user = dwh password = manager path = DWHFO);
	execute (
		create view active_base as
		select 
			member_id
			, min(activity_date) as min_activity_date
			, max(activity_date) as max_activity_date
		from det_Activity
		where 
			transaction_type_id in (8,295)
		group by
			member_id
	) by dwh;
	disconnect from dwh;
quit;

/* 
proc summary data = dwhlib.carded_base(keep=city) nway;
	class
		city
	;
	output out = templib.carded_city_list (rename=(_freq_=member_count) drop=_type_);
run;

proc sort data = templib.carded_city_list;
	by descending member_Count;
run; 
*/


data sasmart.active_base_with_meminfo(rename=(min_activity_Date_n = min_activity_date max_Activity_date_n = max_activity_date));

	if 0 then do;
		set templib.member_partner_ptd_act_summ;
	end;
	
	format mobile_no $15.;
	format min_activity_date datetime20.;
	format max_activity_date datetime20.;
	
	if _n_ = 1 then do;
		declare hash emlhash(hashexp: 16, dataset:"SUPPLIB.EMAIL_REACHABLE");
		emlhash.definekey("EMAIL");
		emlhash.definedone();

		declare hash mblhash(hashexp: 16, dataset:"SUPPLIB.MBL_REACHABLE");
		mblhash.definekey("LOY_CARD_NUMBER");
		mblhash.definedata("MOBILE_NO");
		mblhash.definedone();

		declare hash acthash(dataset:"dwhlib.active_base(KEEP=member_id min_activity_date max_activity_date)");
		acthash.definekey("member_id");
		acthash.definedata(all:"yes");
		acthash.definedone();

		declare hash crshash(dataset:"templib.member_partner_ptd_act_summ");
		crshash.definekey("member_id");
		crshash.definedata(all:"yes");
		crshash.definedone();
	end;

	set dwhlib.carded_base;

	format reachability $5.;
	format valid_address_flag 8.;

	array address (4) address_line1-address_line4;

	reachability="NONE";

	rce = emlhash.find();
	rcm = mblhash.find();

	if rce = 0 then reachability = "EMAIL";
	if rcm = 0 then reachability = "SMS";
	
	if rce = 0 and rcm = 0 then reachability = "BOTH";

	do i = 1 to dim(address);
		if 
			length(strip(address(1))) < 2 
			or indexw(strip(upcase(address(i))), "DUMMY") > 0 
			or indexw(strip(upcase(address(i))), "TEST") > 0 
			or indexw(strip(upcase(address(i))), "NULL") > 0 
		then bad_address = 1;
	end;

	if anyalpha(strip(zip)) 
		or anypunct(strip(zip))
		or	strip(zip) IN 
			("999999" "888888" "777777" "666666" "555555" "444444" "333333" "222222" "111111")    
		or input(strip(zip), 8.) < 100000
		or input(strip(zip), 8.) > 999999
		or length(strip(zip)) ~= 6
	then 
		bad_zip=1;

	valid_address_flag = 0;
	if not (bad_address or bad_zip) then valid_address_flag = 1;

	gender = upcase(strip(gender));
	age = intck("year", datepart(date_of_birth), "&rundate"d);

	three_mth_actv_cutoff = intnx("month", "&rundate."d, -3,"B");
	six_mth_actv_cutoff = intnx("month", "&rundate."d, -6,"B");
	year_mth_actv_cutoff = intnx("month", "&rundate."d, -12,"B");

	rc1=acthash.find();
	rc2=crshash.find();

	first_swipe_MONTH=put(datepart(min_activity_date), yymmn6.);
	format max_activity_date_N date9.;
	format min_activity_date_N date9.;

	min_activity_date_n = datepart(min_Activity_date);
	max_activity_date_n = datepart(max_Activity_date);

	format actv_flag $10.;
	actv_flag = "NOT_ACTV";
	if rc1 = 0 then do;
		if max_activity_date_n >= three_mth_actv_cutoff then actv_flag = "3MTH_ACTV";
		else if  six_mth_actv_cutoff <= max_activity_date_n < three_mth_actv_cutoff then ACTV_FLAG = "6MTH_ACTV";
		else if  year_mth_actv_cutoff <= max_activity_date_n < six_mth_actv_cutoff then ACTV_FLAG="12MTH_ACTV";
		else if 0 < max_activity_date_n <  year_mth_actv_cutoff then ACTV_FLAG = "EVR_ACTV";
	end;
	drop 
		i
		rc:
		three_mth_actv_cutoff 
		six_mth_actv_cutoff
		year_mth_actv_cutoff
		bad_:
		min_Activity_date
		max_Activity_date
		address_line1-address_line4
		date_of_birth
	;
run;

proc datasets lib=dwhlib nolist;
	delete
		carded_base
		active_base
	;
quit;



