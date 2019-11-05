/************************************************************************
*       Program      : create_partner_kpi_data_mthly.sas                *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Christof S.                                      *
*                                                                       *
*       Input        : Card, Transaction, dim_member, member history    *
*                                                                       *
*                                                                       *
*                                                                       *
*       Output       : dwhwork.rp_analytics_main                        *
*                      dwhwork.rp_analytics_mem                         *
*                      dwhwork.rp_analytics_partner                     *
*                      dwhwork.rp_redemption_12mo                       *
*                      dwhwork.temp_redemp1                             *
*                      dwhwork.temp_rep1                                *
*                                                                       *
*       Dependencies : None.                                            *
*                                                                       *
*       Description  : Program to generate the partner KPI values on a  *
*                      monthly basis.                                   *     
*                                                                       *
*       Usage        : %create_partner_kpi_data_mthly(                  *                                                                       *
*                        datalib=dwh,                                   *
*                        refdate=('01/07/2009'));                       *
*                        for e.g.to capture data for June 2009.         *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
************************************************************************/


%macro create_partner_kpi_data_mthly(refdate=);

	libname dwhwork oracle user=work password=WORK path='dwhfo';

	proc sql;
   	        connect to oracle as dwh ( user = work password = WORK path = 'dwhfo' preserve_comments buffsize=10000);          
		   
		/* -------------------------------------------------
		   Analytics equivalent table with memberid aggregated trx data
		   on program level
		   --------------------------------------------- */

		drop table dwhwork.rp_analytics_main;
		execute(create table rp_analytics_main nologging compress as
		select
		 %str(/)%str(*)+ full(a) full(b) full(c) parallel(a,2) parallel(b,2) parallel(c,2) use_hash(a b c) %str(*)%str(/)
		 a.memberid,
		 no_trx_lt,  
		 no_trx_lt_nonbank,
		 no_trx_3mo,
		 no_trx_3mo_nonbank,
		 no_trx_12mo,
		 no_trx_12mo_nonbank,
		 sales_lt,
		 sales_lt_nonbank,  
		 sales_3mo,
		 sales_3mo_nonbank,
		 sales_12mo,
		 sales_12mo_nonbank,    
		 points_lt,
		 points_lt_nonbank, 
		 points_3mo,
		 points_3mo_nonbank,
		 points_12mo,
		 points_12mo_nonbank,      
		 no_trx_lt_val,
		 no_trx_lt_val_nonbank,  
		 no_trx_3mo_val,
		 no_trx_3mo_val_nonbank,  
		 no_trx_12mo_val,
		 no_trx_12mo_val_nonbank,  
		 first_trx_date,
		 first_trx_date_nonbank,
		 last_trx_date,
		 last_trx_date_nonbank,  
		 tenure,
		 tenure_nonbank,  
		 crossusage,
		 crossusage_nonbank,
		 last_redemption_date,
		 red_points,
		 red_points_nonbank,
		 no_trx_repmo,
		 no_trx_repmo_nonbank,  
		 no_trx_repmo_3mo,
		 no_trx_repmo_3mo_nonbank,  
		 no_trx_repmo_12mo,
		 no_trx_repmo_12mo_nonbank,    
		 a.c_points_repmo,
		 a.c_points_repmo_nonbank,  
		 a.p_points_repmo,
		 a.p_points_repmo_nonbank,   
		 a.b_points_repmo as r_points_repmo,
		 a.b_points_repmo_nonbank as r_points_repmo_nonbank,    
		 a.sales_repmo,
		 a.sales_repmo_nonbank, 
		 a.b_trx_repmo as r_trx_repmo,
		 a.b_trx_nonbank as r_trx_repmo_nonbank,
		 a.no_trx_repmo_val,
		 a.no_trx_repmo_val_nonbank,
		 case when no_trx_lt>0 and tenure>0 then (to_date(&REFDATE,'dd/mm/yyyy')-last_trx_date)/(tenure/no_trx_lt) else null end as wtr,
		 case when no_trx_lt_nonbank>0 and tenure_nonbank>0 then (to_date(&REFDATE,'dd/mm/yyyy')-last_trx_date_nonbank)/(tenure_nonbank/no_trx_lt_nonbank) else null end as wtr_nonbank,
		 case when first_trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and first_trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end as first_active_repmo,
		 case when first_trx_date_nonbank>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and first_trx_date_nonbank<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end as first_active_repmo_nonbank,
		 b.total_points,
		 b.total_burn_points,
		 b.total_expiry_points,
		 b.total_avl_points_to_burn,
		 b.total_earn_points,
		 b.total_restricted_points,
		 a.has_permanent_card,
		 a.has_temporary_card,
		 a.is_non_carded,  
		 a.has_retail_card,    
		 a.has_virtual_card,
		 b.SALUTATION,
		 b.GENDER,
		 b.DATE_OF_BIRTH,
		 months_between(to_date(&REFDATE,'dd/mm/yyyy'),b.DATE_OF_BIRTH)/12 as age,
		 b.nationality,
		 b.marital_status,
		 b.MOBILE_PHONE,
		 b.EMAIL,
		 b.MEMBER_ANNUAL_INCOME,
		 b.QUALIFICATION_DESC,
		 b.RESIDENTIAL_STATUS,
		 b.RESIDENTIAL_TYPE,
		 b.EMPLOYMENT_STATUS,
		 b.OCCUPATION_FUNCTION,
		 b.COMPANY_OCCU_INDUSTRY,
		 b.IS_MEMBER_SIGNED,
		 b.SIGNUP_DATE,
		 b.REGION,
		 b.ZIP,
		 b.COUNTRY,
		 c.EMAIL_REACHABLE,
		 c.MOBILE_REACHABLE,
		 c.NO_PROMO_SMS
		from  
		(  
		select
		  /*+ full(t) full(c) parallel(c,2) parallel(t,2) use_hash(t c) */
		  c.memberid,
		  sum(1) as no_trx_lt,  
		  sum(case when t.trx_type in (1,5) and t.partnerid!=2 then 1 else 0 end) as no_trx_lt_nonbank,
		  sum(case when t.trx_type in (1,5) and t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) then 1 else 0 end) as no_trx_3mo,
		  sum(case when t.trx_type in (1,5) and t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) and t.partnerid!=2 then 1 else 0 end) as no_trx_3mo_nonbank,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) then 1 else 0 end) as no_trx_12mo,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) and t.partnerid!=2 then 1 else 0 end) as no_trx_12mo_nonbank,  
		  sum(case when t.trx_type in (1,5) then t.value else 0 end) as sales_lt,
		  sum(case when t.trx_type in (1,3,5) and t.partnerid!=2 then t.value else 0 end) as sales_lt_nonbank,  
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) then t.value else 0 end) as sales_3mo,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) and t.partnerid!=2 then t.value else 0 end) as sales_3mo_nonbank,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) then t.value else 0 end) as sales_12mo,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) and t.partnerid!=2 then t.value else 0 end) as sales_12mo_nonbank,    
		  sum(case when t.trx_type in (1,3,5) then t.points else 0 end) as points_lt,
		  sum(case when t.trx_type in (1,3,5) and t.partnerid!=2 then t.points else 0 end) as points_lt_nonbank,  
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) then t.points else 0 end) as points_3mo,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) and t.partnerid!=2 then t.points else 0 end) as points_3mo_nonbank,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) then t.points else 0 end) as points_12mo,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) and t.partnerid!=2 then t.points else 0 end) as points_12mo_nonbank,      
		  sum(case when t.trx_type in (1,5) and t.value is not null then 1 else 0 end) as no_trx_lt_val,
		  sum(case when t.trx_type in (1,5) and t.value is not null and t.partnerid!=2 then 1 else 0 end) as no_trx_lt_val_nonbank,  
		  sum(case when t.trx_type in (1,5) and t.value is not null and t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) then 1 else 0 end) as no_trx_3mo_val,
		  sum(case when t.trx_type in (1,5) and t.value is not null and t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3)and t.partnerid!=2 then 1 else 0 end) as no_trx_3mo_val_nonbank,  
		  sum(case when t.trx_type in (1,5) and t.value is not null and t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) then 1 else 0 end) as no_trx_12mo_val,
		  sum(case when t.trx_type in (1,5) and t.value is not null and t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12)and t.partnerid!=2 then 1 else 0 end) as no_trx_12mo_val_nonbank,  
		  min(case when t.trx_type in (1,5) then trx_date else null end) as first_trx_date,
		  min(case when t.trx_type in (1,5)  and t.partnerid!=2 then trx_date else null end) as first_trx_date_nonbank,
		  max(case when t.trx_type in (1,5) then trx_date else null end) as last_trx_date,
		  max(case when t.trx_type in (1,5)  and t.partnerid!=2 then trx_date else null end) as last_trx_date_nonbank,  
		  max(case when t.trx_type in (1,5) then trx_date else null end)-min(case when t.trx_type in (1,5) then trx_date else null end) as tenure,
		  max(case when t.trx_type in (1,5) and t.partnerid!=2 then trx_date else null end)- min(case when t.trx_type in (1,5) and t.partnerid!=2 then trx_date else null end) as tenure_nonbank,  
		  count(distinct case when t.trx_type in (1,5) then t.partnerid else null end) as crossusage,
		  count(distinct case when t.trx_type in (1,5)  and partnerid!=2 then t.partnerid else null end) as crossusage_nonbank,
		  max(case when t.trx_type in (2) then t.trx_date else null end) as last_redemption_date,
		  sum(case when t.trx_type in (2,4) then -t.points else 0 end) as red_points,
		  sum(case when t.trx_type in (2,4) and t.partnerid!=2 then -t.points else 0 end) as red_points_nonbank,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end) as no_trx_repmo,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and partnerid!=2 then 1 else 0 end) as no_trx_repmo_nonbank,  
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end) as no_trx_repmo_3mo,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and partnerid!=2 then 1 else 0 end) as no_trx_repmo_3mo_nonbank,  
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end) as no_trx_repmo_12mo,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and partnerid!=2 then 1 else 0 end) as no_trx_repmo_12mo_nonbank,    
		  sum(case when t.trx_type in (1,3) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then t.points else 0 end) as c_points_repmo,
		  sum(case when t.trx_type in (1,3) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and partnerid!=2 then t.points else 0 end) as c_points_repmo_nonbank,  
		  sum(case when t.trx_type in (5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then t.points else 0 end) as p_points_repmo,
		  sum(case when t.trx_type in (5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and partnerid!=2 then t.points else 0 end) as p_points_repmo_nonbank,    
		  sum(case when t.trx_type in (2,4) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then -t.points else 0 end) as b_points_repmo,
		  sum(case when t.trx_type in (2,4) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and partnerid!=2 then -t.points else 0 end) as b_points_repmo_nonbank,    
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then t.value else 0 end) as sales_repmo,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and partnerid!=2 then t.value else 0 end) as sales_repmo_nonbank, 
		  sum(case when t.trx_type in (2,4) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end) as b_trx_repmo,
		  sum(case when t.trx_type in (2,4) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and partnerid!=2 then 1 else 0 end) as b_trx_nonbank,
		  sum(case when t.trx_type in (1,5) and t.value is not null and t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end) as no_trx_repmo_val,
		  sum(case when t.trx_type in (1,5) and t.value is not null and t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and t.partnerid!=2 then 1 else 0 end) 
		  as no_trx_repmo_val_nonbank,
		  count(distinct case when t.trx_type in (1,5) and t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then t.partnerid else null end) as crossusage_REPMO,
		  count(distinct case when t.trx_type in (1,5) and t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') and t.partnerid!=2 then t.partnerid else null end) 
		  as crossusage_REPMO_nonbank,
		  max(case when c.card_type=1 then 1 else 0 end) as has_permanent_card,
		  max(case when c.card_type=2 then 1 else 0 end) as has_temporary_card,
		  max(case when c.card_type=3 then 1 else 0 end) as is_non_carded,  
		  max(case when c.card_type=4 then 1 else 0 end) as has_retail_card,    
		  max(case when c.card_type=5 then 1 else 0 end) as has_virtual_card
		from
		  star.card_sample c,
		  star.trx_sample t
		where
		  c.card_number=t.card_number and
		  c.dwh_valid=1 and
		  c.valid=1 and
		  t.trx_type<=6 and
		  t.trx_date<to_date(&REFDATE,'dd/mm/yyyy')
		group by 
		 c.memberid 
		) a,
		dwh.dim_member b,
		star.member_hist c
		where
		  a.memberid=b.member_id and
		  a.memberid=c.memberid and
		  c.valid=1 and
		  c.dwh_valid=1 and
		  b.is_member_disabled=0 and
		  b.is_deleted=0) by dwh;
		
		
		
		drop table dwhwork.rp_analytics_mem;
		execute(create table rp_analytics_mem as select /*+ parallel(a,2) */ distinct memberid from rp_analytics_main a) by dwh;   
		   
		   
		/* -------------------------------------------------
		   Analytics equivalent table with memberid aggregated trx data
		   on partner level
		   --------------------------------------------- */
		
		drop table dwhwork.rp_analytics_partner;
		execute(create table rp_analytics_partner nologging compress as
		select
		 %str(/)%str(*)+ full(a) full(b) full(c) parallel(a,2) parallel(b,2) parallel(c,2) use_hash(a b c) %str(*)%str(/)
		 a.memberid,
		 a.partnerid,
		 a.no_trx_lt,  
		 a.no_trx_3mo,
		 a.no_trx_12mo,
		 a.sales_lt,
		 a.sales_3mo,
		 a.sales_12mo,
		 a.points_lt,
		 a.points_3mo,
		 a.points_12mo,
		 a.first_trx_date,
		 a.last_trx_date,
		 a.tenure,
		 a.last_redemption_date,
		 a.red_points,
		 a.no_trx_repmo,
		 a.no_trx_repmo_3mo,
		 a.no_trx_repmo_12mo,
		 a.c_points_repmo,
		 a.p_points_repmo, 
		 a.b_points_repmo as r_points_repmo,
		 a.sales_repmo,
		 a.b_trx_repmo as r_trx_repmo,
		 case when a.no_trx_lt>0 and a.tenure>0 then (to_date(&REFDATE,'dd/mm/yyyy')-a.last_trx_date)/(a.tenure/a.no_trx_lt) else null end as wtr,
		 case when a.first_trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and a.first_trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end as first_active_repmo
		from  
		(  
		select
		  %str(/)%str(*)+ full(t) full(c) parallel(c,2) parallel(t,2) use_hash(t c) %str(*)%str(/)
		  c.memberid,  
		  t.partnerid,
		  sum(1) as no_trx_lt,  
		  sum(case when t.trx_type in (1,5) and t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) then 1 else 0 end) as no_trx_3mo,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) then 1 else 0 end) as no_trx_12mo,
		  sum(case when t.trx_type in (1,5) then t.value else 0 end) as sales_lt,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) then t.value else 0 end) as sales_3mo,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) then t.value else 0 end) as sales_12mo,
		  sum(case when t.trx_type in (1,3,5) then t.points else 0 end) as points_lt,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) then t.points else 0 end) as points_3mo,
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) then t.points else 0 end) as points_12mo,
		  sum(case when t.trx_type in (1,5) and t.value is not null then 1 else 0 end) as no_trx_lt_val,
		  sum(case when t.trx_type in (1,5) and t.value is not null and t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3) then 1 else 0 end) as no_trx_3mo_val,
		  sum(case when t.trx_type in (1,5) and t.value is not null and t.trx_date>=add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12) then 1 else 0 end) as no_trx_12mo_val,
		  min(case when t.trx_type in (1,5) then trx_date else null end) as first_trx_date,
		  max(case when t.trx_type in (1,5) and t.trx_date<to_date(&REFDATE,'dd/mm/yyyy') then trx_date else null end) as last_trx_date,
		  max(case when t.trx_type in (1,5) then trx_date else null end)-min(case when t.trx_type in (1,5) then trx_date else null end) as tenure,
		  count(distinct case when t.trx_type in (1,5) then t.partnerid else null end) as crossusage,
		  max(case when t.trx_type in (2) then t.trx_date else null end) as last_redemption_date,
		  sum(case when t.trx_type in (2,4) then -t.points else 0 end) as red_points,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end) as no_trx_repmo,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-3),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end) as no_trx_repmo_3mo,
		  sum(case when t.trx_type in (1,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end) as no_trx_repmo_12mo,
		  sum(case when t.trx_type in (1,3) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then t.points else 0 end) as c_points_repmo,
		  sum(case when t.trx_type in (5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then t.points else 0 end) as p_points_repmo,  
		  sum(case when t.trx_type in (2,4) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then -t.points else 0 end) as b_points_repmo,
		  sum(case when t.trx_type in (2,4) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-12),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then -t.points else 0 end) as b_points_12mo_repmo,  
		  sum(case when t.trx_type in (2,4) and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then -t.points else 0 end) as b_points_lt_repmo,      
		  sum(case when t.trx_type in (1,3,5) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then t.value else 0 end) as sales_repmo,
		  sum(case when t.trx_type in (2,4) and  t.trx_date>=trunc(add_months(to_date(&REFDATE,'dd/mm/yyyy'),-1),'MM') and t.trx_date<trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM') then 1 else 0 end) as b_trx_repmo
		from
		  star.card_sample c,
		  star.trx_sample t,
		  rp_analytics_mem m
		where  
		  c.card_number=t.card_number and
		  c.dwh_valid=1 and
		  c.valid=1 and
		  t.trx_type<=6 and
		  t.trx_date<to_date(&REFDATE,'dd/mm/yyyy') and
		  c.memberid=m.memberid /* Exclude deleted and disabled cards */
		group by 
		 c.memberid ,
		 t.partnerid
		) a) by dwh;
		  
		
		/* -------------------------------------------------
		   Analytics equivalent table for redemption data 
		   on memberid and partner level
		   --------------------------------------------- */
		
		/* Redemption Table */
		drop table dwhwork.rp_redemption_12mo;
		execute(create table rp_redemption_12mo nologging compress as
		select  
		  %str(/)%str(*)+ full(a) full(c) parallel(a,2) parallel(c,2) use_hash(a b c) %str(*)%str(/)
		  memberid,
		  activity_date as trx_date,  
		  channel,
		  p.partnerid,
		  activity_action_id as trx_type,
		  nvl(a.allocated_points,0) as points
		from
		  dwh.det_activity a,
		  star.card_sample c,
		  star.partner_id_lkp p
		where
		  c.card_number=a.loy_card_number and
		  a.activity_action_id in (2,4,6) and
		  a.partner_id=p.partner_id(+) and
		  a.activity_date>=add_months(trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM'),-12)) by dwh;
		  
		
		/* Prepare redemption data */
		drop table dwhwork.temp_redemp1;
		execute(create table temp_redemp1 as
		select
		  memberid,
		  partnerid,
		  sum(case when trx_type in (4) then -points else points end) as points,
		  count(*) as ntrx_redemp
		from    
		  rp_redemption_12mo
		where
		  channel in (5,6) 
		  and trunc(trx_date,'MM')=to_date(&REFDATE,'dd/mm/yyyy')
		group by 
		  memberid,
		  partnerid) by dwh;
		  
		/* -------------------------------------------------
		   Create the report data for REFDATE
		   --------------------------------------------- */
		 
		drop table dwhwork.temp_rep1;
		execute(create table temp_rep1 as
		select
		  add_months(trunc(to_date(&REFDATE,'dd/mm/yyyy'),'MM'),-1) as reportmonth,
		  p.partnerid,
		  pc_1,
		  pc_2,
		  s.pc_3,
		  pc_4,
		  pc_5,
		  pc_7,
		  pc_9,
		  m.active_12mo as pc_10,
		  case when m.active_12mo>0 then pc_9/m.active_12mo else -1 end as pc_8,
		  case when m.active_12mo_nonbank>0 and p.partnerid!=2 then pc_9/m.active_12mo_nonbank else -1 end as pc_11,
		  pc_12 as pc_12a,
		  case when pc_9>0 then pc_12/pc_9 else -1 end as pc_12,
		  pc_35,
		  pc_35a,
		  pc_35b,
		  pc_35c,
		  pc_35d,
		  m.wtr_def,
		  m.wtr_base,
		  m.wtr_3,
		  case when m.wtr>0 then pc_35/m.wtr else -1 end as pc_36,
		  /* Sales Amount */
		  case when pc_19nom>0 then pc_19/pc_19nom else -1 end as pc_19,
		  case when pc_20nom>0 then pc_20/pc_20nom else -1 end as pc_20,
		  case when pc_21nom>0 then pc_21/pc_21nom else -1 end as pc_21,
		  /* Frequency */
		  case when pc_19nom>0 then pc_22/pc_19nom else -1 end as pc_22,
		  case when pc_20nom>0 then pc_23/pc_20nom else -1 end as pc_23,	
		  case when pc_21nom>0 then pc_24/pc_21nom else -1 end as pc_24,
		  /* Ticket Size */
		  case when pc_22>0 then pc_19/pc_22 else -1 end as pc_28,
		  case when pc_23>0 then pc_20/pc_23 else -1 end as pc_29,
		  case when pc_24>0 then pc_21/pc_24 else -1 end as pc_30,
		  pp_1,
		  pp_2,
		  pp_3,
		  case when points_repmo>0 then pp_1/points_repmo else -1 end as pp_4,
		  case when p.partnerid!=2 and points_repmo_nonbank>0 then pp_1/points_repmo_nonbank else -1 end as pp_20,
		  case when pc_19nom>0 then pp_5/pc_19nom else -1 end as pp_5,
		  case when pc_19nom>0 then pp_6/pc_19nom else -1 end as pp_6,
		  case when pc_19nom>0 then pp_7/pc_19nom else -1 end as pp_7,
		  pp_14,
		  pp_15,
		  case when points_redemp>0 then pp_14/points_redemp else -1 end as pp_16,
		  case when ntrx_redemp>0 then pp_15/ntrx_redemp else -1 end as pp_17,
		  case when pp_15>0 then pp_14/pp_15 else -1 end as pp_18,
		  
		  /* Financial KPI */
		  /* pf_1: Revenue from pp_1  */
		  pc_19 as pf_13,
		  case when m.sum_sales_repmo>0 then pc_19/sum_sales_repmo else -1 end as pf_16,		  
		  /* Sales per Outlet pf_ 18: To be done with branch table */
		  -1 as pf_18,
		  sysdate as inserted		  
		from 
		(select
		  %str(/)%str(*)+ full(a) full(b) parallel(a,2) parallel(b,2) use_hash(a b) %str(*)%str(/)  
		  a.partnerid,
		  sum(case when a.NO_TRX_REPMO>0 then 1 else 0 end) as pc_1,
		  sum(a.NO_TRX_REPMO) as pc_2,
		  /* total count of first card transactions (first time transaction) - sourced by partner. Better: 
		     Just number of self akquired customers having their first transaction at this partner
		   */     
		  sum(case when 
		       c.sourced_association_id in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		       and first_active_repmo=1 
		       then 1 else 0 end) as pc_4,
		  /* total count of first card transactions (first time transaction) - others. Better: 
		     Just number of other customers having their first transaction at this partner
		   */     
		  sum(case when 
		       c.sourced_association_id not in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		       and first_active_repmo=1 
		       then 1 else 0 end) as pc_5,
		  /* 3 month partner actives: POSITIONS CHANGED */     
		  sum(case when NO_TRX_REPMO_3MO>0 then 1 else 0 end) as pc_7,
		  /* 12 month partner actives: POSITIONS CHANGED */     
		  sum(case when NO_TRX_REPMO_12MO>0 then 1 else 0 end) as pc_9,
		  percentile_cont(0.5) within group (order by case when wtr>0 and wtr<6 then wtr else null end) as pc_35,  		  
		  sum(case when wtr>0 then 1 else 0 end) as pc_35a,  
		  sum(case when wtr>0 and wtr<6 then 1 else 0 end) as pc_35b,  		  
		  sum(case when wtr>3 and wtr<6 then 1 else 0 end) as pc_35c,  		  		  
		  avg(case when wtr>0 and wtr<6 then wtr else null end) as pc_35d,  		  		  
		  /* NONBANK transactions make no sense here! ==> Omit pc_8 and pc_10 ! */
		
		  sum(case when 
		       c.sourced_association_id in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		       and NO_TRX_REPMO_12MO>0 then 1 else 0 end) as pc_12,       
		  sum(case when 
		       c.sourced_association_id not in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		       and NO_TRX_REPMO_12MO>0 then 1 else 0 end) as pc_13,
		  
		  /* Sales amounts */
		  sum(case when no_trx_repmo>0 then sales_repmo else 0 end) as pc_19,
		  sum(case when no_trx_repmo>0 then 1 else 0 end) as pc_19nom,  
		  sum(case when 
		          c.sourced_association_id in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		          and no_trx_repmo>0 then sales_repmo else 0 end) as pc_20,
		  sum(case when 
		          c.sourced_association_id in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		          and no_trx_repmo>0 then 1 else 0 end) as pc_20nom,
		  sum(case when 
		          c.sourced_association_id not in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		          and no_trx_repmo>0 then sales_repmo else 0 end) as pc_21,
		  sum(case when 
		          c.sourced_association_id not in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		          and no_trx_repmo>0 then 1 else 0 end) as pc_21nom,
		  /* Frequency */
		  sum(case when no_trx_repmo>0 then no_trx_repmo else 0 end) as pc_22,        
		  sum(case when 
		          c.sourced_association_id in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		          and no_trx_repmo>0 then no_trx_repmo else 0 end) as pc_23,
		  sum(case when 
		          c.sourced_association_id not in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		          and no_trx_repmo>0 then no_trx_repmo else 0 end) as pc_24,
		
		  /* Points */
		  sum(C_POINTS_REPMO + P_POINTS_REPMO) as pp_1,
		  sum(P_POINTS_REPMO) as pp_2,
		  sum(C_POINTS_REPMO) as pp_3,
		  sum(case when no_trx_repmo>0 then C_POINTS_REPMO + P_POINTS_REPMO else 0 end) as pp_5,
		  sum(case when no_trx_repmo>0 then P_POINTS_REPMO else 0 end) as pp_6,
		  sum(case when no_trx_repmo>0 then C_POINTS_REPMO else 0 end) as pp_7,
		  sum(r.points) as pp_14,
		  sum(r.ntrx_redemp) as pp_15
		from
		  rp_analytics_partner a,
		  star.source_aid_lkp b,
		  star.member_sample c,
		  temp_redemp1 r
		where
		  a.memberid=c.memberid and
		  c.sourced_association_id=b.source_a_id  and
		  a.memberid=r.memberid(+) and
		  a.partnerid=r.partnerid(+)
		group by 
		  a.partnerid) p,
		(select  
		  sum(case when no_trx_repmo_12mo>0 then 1 else 0 end) as active_12mo,
		  sum(case when no_trx_repmo_12mo_nonbank>0 then 1 else 0 end) as active_12mo_nonbank,
		  percentile_cont(0.5) within group (order by case when wtr>0 and wtr<6 then wtr else null end) as wtr,
		  sum(case when wtr>0 then 1 else 0 end) as wtr_def,
		  sum(case when wtr>0 and wtr<6 then 1 else 0 end) as wtr_base,
		  sum(case when wtr>0 and wtr<3 then 1 else 0 end) as wtr_3,		 
		  sum(sales_repmo) as sum_sales_repmo,
		  sum(C_POINTS_REPMO+P_POINTS_REPMO) as points_repmo,
		  sum(C_POINTS_REPMO_NONBANK+P_POINTS_REPMO_NONBANK) as points_repmo_nonbank,
		  sum(nvl(b.points,0)) as points_redemp,
		  sum(nvl(b.ntrx_redemp,0)) as ntrx_redemp
		 from
		   rp_analytics_main a,
		   (select memberid,sum(points) as points,sum(ntrx_redemp) as ntrx_redemp from temp_redemp1 group by memberid) b
		 where
		   a.memberid=b.memberid(+)
		 ) m,
		 (select
		   a.partnerid, 
		     /* total count of registered members / registrations */
		   sum(case when 
		       c.sourced_association_id in (select source_a_id from star.source_aid_lkp s1 where s1.partnerid=a.partnerid) 
		       and signup_date>=to_date(&REFDATE,'dd/mm/yyyy') and signup_date<add_months(to_date(&REFDATE,'dd/mm/yyyy'),1)           
		       then 1 else 0 end) as pc_3
		   from
		     star.partnername a,
		     star.member_sample c
		   group by 
		     a.partnerid) s
		 where
		   p.partnerid=s.partnerid
		 order by partnerid) by dwh;
		 
		 /* -------------------------------------------------
		    Insert into the common table
		    --------------------------------------------- */
    execute(insert into report_partner
    select
				REPORTMONTH,
				PARTNERID,
				PC_1,
				PC_2,
				PC_3,
				PC_4,
				PC_5,
				PC_7,
				PC_9,
				PC_10,
				PC_8,
				PC_11,
				PC_12A,
				PC_12,
				PC_35,
				PC_36,
				PC_19,
				PC_20,
				PC_21,
				PC_22,
				PC_23,
				PC_24,
				PC_28,
				PC_29,
				PC_30,
				PP_1,
				PP_2,
				PP_3,
				PP_4,
				PP_20,
				PP_5,
				PP_6,
				PP_7,
				PP_14,
				PP_15,
				PP_16,
				PP_17,
				PP_18,
				PF_13,
				PF_16,
				PF_18,
				INSERTED,
				PC_35A,
				PC_35B,
				PC_35C,
				PC_35D,
				WTR_DEF,
				WTR_BASE,
				WTR_3
    from temp_rep1) by dwh;
     
	  disconnect from dwh;
	quit;

%mend create_partner_kpi_data_mthly;

/* Input: Reference date of the report. Example: '01/05/2011' means: The base data are created for the time before 01/05/2011. Reporting month is therefore not may, 
but april 2011.
In the output the reporting month is given directly, therefore april for the april report. */
