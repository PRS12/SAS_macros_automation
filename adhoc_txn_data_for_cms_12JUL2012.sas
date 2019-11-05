data templib.activity_details_for_cms_mem;

	IF _N_ = 1 THEN DO;
		declare hash memhash(dataset:"templib.memlist_for_cms_demog(KEEP=loy_card_number)");
		memhash.definekey("LOY_CARD_NUMBER");
		memhash.definedone();
	END;

	set DWHLIB.PB_TRANS_FACT_MASTER
	(
		KEEP=
			loy_card_number
			activity_id
			activity_date
			allocated_points
			preallocated_points
			activity_action_id
			activity_value
			partner_id
			branch
			IDS_setl_date_str
			invoice_number_str
			transaction_type_id
			partner_type
			p_commercial_name
			loyalty_partner_id
			order_partner_id
			order_status_id
			order_date
			redeem_channel_id
			order_id
			order_batch_id
			item_id
			total_cost_points
			quantity
			order_p_commercial_name
			order_partner_type
			address_line:	
	)	
	;
	where
		activity_date >= "01JAN2011"D
	;

	rc = memhash.find();
		
	if rc = 0;

	drop rc;
run;
