/************************************************************************
*       Program      : create_sas_views_for_orcl.sas                    *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : LSRL\273 (Anantha Raman, M.R.)                   *
*                                                                       *
*       Input        : DWHLIB                                           *
*                                                                       *
*                                                                       *
*                                                                       *
*       Output       :                                                  *
*                                                                       *
*                                                                       *
*                                                                       *
*       Dependencies :                                                  *
*                                                                       *
*       Description  :                                                  *
*                                                                       *
*                                                                       *
*       Usage        :                                                  *
*                                                                       *
*                                                                       *
*                                                                       *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*       LSRL-273	17AUG2012	Adding EBR (C0001)                      *
*       LSRL-273	20SEP2012	Adding view for FG basket (C0002)       *
*       LSRL-273	21NOV2012	Adding column TERMINAL_ID (C0003)       *
*       LSRL-273	03JUN2013	Adding another view with reversals (C0004)*
*       LSRL-273	03JUN2013	Adding order add & update date to view  *
*                               with reversals (C0005)                  *
*       LSRL-273	10JUN2013   Adding ASSOCIATION_ID to cols from 	  *
*                               DET_ACTIVITY for identifying MI txns    *
*                               (C0006)                                 *
*       LSRL-273    07JUL2014 Adding LCN & REDEMPTION CHANNEL to join   *
*                             criteria between DET_ACTIVITY & DET ORDER *
*                             PROCESSING (C0007)                        *
*       LSRL-324    05DEC2014 Added order_refund_points column(C0008)	  *
************************************************************************/

OPTIONS MPRINT MLOGIC SYMBOLGEN;

%include "/sasdata/core_etl/prod/sas/includes/init_env.sas";

/* Transaction mart with member & partner info integrated */

PROC DATASETS LIB=DWHLIB NOLIST;
	delete
		pb_trans_fact_master
		/* C0004 */
		pb_trans_fact_master_with_rev
		/* C0002 */
		fg_activity_basket_master
		det_order_proc_vw
	;
quit;

proc sql noprint;
	connect to oracle as dwh (user=dwh password=manager path=DWHFO);

	execute (
		create view det_order_proc_vw as
		select
			dop.partner_id as order_partner_id
			, dop.order_status_id
			, dop.order_date
			, dop.redeem_channel_id
			, dop.order_id
			, dop.order_batch_id
			, dop.item_id
			, dop.total_cost_points
			, dop.quantity
			/* C0005 */
			, dop.update_date as order_update_date
			, dop.add_date as order_add_date

			, dpl.p_commercial_name as order_p_commercial_name
			, dpl.loyalty_partner_id as order_lmid
			, dpl.partner_type as order_partner_type
		from
			det_order_processing dop 
				LEFT JOIN 
					partner_list dpl 
						on dop.partner_id = dpl.partner_id
	) by dwh;
	disconnect from dwh;
quit;

proc sql noprint;
	connect to oracle as dwh (user=dwh password=manager path=DWHFO);

	execute (
			create view PB_TRANS_fact_master as
			select 
			to_char(da.loy_card_number) as loy_card_number
			, to_char(da.member_account_number) as member_account_number
			, da.member_id
			, da.activity_id
			, da.order_id
			, da.activity_date
			, da.allocated_points
			, da.preallocated_points
			, da.activity_action_id
			, da.activity_value
			, da.partner_id
			/* C0003 */
			, da.terminal_id
			/* C0001 */
			, da.earn_burn_residue
			, da.flex7
			, da.flex8 as branch
			, da.flex10 as IDS_setl_date_str
			, da.flex1 as invoice_number_str
			, da.transaction_type_id
			, da.activity_base24_settlement
			, da.update_date
			, da.member_association_id
			, da.order_refund_points    /* C0008 */
			/* C0006 */
			, da.association_id
			, mv.promo_code_id
			, mv.sourced_association_id
			, mv.physical_card_type_id
			, mv.member_card_type_id
			, mv.phone1
			, mv.date_of_birth
			, mv.signup_date
			, mv.gender
			, mv.zip
			, mv.city
			, mv.state_province
			, mv.full_name
			, mv.address_line1
			, mv.address_line2
			, mv.address_line3
			, mv.address_line4
			, mv.email
			, mv.mobile_phone
			, mv.demographics_updated_date
			, mv.NET_TOTAL_POINTS
			, mv.CUSTOMER_ID
			, mv.cust_point_balance
			, mv.CUST_CURED_MOBILE
			, mv.CUST_CORRECTED_EMAIL_ADDRESS
			, mv.TRUE_ACTIVE_FLAG
			, mv.EVER_ACTIVE_FLAG
			, mv.TRUE_SWIPE_ACTIVE_FLAG
			, mv.FINAL_ACC
			, mv.FINAL_LCN
			, mv.PRIMARY_MEMBER_ID
			, mv.NET_TOTAL_POINTS_AGG
			, dpl.partner_type
			, dpl.p_commercial_name
			, dpl.loyalty_partner_id
			, dop.order_partner_id
			, dop.order_status_id
			, dop.order_date
			, dop.redeem_channel_id
/*			, dop.order_id */
			, dop.order_batch_id
			, dop.item_id
			, dop.total_cost_points
			, dop.quantity
			, dop.order_p_commercial_name
			, dop.order_partner_type
			, (
				case when da.activity_action_id in (2,6) and dop.order_p_commercial_name is not null then dop.order_p_commercial_name
				else dpl.p_commercial_name end
			) activity_order_pname
			, (
				case when da.activity_action_id in (2,6) and dop.order_p_commercial_name is not null then dop.order_date
				else da.activity_date end
			) activity_order_date
			, (
				case when da.activity_action_id in (2,6) and dop.order_p_commercial_name is not null then dop.order_lmid
				else dpl.loyalty_partner_id end
			) activity_order_lmid
		from
			(((det_activity da LEFT JOIN member_vw mv on da.member_id = mv.member_id)
					/* C0007 */
					LEFT JOIN det_order_proc_vw dop on da.order_id = dop.order_id and da.channel = dop.redeem_channel_id)
						LEFT JOIN partner_list dpl on da.partner_id = dpl.partner_id)
		where
			da.record_processed = 1
			and
			da.activity_id not in 
			(
				select distinct referenced_activity_id from det_activity_link
			)
	) by dwh;
	/* C0004 */
	execute (
			create view PB_TRANS_fact_master_WITH_REV as
			select 
			to_char(da.loy_card_number) as loy_card_number
			, to_char(da.member_account_number) as member_account_number
			, da.member_id
			, da.activity_id
			, da.activity_date
			, da.allocated_points
			, da.preallocated_points
			, da.activity_action_id
			, da.activity_value
			, da.partner_id
			/* C0003 */
			, da.terminal_id
			/* C0001 */
			, da.earn_burn_residue
			, da.flex7
			, da.flex8 as branch
			, da.flex10 as IDS_setl_date_str
			, da.flex1 as invoice_number_str
			, da.transaction_type_id
			, da.activity_base24_settlement
			, da.add_date
			, da.update_date
			, da.member_association_id
			/* C0004 */
			, da.association_id
			, mv.promo_code_id
			, mv.sourced_association_id
			, mv.physical_card_type_id
			, mv.member_card_type_id
			, mv.phone1
			, mv.date_of_birth
			, mv.signup_date
			, mv.gender
			, mv.zip
			, mv.city
			, mv.state_province
			, mv.full_name
			, mv.address_line1
			, mv.address_line2
			, mv.address_line3
			, mv.address_line4
			, mv.email
			, mv.mobile_phone
			, mv.demographics_updated_date
			, mv.NET_TOTAL_POINTS
			, mv.CUSTOMER_ID
			, mv.cust_point_balance
			, mv.CUST_CURED_MOBILE
			, mv.CUST_CORRECTED_EMAIL_ADDRESS
			, mv.TRUE_ACTIVE_FLAG
			, mv.EVER_ACTIVE_FLAG
			, mv.TRUE_SWIPE_ACTIVE_FLAG
			, mv.FINAL_ACC
			, mv.FINAL_LCN
			, mv.PRIMARY_MEMBER_ID
			, mv.NET_TOTAL_POINTS_AGG
			, dpl.partner_type
			, dpl.p_commercial_name
			, dpl.loyalty_partner_id
			, dop.order_partner_id
			, dop.order_status_id
			, dop.order_date
			, dop.redeem_channel_id
			, dop.order_id
			, dop.order_batch_id
			, dop.item_id
			, dop.total_cost_points
			, dop.quantity
			, dop.order_p_commercial_name
			, dop.order_partner_type
			, dop.order_add_date
			, dop.order_update_date
			, (
				case when da.activity_action_id in (2,6) and dop.order_p_commercial_name is not null then dop.order_p_commercial_name
				else dpl.p_commercial_name end
			) activity_order_pname
			, (
				case when da.activity_action_id in (2,6) and dop.order_p_commercial_name is not null then dop.order_date
				else da.activity_date end
			) activity_order_date
			, (
				case when da.activity_action_id in (2,6) and dop.order_p_commercial_name is not null then dop.order_lmid
				else dpl.loyalty_partner_id end
			) activity_order_lmid
		from
			(((det_activity da LEFT JOIN member_vw mv on da.member_id = mv.member_id)
					/* C0007 */
					LEFT JOIN det_order_proc_vw dop on da.order_id = dop.order_id and da.channel = dop.redeem_channel_id)
						LEFT JOIN partner_list dpl on da.partner_id = dpl.partner_id)
		/* C0004 */
/*		where*/
/*			da.record_processed = 1*/
/*			and*/
/*			da.activity_id not in */
/*			(*/
/*				select distinct referenced_activity_id from det_activity_link*/
/*			)*/
	) by dwh;
	
	disconnect from dwh;
quit;

proc sql noprint;
	connect to oracle as dwh (user=dwh password=manager path=DWHFO);
	
	/* C0002 */
	execute (
		create view fg_activity_basket_master as
		select
			distinct
			to_char(da.loy_card_number) as loy_card_number
			, to_char(da.member_account_number) as member_account_number
			, da.member_id
			, da.activity_id
			, da.activity_date
			, da.allocated_points
/*			, da.preallocated_points*/
			, da.activity_action_id
			, da.activity_value
			, da.partner_id
			, da.earn_burn_residue
			, da.flex7
			, da.flex8 as branch
			, da.flex10 as IDS_setl_date_str
			, da.flex1 as invoice_number_str
			, da.transaction_type_id
			, bi.txn_inv_num
			, bi.qty
			, bi.tot_turnover_amt
			, bi.dep_code
			, bi.dep_name
			, bi.txn_merch_id
			, dm.date_of_birth
			, dm.gender
			, dm.city
			, dpl.p_commercial_name
		from
			det_activity da
			, basket_info bi
			, dim_member dm
			, partner_list dpl
		where
			dpl.partner_id = da.partner_id
			and
			da.activity_date >= '01-sep-2011'
			and
			da.flex1 = bi.txn_inv_num
			and
			da.member_id = dm.member_id	
	) by dwh;

	disconnect from dwh;
quit;


