/*
36801998
16006524
*/

data check_dm;
	set dwhlib.dim_member;
	where
		member_id in (36801998, 16006524)
	;
run;


data check_memvw;
	set dwhlib.member_vw;
	where
		member_id in (36801998, 16006524)
	;
run;

proc sql noprint;
	connect to oracle as dwh(user=dwh password=manager path=dwhfo);
	execute (
		create view dmap_vw as
		select TO_CHAR(LOY_CARD_NUMBER) AS loy_Card_number
		, TO_CHAR(member_account_number) AS member_account_number
		, member_id
		, is_current
		, is_card_disabled
		from
			det_member_card_acc_map
	) by dwh;
	disconnect from dwh;
quit;

data check_dmap;
	set dwhlib.dmap_vw;
	where
		member_id in (36801998, 16006524)
	;
run;
