/***************************************************************************************
*       Program      : ECOUPON Monthly Transaction Report							   *
*		Owner        : Analytics, LSRPL                                 			   *
*                                                                       			   *
*       Author       : Vikas Sinha                                      			   *
*                                                                       			   *
*       Input        : ecoupon.CAMPAIGN_TRACKER				            			   *
*					 : ecoupon.ECOUPONE_MART			            				   *
*					 : WHOUSE.ACTIVITY_SUBSET_4MONTHS				    			   *
*					 : ecoupon.ECOUPON_REPORTS_ALL_CAMPAIGNS		    			   *
*					 : ecoupon.ec_reject_camp				            			   *
*                                                                       			   *
*       Output       : G:\ECOUPON\Report_Output\Ecoupon_Monthly_Transaction_Report	   *
*                                                                       			   *
*       Description  : This program need to be run on 10th of every month to generate  *
*						ECOUPON Monthly Transaction Report.															   *
*       History      :                                                  			   *
*       (Analyst)     (Date)    (Changes)                               			   *
*                                                                       			   *
***************************************************************************************/

/*%LET tracker = %STR(ECOUPON.ECOUPON_CAMPAIGN_TRACKER_REVISED);*/
%macro Ecoupon_TXN_REPORT(CAMP_NO);
options varlenchk = nowarn;
/*Reset all automatic error macro varibales to zero*/
	proc sql;quit;
	data _null_;run;

	%local  C Tracker dsid rc rc1 CAMP_NO campid STDT ENDT I J;
	%global note;
	%LET I = 0;
	%LET J = 0;
	%let note = %str();

	data ecoupon_tracker;
		set ecoupon.campaign_tracker 
		(keep= camp_no
				month
				camp_name
				type
				p_commercial_name
				partner_type
				city_name
				camp_start_date
				camp_end_date
				offer_terms
				threshold_value_min
				threshold_value_max
				mc_code
				target_count
				grouping_id
				seg_id
				actual_segments
				personalization
				planned_data_extraction
				marketing_platform
				rename=(planned_data_extraction=pde target_count = tc grouping_id=GPID)
				)
			;
			where upcase(marketing_platform) ? "COUPON" and gpid is not null;
			PARTNER_NAME = p_commercial_name;
			CAMP_NO = upcase(CAMP_NO);

	/*		planned_data_extraction = input(pde,??date9.);*/

			planned_data_extraction = pde;
			type =upcase(type);
			p_commercial_name=upcase(p_commercial_name);
			actual_segments=upcase(actual_segments);
			personalization=upcase(personalization);
			PARTNER_NAME=upcase(PARTNER_NAME);

			if anyalpha(tc)  OR  upcase(tc)= "" THEN target_count = 0;
			Else target_count = INPUT(STRIP(TC),COMMA32.);

			if anyalpha(GPID)  OR  upcase(GPID)= "" THEN grouping_id = 0;
			Else grouping_id = input(strip(GPID),?12.);
			if grouping_id  gt 0;

			if missing(actual_segments) then do;
				if find(seg_id,"gen",'i') then do;
					actual_segments = "Generic";
				end;
				Else if find(seg_id,"ACT",'i') then do;
					actual_segments = "Active";
				end;
				Else if find(seg_id,"NAC",'i') then do;
					actual_segments = "Never Active";
				end;
				Else if find(seg_id,"IAC",'i') then do;
					actual_segments = "Inactive";
				end;
			end;
 				
			MTH = INPUT(put(MONTH,MONYY6.),??MONYY6.);

			/*		IF MTH GE INTNX("MONTH",TODAY(),-1);*/
			format planned_data_extraction  CAMP_END_DATE CAMP_START_DATE date9. MTH monyy6.;
			drop pde TC GPID marketing_platform
			;
	%chekNrun;

		%let tracker = ecoupon_tracker;

		%if not %sysfunc(exist(&TRACKER.)) %then
			%do;
				%let note = %str(Tracker -  &Tracker. does not exist. Please import the tracker and Re Run this Code.);
				%goto error_mail;
			%end;
		%else
			%do;
				%let dsid = %sysfunc(open(&tracker.));

				%if %eval(&DSID.) > 0 %THEN
					%DO;
						%let rc1 = %sysfunc(attrn(&dsid.,any));

						%if %EVAL(&rc1.) > 0 %then
							%do;
								%let varnum = %sysfunc(varnum(&dsid.,planned_data_extraction));
								%put &varnum.;

								%if &varnum. > 0 %then
									%do;
										%put dsid: &dsid. Tracker Exists: &TRACKER.;
										%put varnum: &varnum. Variable Exists:Planned_Data_Extraction = put(&varnum., date11.);
										%let rc2 =%sysfunc(close(&dsid.));
									%END;
								%ELSE
									%DO;
										%put Planned_Data_Extraction is not defined;
										%let note = %str(Planned_Data_Extraction is not defined);
										%GOTO ERROR_MAIL;
									%END;
							%end;
						%ELSE
							%DO;
								%let note = %str(There are no obsersation found in &syslast.);
								%GOTO ERROR_MAIL;
							%END;
					%END;
				%ELSE
					%DO;
						%let note = %str(Tracker does not exist: &syslast.);
						%GOTO ERROR_MAIL;
					%END;


				/*Get the Todays Campaign Data*/
				%if %length(&CAMP_NO.) > 2 %then
					%do;

	data curr_day_coupons_&rundate.;
		set &TRACKER. (where=(upcase(Camp_no) in (%upcase(&Camp_no.)) and Grouping_ID is not missing));

		%chekNrun;
					%end;
				%else
					%do;

	proc sql;
		create table 
			curr_day_coupons_&rundate. as 
		select 	
			DISTINCT
				A.*
			from 
				&TRACKER. A
			where 	

/*				planned_data_extraction is not missing */
/*				and */
/*Please remove the below condition if future group customers are required*/
				UPCASE(partner_type) NE "FUTUREGROUP"
				AND
				Grouping_ID is not missing
				and
				A.CAMP_END_DATE ge MAX(INTNX('Month',today(),-4),0)

			%if %sysfunc(exist(ecoupon.ECOUPON_REPORTS_ALL_CAMPAIGNS)) %then
				%do;
					and
					upcase(camp_no) not in 
					(select distinct upcase(camp_no) from ecoupon.ECOUPON_REPORTS_ALL_CAMPAIGNS
						where 
						A.CAMP_END_DATE LE MAX(INTNX('DAY',Latest_Update,-15),0)
					)
				%end;
			%if %sysfunc(exist(ecoupon.ec_reject_camp)) %then
				%do;
					and
					upcase(camp_no) not in 
					(select distinct upcase(camp_no) from ecoupon.ec_reject_camp)
				%end;
			;
			%chekNrun;
					%end;
/*Remove the campaigns from ECOUPON_REPORTS_ALL_CAMPAIGNS to get the latest numbers*/
	PROC SQL;
		DELETE FROM ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS
			WHERE upcase(CAMP_NO) IN (SELECT DISTINCT upcase(CAMP_NO) FROM curr_day_coupons_&rundate.);
	QUIT;

	%get_observation_count(dsn=%cmpres(curr_day_coupons_&rundate.));

	%if %eval(&nobs.) <= 0 %then
		%do;
			%put |+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|;
			%put | Dataset Name: ECOUPON.ECOUPON_TRACKER  DOES NOT HAVE OBSERVATION OR Invalid DATE_OF_EXTRACTION column   |;
			%put | Please import latest the Ecoupon Traker in ECOUPON with Dataset Name: ECOUPON.ECOUPON_TRACKER 		   |;
			%put | If IMPORT is successfule the run this program again													   |;
			%put |+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|;
			%let note =  %str(No Campaign is Scheduled for Today : %SYSFUNC(TODAY(),DATE11.));
			%goto error_mail;

			/*%return;*/
		%end;
	%else
		%do;

			PROC SQL NOPRINT;
				SELECT DISTINCT CAMP_NO INTO :CAMP_ID SEPARATED BY %STR('|')
					FROM curr_day_coupons_&rundate.
						ORDER BY CAMP_NO;

				%chekNrun;
				%put CAMP_ID = &CAMP_ID.;

				/*Select One Campaign in one go*/
				%let i =1;
				%let note = %str();
				%put Value of incremental i : &i.;

				%do %while (%qscan(&camp_id,&i,%str(|)) ne %str());
					%let CAMPID = %qscan(%upcase(&camp_id),&i,%str(|));

			Data %cmpres(curr_campaign_&CAMPID._&rundate.);
				set curr_day_coupons_&rundate. (where=(upcase(Camp_no)="%upcase(&CAMPID.)"));

				%chekNrun;

				/*CAPTURE THE CAMPIAGN PERTICULARS */
			PROC SQL NOPRINT;
				SELECT DISTINCT UPCASE(Type) INTO : TXN_TYPE SEPARATED BY "|"
					FROM %cmpres(curr_campaign_&CAMPID._&rundate.);
				SELECT DISTINCT COMPRESS(UPCASE(QUOTE(P_COMMERCIAL_NAME))) INTO : PRTNAME SEPARATED BY ','
					FROM %cmpres(curr_campaign_&CAMPID._&rundate.);
				SELECT DISTINCT COMPRESS(UPCASE(P_COMMERCIAL_NAME)) INTO : PRT SEPARATED BY ','
					FROM %cmpres(curr_campaign_&CAMPID._&rundate.);
				SELECT DISTINCT partner_type INTO : PRTNER_TYPE 
					FROM %cmpres(curr_campaign_&CAMPID._&rundate.);
			%chekNrun;

				%VTYPE(%cmpres(curr_campaign_&CAMPID._&rundate.),CAMP_start_DATE);

				%IF &VTYPE. = %STR(N) %THEN
					%DO;

			PROC SQL NOPRINT;
				SELECT  min(CAMP_start_DATE) FORMAT = DATE9. INTO  :STDT
					FROM %cmpres(curr_campaign_&CAMPID._&rundate.);
			QUIT;

			%PUT CHECK  STDT = &STDT.;
					%END;
				%ELSE
					%DO;

						PROC SQL;
							SELECT min(INPUT(STRIP(CAMP_start_DATE),DATE9.)) FORMAT = DATE9. INTO  :STDT
								FROM %cmpres(curr_campaign_&CAMPID._&rundate.);
						QUIT;

						%PUT CHECK STDT = &STDT.;
					%END;

				%VTYPE(%cmpres(curr_campaign_&CAMPID._&rundate.),CAMP_END_DATE);

				%IF &VTYPE. = %STR(N) %THEN
					%DO;

						PROC SQL NOPRINT;
							SELECT  MAX(CAMP_END_DATE) + 1 FORMAT = DATE9. INTO  :ENDT
								FROM %cmpres(curr_campaign_&CAMPID._&rundate.);
						QUIT;

						%PUT CHECK  ENDT = &ENDT.;
					%END;
				%ELSE
					%DO;

						PROC SQL NOPRINT;
							SELECT MAX(INPUT(STRIP(CAMP_END_DATE),DATE9.)) + 1 FORMAT = DATE9. INTO  :ENDT
								FROM %cmpres(curr_campaign_&CAMPID._&rundate.);
						QUIT;

						%PUT CHECK ENDT = &ENDT.;
					%END;

				DATA _NULL_;
					/*	SET &SYSLAST.;*/
					IF STRIP("&ENDT.") = "" THEN
						DO;
							CALL SYMPUT ("ENDT", PUT(INTNX('MONTH',"&STDT."D, 0 , 'E'),DATE9.));
						END;

					%chekNrun;
					%PUT 
						TXN_TYPE = &TXN_TYPE.
						PRTNAME = &PRTNAME.
						PRT = &PRT.
						STDT = &STDT.
						ENDT = &ENDT.
					;

					%IF %UPCASE(&TXN_TYPE.) EQ %str(EARN) %THEN
						%DO;

			/*Select the Threshold Values for each campaign*/
				PROC SQL NOPRINT;
					SELECT MIN (THRESHOLD_VALUE_MIN)  , MAX(THRESHOLD_VALUE_MAX) ,MAX(THRESHOLD_VALUE_MIN)
						INTO : MIN_VALUE , :MAX_VALUE, :MAX_OF_MIN
							FROM %cmpres(curr_campaign_&CAMPID._&rundate.)
								WHERE STRIP(UPCASE(Offer_Terms)) = "V";

					%chekNrun;

					%IF &MIN_VALUE. > 0 AND  &MAX_VALUE. > &MAX_OF_MIN. %THEN
						%DO;
							%LET VALUE_LIMIT = %str(&MIN_VALUE. <= ACTIVITY_VALUE <= &MAX_VALUE.);
						%END;
					%ELSE %IF &MIN_VALUE. > 0 AND  &MAX_VALUE. < &MAX_OF_MIN. %THEN
						%DO;
							%LET VALUE_LIMIT  = %str(ACTIVITY_VALUE >= &MIN_VALUE.);
						%END;
					%ELSE %IF &MIN_VALUE. < 0 AND  &MAX_VALUE. < 0 %THEN
						%DO;
							%LET VALUE_LIMIT  = %str(ACTIVITY_VALUE > 0);
						%END;

					%PUT &VALUE_LIMIT;

					/* END OF MACRO VARIABLE DEFINITION */
					

					/*CLEAN THE LIBRARY*/
				PROC DATASETS LIB=ECOUPON NOLIST NOWARN;
					DELETE 
						%cmpres(CMPGN_TXN_&campid.)
						%cmpres(EC_CMPGN_TXN_&campid.)
						%cmpres(EC_&campid.)
						%cmpres(EC_TXN_BPE_&campid.)
						%cmpres(EC_TXN_&campid.)
						%cmpres(EC_TXN_FINAL_&campid.)
						%cmpres(EC_TXN_MATCH_&campid.)
						%cmpres(EC_TXN_SORTED_&campid.)
						%cmpres(ecoupon_bonus_point_&campid.);
					;
				%chekNrun;

				PROC DATASETS LIB=WORK NOLIST NOWARN;
					DELETE T:;
				%chekNrun;

					/* Matching Process */
					options varlenchk=nowarn;

				DATA %cmpres(ECOUPON.EC_&CAMPID.);
					length 
						partner_name  		$100
						APPLIES_FOR			$32
						camp_name	  		$50
						CAMPAIGN_NAME		$100
						EXTRA_XFACTOR		$50
						PERSONALIZATION		$16
						p_commercial_name 	$100
						CALCULATION_METHOD	$100
						POINT_CALCULATION_BASE	$16
						Text 				$255
					;
					format 
						partner_name  		$100.
						APPLIES_FOR			$32.
						camp_name	  		$50.
						CAMPAIGN_NAME		$100.
						EXTRA_XFACTOR		$50.
						PERSONALIZATION		$16.
						p_commercial_name 	$100.
						CALCULATION_METHOD	$100.
						POINT_CALCULATION_BASE	$16.
						Text 				$255.
					;

					IF _N_ = 0 THEN
						SET %cmpres(%cmpres(curr_campaign_&CAMPID._&rundate.));

					IF _N_ = 1 THEN
						DO;
							DECLARE HASH %CMPRES(H&CAMPID.) (DATASET:"%cmpres(%cmpres(curr_campaign_&CAMPID._&rundate.))", hashexp:16);

							%CMPRES(H&CAMPID..DEFINEKEY("GROUPING_ID"));
							%CMPRES(H&CAMPID..DEFINEDATA(ALL:"Y"));
							%CMPRES(H&CAMPID..DEFINEDONE());
						end;

					SET ecoupon.ECOUPONE_MART	(drop= 
													STATUS_ID
													STATUS_NAME
													VISIBLE_FROM
													/*LOYLTY_PARTNER_ID*/
													UPDATED_AT
													/*POINT_CALCULATION_BASE*/
													/*APPLIES_FOR*/
												)
					;
					RC=%CMPRES(H&CAMPID..FIND());

					IF RC=0;

					if missing(OFFER_DESCRIPTION) then
						OFFER_DESCRIPTION = 'Other Offer';

					if missing(actual_segments) then do;
						if find(seg_id,"gen",'i') then do;
							actual_segments = "Generic";
						end;
						Else if find(seg_id,"ACT",'i') then do;
							actual_segments = "Active";
						end;
						Else if find(seg_id,"NAC",'i') then do;
							actual_segments = "Never Active";
						end;
						Else if find(seg_id,"IAC",'i') then do;
							actual_segments = "Inactive";
						end;
					end;
					DROP RC;
				%chekNrun;

				/*Check if any customer Activation/Views exists*/
				/*	%let rc = %str();*/
				%let dsid = %sysfunc(open(%cmpres(ECOUPON.EC_&CAMPID.)));

				%if &dsid %then
					%do;
						%let rc = %sysfunc(ATTRN(&dsid.,any));
						%let rc1 = %sysfunc(close(&dsid.));
					%end;

				%PUT RC = &RC.;

				%IF %eval(&RC) <= 0 %THEN
					%DO;
						%let note =  %str(No Views or Activations for grouping id of Campaign No: &campid.);
						%goto error_mail;

						/* %return; */
					%end;
				%else
					%do;
						/*Query for the Transactions pertaining to selected Grouping ID in Det.Activity*/
						PROC SQL;
							CREATE TABLE %cmpres(ECOUPON.CMPGN_TXN_&CAMPID.) AS
								SELECT
										distinct	
										A.LOY_CARD_NUMBER
									,	A.MEMBER_ID
									,	A.P_COMMERCIAL_NAME
									,	A.PARTNER_ID
									,	A.TRANSACTION_TYPE_ID
									,	A.ACTIVITY_DATE
									,	A.ACTIVITY_ID
									,	A.ACTIVITY_VALUE format=comma32.
									,	A.ALLOCATED_POINTS
									,	A.PARTNER_TYPE
									,	A.INVOICE_NUMBER_STR
									,	A.PROMO_CODE_ID
									,	A.SOURCED_ASSOCIATION_ID
									,	A.CITY
									,	A.BRANCH 
									,	A.LOYALTY_PARTNER_ID

								%IF NOT (%upcase(&PRTNER_TYPE) EQ %STR(AFFILIATE)) %THEN
									%DO;
										FROM 	
											WHOUSE.ACTIVITY_SUBSET_4MONTHS A
										WHERE 
											UPCASE(A.P_COMMERCIAL_NAME) IN (%UPCASE(&PRTNAME.))
											AND 
											A.TRANSACTION_TYPE_ID IN (8, 295)
											AND
											"&stdt"d <= DATEPART(A.ACTIVITY_DATE)  < "&endt"d 
											AND 
											&VALUE_LIMIT.
									%END;
								%ELSE %IF %upcase(&PRTNER_TYPE) EQ %STR(AFFILIATE) %THEN
									%DO;
										FROM 	
												WHOUSE.ACTIVITY_SUBSET_4MONTHS A
											,	WHOUSE.affiliate_partner_list B

										where   (
											UPCASE(b.p_commercial_name) in (%UPCASE(&PRTNAME.))
											and
											UPCASE(A.invoice_number_str) = UPCASE(B.invoice_number_str)
											)
											and 
											a.transaction_type_id = 10
											AND
											"&stdt"d <= DATEPART(A.ACTIVITY_DATE)  < "&endt"d 
											/*Activity_Value is missing for Affliate Partners*/
									%END;
								;
								%chekNrun;

								/*Check if any customer transaction exists*/
								%let dsid = %sysfunc(open(%cmpres(ECOUPON.CMPGN_TXN_&CAMPID.)));

								%if &dsid %then
									%do;
										%let rc = %sysfunc(ATTRN(&dsid.,any));
										%let rc1 = %sysfunc(close(&dsid.));
									%end;

								%PUT RC = &RC.;

								%IF %eval(&RC) > 0 %THEN
									%DO;
										/*Remove any duplicates form the transactional data from WHOUSE.ACTIVITY_SUBSET_4MONTHS*/
						proc sort data=  %CMPRES(ECOUPON.CMPGN_TXN_&CAMPID.) noduprecs;
							by _all_;
						%chekNrun;

							/*Join Transaction Data with LCN who have viewd and activated their coupons*/
						PROC SQL NOPRINT;
							CREATE TABLE %cmpres(ECOUPON.EC_TXN_&CAMPID.) AS
								SELECT distinct 
									B.ACTIVITY_ID
									,  B.LOY_CARD_NUMBER
									,  B.ACTIVITY_DATE
									,  B.ACTIVITY_VALUE format=comma32.
									,  B.ALLOCATED_POINTS
									,  B.P_COMMERCIAL_NAME
									,  B.PROMO_CODE_ID
									,  B.SOURCED_ASSOCIATION_ID
									,  B.CITY
									,  B.INVOICE_NUMBER_STR
									,  B.BRANCH 
									,  B.LOYALTY_PARTNER_ID

									,  A.CAMP_no
									,  A.GROUPING_ID
									,  A.EC_CONTROL_FLAG
									,  A.VALID_FROM
									,  A.VALID_TO
									,  A.COUPON_STATUS
									,  A.OFFER_DESCRIPTION
									,  A.Camp_Name
									,  A.ACTIVATED_DATE
									,  A.VIEWED_DATE
									,  A.ACTIVATED_CHANNEL
									,  A.VIEWED_CHANNEL
									,  A.PERSONALIZATION
									,  A.Seg_ID
									,  A.Actual_segments
									,  A.TEXT LABEL="Treatment text"
									,  A.Target_Count
									,  A.APPLIES_FOR
									,  POINT_CALCULATION_BASE
									,  CALCULATION_METHOD
									,  input(EXTRA_XFACTOR,12.) as EXTRA_XFACTOR  
									,  THRESHOLD

								FROM 
									%cmpres(ECOUPON.CMPGN_TXN_&CAMPID.) B  LEFT JOIN %cmpres(ECOUPON.EC_&CAMPID.) A 
									ON 
									B.LOY_CARD_NUMBER = A.LOY_CARD_NUMBER
									
							;
							%chekNrun;

							/*Put Counter on Txn to segregate one and all txn*/
						PROC SORT DATA=%cmpres(ECOUPON.EC_TXN_&CAMPID.) OUT=%cmpres(ECOUPON.EC_TXN_sorted_&CAMPID.);
							WHERE (ACTIVATED_DATE is not missing and (datepart(ACTIVITY_DATE) GE datepart(ACTIVATED_DATE)))
								or
								(ACTIVATED_DATE is missing and EC_CONTROL_FLAG > 0)
							;
							BY loy_card_number Grouping_id ACTIVITY_DATE ACTIVITY_VALUE ACTIVATED_DATE;

							%chekNrun;

						%get_observation_count(dsn=%cmpres(ECOUPON.EC_TXN_sorted_&CAMPID.));
						%if %eval(&nobs.) <= 0 %then %do;
							%let note = %str(No Observation found after sorting of data : Camp_No: &campid.);
							%GOTO ERROR_MAIL;
						%end;

						data %cmpres(ECOUPON.EC_cmpgn_txn_&CAMPID.);
							SET %cmpres(ECOUPON.EC_TXN_sorted_&CAMPID.);
							BY loy_card_number grouping_id ACTIVITY_DATE ACTIVATED_DATE;

							IF FIRST.grouping_id then
								txn_count = 1;
							else txn_count + 1;
							%chekNrun;

						%include "G:\sas\common\sasautos\get_observation_count.sas";
						%get_observation_count(dsn=%cmpres(ECOUPON.EC_cmpgn_txn_&CAMPID.));

						%if %eval(&nobs.) <= 0 %then %do;
							%let note = %str(No Observation found after sorting and filtering, for one txn or many txn, of data : Camp_No: &campid.);
							%GOTO ERROR_MAIL;
						%end;

							/*Create two dataests for different level of APPLIES_FOR*/
						proc sql noprint;
							select distinct APPLIES_FOR into :BPE separated by "|"
								from &syslast.
									where APPLIES_FOR is not missing;

							%chekNrun;
							%put APPLIES_FOR = &BPE.;
							%let j =1;

							%do %while (%qscan(&BPE.,&j.,%str(|)) ne %str());
								%let BPE_Value = %qscan(&BPE.,&j.,%str(|));

						data %cmpres(ECOUPON.EC_txn_bpe_&CAMPID.);
							set &syslast. (where=(upcase(APPLIES_FOR)="%upcase(&BPE_Value.)"));

							%if not (%upcase(%substr(&BPE_Value.,1,1)) = %str(A)) %then
								%do;
									/*if datapart(ACTIVITY_DATE) = datepart(ACTIVATED_DATE) Then do;*/
									/*if &VALUE_LIMIT;*/
									/*end;*/
									/*else do;*/
									if txn_count lt 2;

									/*end;*/
								%end;

							%chekNrun;

							/*offer level / Grouping id comparision of cust txn	*/
							options varlenchk=nowarn;

						Data %cmpres(ECOUPON.EC_txn_match_&campid.);
							LENGTH OFFER_NOTE $30 personalization $8;
							format 
								P_COMMERCIAL_NAME $100.
								Camp_Name $100.
								personalization $8.
							;

							if _n_ = 0 then
								set %cmpres(%cmpres(curr_campaign_&CAMPID._&rundate.)) (keep= camp_end_date Camp_Name camp_start_date Grouping_ID Offer_Terms P_Commercial_Name threshold_value_max threshold_value_min Personalization );

							if _N_ = 1 THEN
								DO;
									DECLARE HASH %cmpres(HASH_&CAMPID.) (dataset:"%cmpres(curr_campaign_&CAMPID._&rundate.) (keep= camp_end_date Camp_Name camp_start_date Grouping_ID Offer_Terms P_Commercial_Name threshold_value_max threshold_value_min Personalization )");
									%IF %upcase(&PRTNER_TYPE.) EQ %STR(AFFILIATE) %THEN %do;
									%cmpres(HASH_&CAMPID..DEFINEKEY("GROUPING_ID"  ,"Camp_Name"));
									%end;
									%else %do;
									%cmpres(HASH_&CAMPID..DEFINEKEY("GROUPING_ID" ,"P_COMMERCIAL_NAME" ,"Camp_Name"));
									%end;
									%cmpres(HASH_&CAMPID..DEFINEDATA(
										"Camp_Name",
										"P_Commercial_Name",
										"camp_start_date",
										"camp_end_date",
										"Offer_Terms",
										"threshold_value_max",
										"threshold_value_min",
										"Grouping_ID",
										"Personalization"
										));
									%cmpres(HASH_&CAMPID..DEFINEDONE());
								END;

							set %CMPRES(ECOUPON.EC_txn_bpe_&CAMPID.);
							RC=%cmpres(HASH_&CAMPID..FIND());

							IF RC=0 THEN
								DO;
									IF NOT MISSING(VALID_TO) THEN
										DO;
											IF DATEPART(VALID_FROM) <= DATEPART(ACTIVITY_DATE) < DATEPART(VALID_TO) + 1 THEN
												DO;
													IF NOT MISSING(threshold_value_min) THEN
														DO;
															IF NOT MISSING(threshold_value_max) THEN
																DO;
																	IF ACTIVITY_VALUE >= threshold_value_min and ACTIVITY_VALUE <= threshold_value_max THEN
																		DO;
																			OFFER_NOTE= "1 - ";
																		END;
																end;
															ELSE IF MISSING(threshold_value_max) THEN
																DO;
																	IF ACTIVITY_VALUE >= threshold_value_min THEN
																		DO;
																			OFFER_NOTE= "2 -";
																		END;
																end;
														end;
													else
														do;
															OFFER_NOTE="3 -";
														end;
												END;
											ELSE
												DO;
													OFFER_NOTE="4";
												END;
										END;
									ELSE
										DO;
											IF VALID_FROM <= DATEPART(ACTIVITY_DATE) THEN
												DO;
													IF NOT MISSING(threshold_value_min) THEN
														DO;
															IF NOT MISSING(threshold_value_max) THEN
																DO;
																	IF ACTIVITY_VALUE >= threshold_value_min and ACTIVITY_VALUE <= threshold_value_max THEN
																		DO;
																			OFFER_NOTE="5" ;/*TEXT*/
																		END;
																end;
															ELSE IF MISSING(threshold_value_max) THEN
																DO;
																	IF ACTIVITY_VALUE >= threshold_value_min THEN
																		DO;
																			OFFER_NOTE="6" ;/*TEXT*/
																		END;
																end;
														end;
													else
														do;
															OFFER_NOTE="7" ;/*TEXT*/
														end;
												END;
											ELSE
												DO;
													OFFER_NOTE="8"; /*TEXT*/
												END;
										END;
								END;
							ELSE
								DO;
									OFFER_NOTE= "9";
								END;

							if missing(Offer_note) or OFFER_NOTE= "9" then delete;
							drop OFFER_NOTE;

							%chekNrun;
							
							/*Append the observations for One_Txn and All_Txn Offers*/
							%if %eval(&j.) eq 1 %then
								%do;

						proc sql;
							create table %cmpres(ECOUPON.ec_txn_final_&campid.) like %cmpres(ECOUPON.ec_txn_match_&campid.);

							%chekNrun;
								%end;

						proc append base=%cmpres(ECOUPON.EC_txn_final_&CAMPID.) data=%cmpres(ECOUPON.EC_txn_match_&CAMPID.) force;
							%chekNrun;
							%let j = %eval(&j. + 1);

							%end; /*end of loop j*/

						/*Calculate Bonus Point*/
						DATA %cmpres(ECOUPON.EC_txn_final_bp_&CAMPID.);
							SET %cmpres(ECOUPON.EC_txn_final_&CAMPID.);

							if EC_CONTROL_FLAG eq 0 then
								do;
									IF SUBSTR(UPCASE(CALCULATION_METHOD),1,1) = "F" THEN
										DO;
											IF EXTRA_XFACTOR <= 0 THEN
												Bonus_point = 0;
											ELSE Bonus_point = EXTRA_XFACTOR;
										end;
									Else IF SUBSTR(UPCASE(CALCULATION_METHOD),1,1) = "M" THEN
										DO;
											IF EXTRA_XFACTOR <= 0 or ALLOCATED_POINTS <=0 THEN
												Bonus_point = 0;
											else Bonus_point = EXTRA_XFACTOR * ALLOCATED_POINTS;
										END;

									IF Bonus_point <= 0 THEN
										BP_RS_VALUE = 0;
									ELSE BP_RS_VALUE = DIVIDE(Bonus_point,4);
								end;
						RUN;

						/* Genearate Reports */
						/*Create channel Format*/
						/*ECOUPONE FORMAT FOR COMM_CHANNEL*/
						DATA ECOUPON.MST_ECOUPON_COMM_CHANNEL;
							SET ECOUPON.EC_CHANNEL (keep=Channel_Code Channel_Name rename=(Channel_Code = Start CHANNEL_NAME = label)) end=last;
							RETAIN fmtname  "ECOUPON_COMM_CHANNEL" TYPE 'N';
							OUTPUT;

							if last then
								do;
									hlo='O';
									label='Other Channel';
									output;
								end;
						run;

						proc format lib=FORMATS cntlin=ECOUPON.MST_ECOUPON_COMM_CHANNEL;
						RUN;

						/* Calculate Views and Activations*/
						PROC SQL;
							CREATE table T1 AS
								select  
									distinct 
										camp_no
										,	P_COMMERCIAL_NAME LABEL='Partner Name'
										,	Seg_ID LABEL="Segment ID"
										,	COALESCE(ACTIVATED_CHANNEL,  VIEWED_CHANNEL) AS Channel LABEL="Channel"
										,	OFFER_DESCRIPTION "Type of coupon"
										,	PERSONALIZATION LABEL="Type of Personalisation"
										,	GROUPING_ID LABEL="Grouping ID"
										,	datepart(VALID_FROM) as VALID_FROM format=date11. LABEL="Valid From"
										,	datepart(VALID_TO) as VALID_TO format=date11. "Valid To"
										,	TEXT LABEL="Treatment Text"
										,	Actual_segments Label="Target group description"
										,	Target_Count label="Recipients (Target Count)"
										,  COUNT (distinct loy_card_number) AS No_of_unique_views LABEL='Viewer (user with view)'
										,	COUNT (ACTIVATED_DATE) AS No_of_Activations LABEL='Activator/total no. of activations (user with activation)'
										,	EC_CONTROL_FLAG
									FROM 
										%cmpres(ECOUPON.EC_&CAMPID.)
									where 
										coupon_status is not missing AND EC_CONTROL_FLAG < 1

									GROUP BY
										CAMP_NO 
										, 	P_COMMERCIAL_NAME
										,  Seg_ID
										,	Channel
										,	OFFER_DESCRIPTION
										,	GROUPING_ID
										/*		 ,	EC_CONTROL_FLAG*/
										,  PERSONALIZATION
										,	VALID_FROM 
										,	VALID_TO 
										, 	TEXT 
										,	Actual_segments
										,	Target_Count 
									ORDER BY  
										GROUPING_ID
										/*		 ,  EC_CONTROL_FLAG*/
										,	seg_id;

							/* Prepare a table of Basic coupon details and Count Control Grp Cusomers*/
							CREATE TABLE T2 AS
								select  
									distinct 
										camp_no
										, 	P_COMMERCIAL_NAME LABEL='Partner Name'
										,	Seg_ID LABEL="Segment ID"
										/*		 ,	COALESCE(ACTIVATED_CHANNEL,  VIEWED_CHANNEL) AS Channel LABEL="Channel"*/
										,	OFFER_DESCRIPTION "Type of coupon"
										,	PERSONALIZATION LABEL="Type of Personalisation"
										,	GROUPING_ID LABEL="Grouping ID"
										,	datepart(VALID_FROM) as VALID_FROM format=date11. LABEL="Valid From"
										,	datepart(VALID_TO) as VALID_TO format=date11. "Valid To"
										,	TEXT LABEL="Treatment Text"
										,	Actual_segments Label="Target group description"
										,	Target_Count label="Recipients (Target Count)"
										,	sum (EC_CONTROL_FLAG) as Control_group label="Control Group"	
										/*		 ,  EC_CONTROL_FLAG*/
									FROM 
										%cmpres(ECOUPON.EC_&CAMPID.)
									where 
										EC_CONTROL_FLAG GT 0
									GROUP BY 
										P_COMMERCIAL_NAME
										,  Seg_ID
										/*		 ,	Channel*/
										,  OFFER_DESCRIPTION
										,	GROUPING_ID
										/*		 ,	EC_CONTROL_FLAG*/
										,  PERSONALIZATION
										,	VALID_FROM 
										,	VALID_TO 
										, 	TEXT 
										,	Actual_segments
										,	Target_Count 

									ORDER BY  
										GROUPING_ID
										/*		 ,  EC_CONTROL_FLAG*/
										,	seg_id;

							/*Calculate total Number of Unique Customers */
							CREATE TABLE T3 AS
								SELECT   
									DISTINCT
										camp_no
										,	 P_COMMERCIAL_NAME LABEL='Partner Name'
										,  Seg_ID	
										,	 COALESCE(ACTIVATED_CHANNEL,  VIEWED_CHANNEL) AS Channel
										,	 GROUPING_ID "GROUPING ID"
										,  COALESCE(COUNT(DISTINCT LOY_CARD_NUMBER),0) AS TXN_CUST LABEL="Coupon user (user with redemption)" 
									FROM 
										%cmpres(ECOUPON.EC_txn_final_bp_&CAMPID.)
									WHERE 
										ACTIVITY_ID IS NOT MISSING and upcase(Coupon_status) = "ACTIVATED" 
									GROUP BY 
										camp_no
										,	 GROUPING_ID
										,	 Channel
									ORDER BY  
										GROUPING_ID
							;

							/*Calculate total Number of Unique Transactions */
							CREATE TABLE T4 AS
								select   
									DISTINCT
										camp_no
										,	P_COMMERCIAL_NAME LABEL='Partner Name'
										, 	GROUPING_ID LABEL='GROUPING ID'
										,	COALESCE(ACTIVATED_CHANNEL,  VIEWED_CHANNEL) AS Channel
										,  COALESCE(COUNT (distinct ACTIVITY_ID),0) AS No_of_Transactions LABEL="Coupon usage (total no. of redemptions)"
										,  COALESCE(sum(ACTIVITY_VALUE),0) AS Activity_Value LABEL='Achieved Revenue of coupon users in Rs.' format=comma32.
										,  COALESCE(sum(Bonus_point),0) AS total_Bonus_Point
										,  COALESCE(avg(Bonus_point),0) AS Ave_Bonus_Point
										,  COALESCE(sum(BP_RS_VALUE),0) AS Coupon_promotion  label="Coupon promotion points in Rs.*"  format=comma32.
										,  COALESCE(avg(BP_RS_VALUE),0) AS Average_Coupon_promotion label = "Average Coupon promotion points per user with redemption in Rs." format=comma32.
									FROM 
										%cmpres(ECOUPON.EC_txn_final_bp_&CAMPID.)
									WHERE 
										Coupon_Status = "Activated"

									GROUP BY 	 
										camp_no
										,	 P_COMMERCIAL_NAME
										,	 GROUPING_ID
										,	 Channel
									ORDER BY  
										GROUPING_ID
							;

							/*Calculate Control_GRP_Transactions and Activity Value of Control Group Customers*/
							CREATE TABLE T5 AS
								select     
									DISTINCT
										camp_no
										,	P_COMMERCIAL_NAME LABEL='Partner Name'
										, 	GROUPING_ID LABEL='GROUPING ID'
										,  EC_CONTROL_FLAG	
										/*		 ,	COALESCE(ACTIVATED_CHANNEL,  VIEWED_CHANNEL) AS Channel*/
										,  COALESCE(COUNT (distinct ACTIVITY_ID),0) AS Control_GRP_Transactions "no. of redemptions from users who are in the control group"
										,  COALESCE(sum(ACTIVITY_VALUE),0) AS Control_GRP_Activity_Value "Achieved Revenue from users in the control group" format=comma32.
									FROM 
										%cmpres(ECOUPON.EC_txn_final_bp_&CAMPID.)
									WHERE
										EC_CONTROL_FLAG GT 0
									GROUP BY 
										camp_no
										,	 P_COMMERCIAL_NAME
										,	 GROUPING_ID
										,	 EC_CONTROL_FLAG
										/*		  ,	 CHANNEL*/
									ORDER BY  
										GROUPING_ID
										,  EC_CONTROL_FLAG;

							/* Total customers who purchased with a PB card (used & not used coupon) */
							CREATE TABLE T6 AS
								select    
									P_COMMERCIAL_NAME LABEL='PARTNER'
									,  COALESCE(COUNT (distinct Loy_card_number),0) AS Non_Coupon_Cust "Total customers who purchased with a PB card (used & not used coupon)"
								FROM 
									%cmpres(ECOUPON.EC_TXN_&CAMPID.)
								WHERE
									COUPON_STATUS IS MISSING
								GROUP BY 
									P_COMMERCIAL_NAME
							;

							/*Consolidation of T1 To T5*/
							TITLE 'COUPON & CUSTOMER TRANSACTION DATA ';
							CREATE TABLE %CMPRES(ECOUPON.EC_REPORT_&CAMPID.) AS
								SELECT  
									distinct 
										A.camp_no
										,	A.P_COMMERCIAL_NAME LABEL='Partner Name'
										,	A.Seg_ID LABEL="Segment ID"
										,	A.Channel LABEL="Channel" FORMAT=Ecoupon_comm_channel.
										,	A.OFFER_DESCRIPTION "Type of coupon"
										,	A.PERSONALIZATION LABEL="Type of Personalisation"
										,	A.GROUPING_ID LABEL="Grouping ID"
										,	A.VALID_FROM format=date11. LABEL="Valid From"
										,	A.VALID_TO format=date11. "Valid To"
										,	A.TEXT LABEL="Treatment Text"
										,	A.Actual_segments Label="Target group description"
										,	COALESCE(A.Target_Count,0) as target_count label="Recipients (Target Count)"
										,	B.Control_group label="Control Group"	
										,	COALESCE(A.No_of_unique_views,0) AS No_of_unique_views  LABEL='Viewer (user with view)'
										,	COALESCE(A.No_of_Activations,0) AS No_of_Activations LABEL='Activator \ Total no. of activations (user with activation)'
										,	CASE
										WHEN C.TXN_CUST IS MISSING THEN 0
										ELSE C.TXN_CUST
										END AS TXN_CUST LABEL="Coupon user (user with redemption)" 
										,	COALESCE(D.No_of_Transactions,0) AS No_of_Transactions  LABEL="Coupon usage (total no. of redemptions)"
										,	COALESCE(A.No_of_Activations/A.Target_Count,0) AS Activation_Rate format=12.6 "response rate: activations\ receiver"
										,	COALESCE(D.No_of_Transactions/A.Target_Count,0) AS Response_Rate format=12.6 "response rate: coupon usage (redemptions)\ receiver"
										,   COALESCE(D.No_of_Transactions/A.No_of_Activations,0) as Conversion_Rate format=12.6 "conversion rate: coupon usage (redemptions)\ activations"
										,	COALESCE(D.Activity_Value,0) AS Activity_Value LABEL='Achieved Revenue of coupon users in Rs.' format=comma32.
										,	COALESCE(E.Control_GRP_Activity_Value,0) AS Control_GRP_Activity_Value  "Achieved Revenue from users in the control group" format=comma32.
										,	COALESCE(((COALESCE(D.Activity_Value,0)/A.Target_Count) - ( E.Control_GRP_Activity_Value - B.Control_group)),0)
									AS Incremental_revenue "Incremental revenue" format=comma32.
										,	COALESCE(D.No_of_Transactions,0) AS TRGT_GRP_REDEMPTION LABEL="no. of redemptions from users not in the control group"

										,  COALESCE(D.total_Bonus_Point,0) AS total_Bonus_Point
										,  COALESCE(D.Ave_Bonus_Point,0) AS Ave_Bonus_Point
										,  COALESCE(Coupon_promotion ,0) AS Coupon_promotion  label="Coupon promotion points in Rs.*"
										,  COALESCE(Average_Coupon_promotion ,0) AS Average_Coupon_promotion  label = "Average Coupon promotion points per user with redemption in Rs."

										,	COALESCE(E.Control_GRP_Transactions,0) AS CTRL_GRP_REDEMPTION "no. of redemptions from users who are in the control group"
										,	COALESCE(((D.No_of_Transactions/A.Target_Count) - (E.Control_GRP_Transactions/B.Control_group)),0) AS ADDITIONAL_REDEMPTIONS "incremental additional redemptions"		
									FROM 
										(
										(
										(
										(
										T1 A LEFT JOIN T2 B 
										ON 
										A.GROUPING_ID=B.GROUPING_ID AND A.P_COMMERCIAL_NAME = B.P_COMMERCIAL_NAME AND A.camp_no=B.camp_no
										)
									LEFT JOIN
										T3 C
										ON
										A.GROUPING_ID=C.GROUPING_ID AND A.P_COMMERCIAL_NAME = C.P_COMMERCIAL_NAME and a.channel = c.channel AND A.camp_no=C.camp_no
										)
									LEFT JOIN
										T4 D
										ON
										A.GROUPING_ID=D.GROUPING_ID AND A.P_COMMERCIAL_NAME = D.P_COMMERCIAL_NAME and a.channel = d.channel AND A.camp_no=D.camp_no
										)
									LEFT JOIN
										T5 E
										ON
										A.GROUPING_ID=E.GROUPING_ID AND A.P_COMMERCIAL_NAME = E.P_COMMERCIAL_NAME AND A.camp_no=E.camp_no
										)

									ORDER BY  
										A.camp_no
										,	A.GROUPING_ID
							;
							select * from %CMPRES(ECOUPON.EC_REPORT_&CAMPID.);

							%chekNrun;

						/*Add Run Date for the campaign*/
							data %CMPRES(ECOUPON.EC_REPORT_&CAMPID.);
								set %CMPRES(ECOUPON.EC_REPORT_&CAMPID.);
									Latest_Update = today();
									format Latest_Update date9.;
							run;

							/*Apend report for all the campaigns to one Dataset*/
							%IF %SYSFUNC(EXIST(ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS)) %THEN
								%DO;
									%PUT DATA SET EXIST, DO NOT CREATE ONE;

						proc append base=ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS data=%CMPRES(ECOUPON.EC_REPORT_&CAMPID.) force;
							%chekNrun;
								%END;
							%ELSE
								%DO;
									%PUT Data set does not exists please create one and process append;

						PROC SQL;
							CREATE TABLE ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS LIKE %CMPRES(ECOUPON.EC_REPORT_&CAMPID.);

							%chekNrun;

						proc append base=ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS data=%CMPRES(ECOUPON.EC_REPORT_&CAMPID.) force;
							%chekNrun;

								%END;


						/*Remove the Duplicate Records*/
						proc sort data=ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS noduprecs;
							by _all_;
						%chekNrun;

						%END;  /*Check if any customer transaction exists*/
							%ELSE
								%do;
									%let note = %str(No customer transaction exists for Campid: &campid.);
									%GOTO ERROR_MAIL;

								%end;  /*Check if any customer Activation/Views exists*/
									%end;

					%end;  /* %IF %UPCASE(&TXN_TYPE.) EQ EARN %THEN %do */
				%else
					%do;
						%let note = %str(Transaction Type is not Earn for Campid: &campid.);
						%GOTO ERROR_MAIL;
					%end;

				%put note = &note. i = &i. campid = &campid. ;

				/*Creaet dataset for Bonus POint	*/
				%get_observation_count(dsn=%cmpres(ECOUPON.EC_txn_final_&CAMPID.));
				%if %eval(&nobs.) > 0 %then %do;
					Data %cmpres(ecoupon.ecoupon_bonus_point_&campid.);
					length 
							LOY_CARD_NUMBER       $40
							ACTIVITY_ID            8
							ACTIVITY_DATE          8
							ACTIVITY_VALUE         8
							ALLOCATED_POINTS       8
							BRANCH               $40
							P_COMMERCIAL_NAME    $40
							LOYALTY_PARTNER_ID   $8
							;
					set %cmpres(ECOUPON.EC_txn_final_&CAMPID.)
							(KEEP=
								LOY_CARD_NUMBER
								ACTIVITY_ID
								ACTIVITY_DATE
								ALLOCATED_POINTS
								ACTIVITY_VALUE
								BRANCH
								P_COMMERCIAL_NAME
								LOYALTY_PARTNER_ID
								GROUPING_ID
								)
						;
						ACTIVITY_DATE = datepart(ACTIVITY_DATE);
					   if missing(grouping_id) then delete;
					   format ACTIVITY_DATE date9.;
				     %chekNrun;

				  proc export data=%cmpres(ecoupon.ecoupon_bonus_point_&campid)
				     outfile="F:\Campaign_Bonus\Ecoupon\ecoupon_bonus_point_&campid..txt"
				     dbms=dlm replace
				     ;
					delimiter="|";
				  run;
				%end;

					/*Send the error email	*/
					%ERROR_MAIL:

					%if %length(&note.) > 1 %then
						%do;
						/*Create a dataset that stores rejected camp_no and error note */
						   data ec_reject_camp;
							set ecoupon_tracker (where=(strip(upcase(camp_no)) = "%upcase(&campid.)"))  ;
							length rejection_note $100 ;
						        rejection_note = "&note.";
						   run;

						   proc append base = ecoupon.ec_reject_camp data = ec_reject_camp force ;
						   run;
   
						   proc sort data=ecoupon.ec_reject_camp nodupkey;
						   	by _all_;
						   run;

							%include "G:\sas\common\sasautos\Notifications_email_creds.sas";
							filename mailuser email "imran.anwar_ext@payback.net" 
								cc=("amit.pattnaik@payback.net" "Raghavendra.pawar@payback.net" )
								subject= "BIU- MACRO FAILURE NOTIFICATION (MACRO NAME: ECOUPON_ANALYSIS)"
							;
							%LET C = 1;

				Data _null_;
					FILE MAILUSER;
					PUT #&C. @3 "Hi %sysfunc(propcase(Team)),";
					%put &note.;

					%if %length(&note.) > 2 %then
						%do;
							%LET C = %EVAL(&C + 2);
							put #&C. @8 "&NOTE.";
						%end;

					%if %length("&syserrortext.") > 2 %then
						%do;
							%LET C = %EVAL(&C + 1);
							put #&C. @8 "&syserrortext.";
						%END;

					%if %length("&SYSWARNINGTEXT.") > 2 %then
						%do;
							%LET C = %EVAL(&C + 1);
							put #&C. @8 "&SYSWARNINGTEXT.";
						%END;

					%if %length("%SYSFUNC(SYSMSG())") > 2 %then
						%do;
							%LET C = %EVAL(&C + 1);
							put #&C. @8 "%SYSFUNC(SYSMSG())";
						%END;

					%LET C = %EVAL(&C + 2);
					PUT #&C. @2 "Thanks,";
					PUT #%EVAL(&C. + 1) @2 "Data Innovation & Delivery,";
					PUT #%EVAL(&C. + 2) @2 "Business Intelligence Unit,";
					PUT #%EVAL(&C. + 3) @2 "PAYBACK INDIA";
						%end;

					%LET NOTE = %STR();
					%IF %EVAL(&I.) LT 1 %THEN
						%do;
							%let note = %str(There are no campaign to generate report, no campaign is scheduled for %sysfunc(Today(),date9.).);
							%GOTO FINISH;
						%end;
				run;
				;
				/*CLEAN THE LIBRARY*/
				;

				PROC DATASETS LIB=ECOUPON NOLIST NOWARN;
					DELETE 	
						%cmpres(CMPGN_TXN_&campid.)
						%cmpres(EC_CMPGN_TXN_&campid.)
						%cmpres(EC_&campid.)
						%cmpres(EC_REPORT_&campid.)
						%cmpres(EC_TXN_BPE_&campid.)
						%cmpres(EC_TXN_&campid.)
						%cmpres(EC_TXN_FINAL_&campid.)
						%cmpres(EC_TXN_FINAL_BP_&campid.)
						%cmpres(EC_TXN_MATCH_&campid.)
						%cmpres(EC_TXN_SORTED_&campid.)
					;
				%chekNrun;

				Proc Datasets lib=work nolist nowarn;
					delete T:;
				%chekNrun;

				proc sql;
					delete from ecoupon.ec_reject_camp
						where camp_no in (select distinct camp_no from ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS);
				%chekNrun;

							%let i = %eval(&i. +1);

						%end; 		/*end of loop %do %while (%qscan(&camp_id,&i,%str(|)) ne %str());*/
				%end;
		%end;

	/*Check for Observation in final data : ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS to generate final report */
	%let ALL_CAMPAIGNS = %str();
	%let dsid = %sysfunc(open(ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS));

	%if &dsid %then
		%do;
			%let ALL_CAMPAIGNS = %sysfunc(ATTRN(&dsid.,any));
			%let ALL_CAMPAIGNS1 = %sysfunc(close(&dsid.));
		%end;

	%PUT ALL_CAMPAIGNS = &ALL_CAMPAIGNS.;

	%IF %eval(&ALL_CAMPAIGNS) <= 0 %THEN
		%DO;
			%let note =  %str(Final data 'ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS' does not have any observations );

			%chekNrun;
			%return;
		%end;
	%else
		%do;
			/*Generate the Report in Excel format*/
			%include "G:\sas\common\includes\msoffice2k_x.tpl";

			PROC SORT DATA=ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS;
				BY CAMP_NO GROUPING_ID;
			RUN;

			options nodate nonumber center;
			ods escapechar='^';
			%let FontFormatting = %str(font_face=Arial font_weight=Bold font_size=5 foreground=Georgia);
			%let TitleFormatting = %str(face=Arial weight=Bold size=5 color=BLUE BACKGROUND=GREY font=Georgia);
			ods listing close;
			ods noresults;
			goptions reset =all;
			ods tagsets.msoffice2k_x 
				file="G:\ECOUPON\Report_Output\Ecoupon_Monthly_Transaction_Report\ECOUPON_REPORTS_ALL_CAMPAIGNS_&Rundate..xls" style=Normal
				options (   
				orientation="landscape"
				gridlines="No"
				fittopage="yes"
				sheet_name="Ecoupon_Report"
				tabcolor="yellow"
				pagebreaks="no"
				embedded_titles="Yes"
				embedded_footnotes="Yes"
				autofilter="yes"
				);
			title 
				"^S={background=yellow color=Blue font_size=19pt} ECOUPON MONTHLY TRANSACTION REPORT FOR ALL CAMPAIGN ";

			proc report data=%cmpres(ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS) nowd headline headskip center 
				style(header) = {foreground=darkblue background=lightgrey}
				style(report)={background=white cellspacing=0 bordercolor=brown borderwidth=1 rules=rows }
				style(column)={background=white }
				style(lines)={font_weight=bold font_size=14pt just=center vjust=b foreground=black}
			;
				col 
				(  Camp_No status coupon_id p_commercial_name seg_id CHANNEL)
				( '^S={BACKGROUND=red }-Coupon Details- ' OFFER_DESCRIPTION personalization grouping_id VALID_FROM VALID_TO TEXT Actual_segments ) 
				('-Coupon KPIs-' target_count Control_group No_of_unique_views No_of_Activations No_of_Transactions TXN_CUST)
				('-Conversion Rates-' Activation_Rate Response_Rate Conversion_Rate)
				('-Revenue-' Activity_Value Control_GRP_Activity_Value Incremental_revenue)
				('-Promotion points-' Coupon_promotion Average_Coupon_promotion )
				('-Transactions-' TRGT_GRP_REDEMPTION CTRL_GRP_REDEMPTION ADDITIONAL_REDEMPTIONS 
				/*									payback_card_customer target_for_next_campaigns*/ )
				;
				define Camp_No /  style(header)=[background=#003366 foreground=white] width=15 "Campaign Number" center;
				define status / computed  style(header)=[background=#003366 foreground=white] width=15 "status of Points Processing" center;
				define coupon_id / computed  style(header)=[background=#003366 foreground=white] width=15 "Coupon ID" center;
				define p_commercial_name / display style(header)=[background=#003366 foreground=white] center;
				define seg_id  / display style(header)=[background=#003366 foreground=white] center;
				define CHANNEL / display format=Ecoupon_comm_channel. style(header)=[background=#003366 foreground=white]CENTER missing;
				define OFFER_DESCRIPTION  / display style(header)=[background=#003366 foreground=white]CENTER;
				define personalization  / display style(header)=[background=#003366 foreground=white] width=16 center;
				define grouping_id  /  display style(header)=[background=#003366 foreground=white] center;
				define VALID_FROM  / display style(header)=[background=#003366 foreground=white] center;
				define VALID_TO  / display style(header)=[background=#003366 foreground=white] center;
				define TEXT  / display  style(header)=[background=#003366 foreground=white] center FLOW WIDTH=30;
				define Actual_segments  / display  style(header)=[background=#003366 foreground=white] center;
				define target_count  / display style(header)=[background=#3366FF foreground=white] center FORMAT=COMMA15.;
				define Control_group / display style(header)=[background=#3366FF foreground=white] center;
				define No_of_unique_views / style(header)=[background=#3366FF foreground=white] center;
				define No_of_Activations / style(header)=[background=#3366FF foreground=white] width=30 center;
				define No_of_Transactions / style(header)=[background=#3366FF foreground=white] center;
				define TXN_CUST /  style(header)=[background=#3366FF foreground=white] center;
				define Activation_Rate /  style(header)=[background=#003366 foreground=white] width=30 center FORMAT=PERCENT12.6;
				define Response_Rate /  style(header)=[background=#003366 foreground=white] width=40 center FORMAT=PERCENT12.6;
				define Conversion_Rate /  style(header)=[background=#003366 foreground=white] width=30 center FORMAT=PERCENT12.6;
				define Activity_Value /  style(header)=[background=#3366FF  foreground=white] width=20 center format=comma32.;
				define Control_GRP_Activity_Value  /  style(header)=[background=#3366FF  foreground=white] width=20 center format=comma32.;
				define Incremental_revenue /  style(header)=[background=#3366FF  foreground=white]  width=20 center;
				define Coupon_promotion / width=20 "Coupon promotion points in Rs.* "  
					style(header)=[background=#003366  foreground=white] CENTER  format=comma32.;
				define Average_Coupon_promotion / width=20  
					style(header)=[background=#003366  foreground=white] "Average Coupon promotion points per user with redemption in Rs." CENTER  format=comma32.;
				define TRGT_GRP_REDEMPTION /  width=20 
					style(header)=[background=#3366FF foreground=white] "no. of redemptions from users not in the control group" CENTER;
				define CTRL_GRP_REDEMPTION /  width=20 style(header)=[background=#3366FF foreground=white]  "no. of redemptions from users who are in the control group" CENTER;
				define ADDITIONAL_REDEMPTIONS /  width=20 style(header)=[background=#3366FF foreground=white]  "incremental additional  redemptions" CENTER;
				;

				compute status / CHARACTER length=15;
					status = "";
				endcomp;

				compute coupon_id / CHARACTER length=15;
					coupon_id = "";
				endcomp;

				%chekNrun;
				ods tagsets.msoffice2k_x close;
				ods results;
				ods listing;

				/*Finished ODS Output for the all the Campaign */
				/* Send out a confirmation mail of Success*/
				%include "G:\sas\common\sasautos\Notifications_email_creds.sas";
				filename mailuser email "amit.pattnaik@payback.net" 
					cc=("Raghavendra.pawar@payback.net" "amit.pattnaik@payback.net" "imran.anwar_ext@payback.net")
					subject= "BIU- MACRO SUCCESS NOTIFICATION (MACRO NAME: ECOUPON_ANALYSIS) !!!"
					attach=("G:\ECOUPON\Report_Output\Ecoupon_Monthly_Transaction_Report\ECOUPON_REPORTS_ALL_CAMPAIGNS_&Rundate..xls" content_type="application\excel")
				;
				%LET C = 1;

			Data _null_;
				FILE MAILUSER;
				PUT #&C. @3 "Hi %sysfunc(propcase(Team)),";
				%LET C = %EVAL(&C + 2);
				put #&C. @8 "Report has been successfully Generated and has been saved at:";
				put #%EVAL(&C + 1) @8 "G:\ECOUPON\Report_Output\Ecoupon_Monthly_Transaction_Report\ECOUPON_REPORTS_ALL_CAMPAIGNS_&Rundate..xls";
				%LET C = %EVAL(&C + 3);
				PUT #&C. @2 "Thanks,";
				PUT #%EVAL(&C. + 1) @2 "Data Innovation & Delivery,";
				PUT #%EVAL(&C. + 2) @2 "Business Intelligence Unit,";
				PUT #%EVAL(&C. + 3) @2 "PAYBACK INDIA";

				%chekNrun;
				;
				%goto finish;
		%end;

	%finish:

	proc sql;
		delete from ecoupon.ec_reject_camp
			where camp_no in (select distinct camp_no from ECOUPON.ECOUPON_REPORTS_ALL_CAMPAIGNS);
	quit;
	;
			RUN;

			QUIT;

%mend Ecoupon_TXN_REPORT;

%macro chekNrun;
	;
	run;

	quit;

	%global Error_Code_data Error_Code_sql Error_msg Warn_msg;
	%let Error_Code_data  = %str();
	%let Error_Code_sql  = %str();
	%let Error_msg =%str();
	%let Warn_msg = %str();

	%if (%eval(&syserr.) gt 4)  or (%eval(&sqlrc.) gt 4) %then
		%do;
			%let Error_Code_data = SYSERR : %eval(&syserr.);
			%let Error_Code_sql = SQLRC : %eval(&sqlrc.);
			%let Error_msg = SYSMSG : "&SYSERRORTEXT.";
			%let Warn_msg = WARNING : "&SYSWARNINGTEXT.";
			;
			/*Generate Email*/
			%include "/sasdata/core_etl/prod/sas/sasautos/Notifications_email_creds.sas" /source2;
			filename mailuser email to = ("amit.pattnaik@payback.net") 
				cc=("Raghavendra.pawar@payback.net" "amit.pattnaik@payback.net" "imran.anwar_ext@payback.net")
				subject= "BIU- MACRO FAILURE NOTIFICATION (MACRO NAME: ECOUPON_ANALYSIS) by CheckNRun";

			Data _null_;
				%LET C = 1;
				FILE MAILUSER;
				PUT #&c. @3 "Hi Team,";

				/*		%put &note.;*/
				%if %length(&note.) > 2 %then
					%do;
						%LET C = %EVAL(&C + 3);
						put #&c. @8 "&note.";
					%end;

				%if %length(&syserr.) > 1 %then
					%do;
						%LET C = %EVAL(&C + 2);
						put #&c. @8 "&Error_Code_data.";
					%end;

				%if %length(&sqlrc.) > 1 %then
					%do;
						%LET C = %EVAL(&C + 1);
						put #&c. @8 "&Error_Code_sql.";
					%end;

				%if %length("&SYSERRORTEXT.") > 2 %then
					%do;
						%LET C = %EVAL(&C + 1);
						put #&c. @8 &Error_msg.;
					%end;

				%if %length("&SYSWARNINGTEXT.") > 2 %then
					%do;
						%LET C = %EVAL(&C + 1);
						put #&c. @8 &Warn_msg.;
						put #%eval(&c.+1) @8 "%sysfunc(sysmsg())";
					%end;

				%LET C = %EVAL(&C + 2);
				PUT #%EVAL(&C. + 1) @2 "Thanks,";
				PUT #%EVAL(&C. + 2) @2 "Data Innovation & Delivery,";
				PUT #%EVAL(&C. + 3) @2 "Business Intelligence Unit,";
				PUT #%EVAL(&C. + 4) @2 "PAYBACK INDIA";
			RUN;
			;
			%symdel Error_Code_data Error_Code_sql Error_msg Warn_msg c note/ nowarn;

			proc sql;
			quit;

			data _null_;
			run;

			%abort;
		%end;
%mend chekNrun;

%MACRO VTYPE(DSN,VAR);
	%GLOBAL VTYPE;

	DATA _NULL_;
		set &DSN.;
		CALL SYMPUT("VTYPE", vtype(&var.));
	RUN;

	%PUT &VTYPE.;
%MEND VTYPE;
