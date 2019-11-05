/***********************************************************************\
*       Program      : PRG_ADHOC_COMPUTE_EXPIRY_POINTS.SAS              *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Vikas Sinha				                        *
*                                                                       *
*       Output       : Campaign Reports               					*
*                                                                       *
*       Dependencies : NONE                                             *
*                                                                       *
*       Description  : Campaign Reports								    *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
\***********************************************************************/

%MACRO Campaign_analysis (  TXN_TYPE   =              	  /*EARN OR BURN*/
	                      , STDT     =                    /*DDMMMYYYY*/
	                      , ENDT     =                    /*DDMMMYYYY*/
	                      , PRTNAME  =                    /*PUT VALUE IN QUOTES AND WITH COMMA */
	                      , Value    = %str(>= 0)
	                      , point    = %str(>= 0)
						  , PATH 	 = %str()
						  , camp_id  =  
						  ,	MC_CODE  =  %STR()
	                   );
OPTIONS NOMPRINT NOMLOGIC NOSYMBOLGEN MINOPERATOR NOFMTERR;
OPTIONS FMTSEARCH=(FORMATS CAMPLIB WORK LIBRARY);
%LOCAL PRTNAME PRT P_NAME CAMP_ID;
%IF %LENGTH(&PRTNAME.) > 0 %THEN %DO;
	%let L = 1;
	%DO %WHILE (%SCAN(&PRTNAME. , &L. , %STR(,)) NE %STR());
		%LET P_NAME = %SCAN(&PRTNAME.,&L. , %STR(,));

		%LET PRT = %SYSFUNC(TRANSLATE(%QUOTE(%SYSFUNC(TRANSLATE(%QUOTE(&P_NAME),'','"'))),'',"'"));
		%PUT PRT = &PRT;
		%let PRT = %sysfunc(compress(%quote(&prt),"'"));
		%put &PRT.;

	PROC DATASETS LIB=camplib NOLIST;
		DELETE 
				%CMPRES(CMP_DMP_EFFECTIVE_&CAMP_ID.)
				%CMPRES(CMPGN_text_DATA_&CAMP_ID.)
				%CMPRES(CMPGN_DATA_&Camp_id.)
				%CMPRES(TEST_&camp_id.)
				%CMPRES(UNQ_ACT_&camp_id._&PRT.)
				%CMPRES(BP_first_flag_&camp_id.)
				%CMPRES(BP_left_JOIN_&camp_id.)
				%CMPRES(left_JOIN_2_&camp_id.)
				%CMPRES(CMP_SRC_FLG_&CAMP_ID.)
			;
			RUN;
	QUIT;

	PROC DATASETS LIB=WORK KILL NOLIST;
	QUIT;
	RUN;

	%INCLUDE 'G:\SAS\COMMON\SASAUTOS\READ_CMPGN_FILES.SAS' /SOURCE2;
	%READ_CMPGN_FILES(FILEPATH=&PATH., CAMP_ID= %CMPRES(&CAMP_ID.) , OUTDSN= %CMPRES(camplib.CMPGN_text_DATA_&CAMP_ID.) );

	PROC APPEND BASE=%CMPRES(camplib.CMPGN_DATA_&Camp_id.) DATA=%CMPRES(camplib.CMPGN_text_DATA_&CAMP_ID.) FORCE;
				RUN;


	/* Processing the campaign deployment/selection data in the light of the campaign master ;*/

		DATA %CMPRES(camplib.CMP_DMP_EFFECTIVE_&CAMP_ID.);
			SET %CMPRES(camplib.CMPGN_DATA_&CAMP_ID.);

					IF INDEX(SCAN(SOURCE, -1, '\'),'NL') THEN DO;
						IF INDEX(SCAN(SOURCE, -1, '\'),'CTRL') THEN DO;
						  		NL_CTRL = 1;
						END;
				 		ELSE DO;
								NL_FLG = 1;
						END;
					END;

					IF INDEX(SCAN(SOURCE, -1, '\'),'SMS') THEN DO;
						IF INDEX(SCAN(SOURCE, -1, '\'),'CTRL') THEN DO;
							 SMS_CTRL = 1;
						END;
				 		ELSE DO;
								SMS_FLG = 1;
						END;
					END;
			
			IF (NL_FLG = 1 or  SMS_FLG = 1) THEN DO;
				TARGET = 1;
				CONTROL = 0;
			END;
			ELSE TARGET = 0;

			IF (NL_CTRL = 1 or SMS_CTRL = 1) THEN DO;
				IF (NL_FLG  = 1 or  SMS_FLG  = 1) THEN CONTROL = 0;
				ELSE CONTROL = 1;
			END;
			IF MISSING(NL_FLG) THEN NL_FLG 		= 0;
			IF MISSING(SMS_FLG) THEN SMS_FLG 	= 0;
			IF MISSING(SMS_CTRL) THEN SMS_CTRL 	= 0;
			IF MISSING(NL_CTRL) THEN NL_CTRL 	= 0;
		
	RUN;

	/* RE-FLAGGING FOR WITH ALL UNIQUE CARD NUMBERS */


		PROC SORT DATA=%CMPRES(camplib.CMPGN_DATA_&CAMP_ID.);
			BY CAMP_NO LOY_CARD_NUMBER; 
		RUN;

		DATA %CMPRES(camplib.CMP_SRC_FLG_&CAMP_ID.);
			SET %CMPRES(camplib.CMPGN_DATA_&CAMP_ID.);
				BY CAMP_NO LOY_CARD_NUMBER;


				retain 
					NL_FLG 
					NL_CTRL
					SMS_CTRL 
					SMS_FLG
				;
				IF first.loy_Card_number then do;
					NL_FLG 	 =0;
					NL_CTRL	 =0;
					SMS_CTRL =0;
					SMS_FLG	 =0;
				end;

				IF INDEX(SCAN(SOURCE, -1, '\'),'NL') THEN DO;
					IF INDEX(SCAN(SOURCE, -1, '\'),'CTRL') THEN DO;
					  		NL_CTRL = 1;
					END;
			 		ELSE DO;
							NL_FLG = 1;
					END;
				END;

				IF INDEX(SCAN(SOURCE, -1, '\'),'SMS') THEN DO;
					IF INDEX(SCAN(SOURCE, -1, '\'),'CTRL') THEN DO;
						 SMS_CTRL = 1;
					END;
			 		ELSE DO;
							SMS_FLG = 1;
					END;
				END;
			
			IF LAST.LOY_CARD_NUMBER THEN DO;
				IF (NL_FLG = 1 or  SMS_FLG = 1) THEN DO;
					TARGET = 1;
					CONTROL = 0;
				END;
				ELSE TARGET = 0;

				IF (NL_CTRL = 1 or SMS_CTRL = 1) THEN DO;
					IF (NL_FLG  = 1 or  SMS_FLG  = 1) THEN CONTROL = 0;
					ELSE CONTROL = 1;
				END;
			END;

			IF LAST.LOY_CARD_NUMBER;
		RUN;

	/* create required date format */
	PROC FORMAT;
	PICTURE CMP_DTFMT
		LOW-HIGH = '%0d-%b-%y' (DATATYPE=DATE);
	run;

	/* COLLECT THE CUSTOMER TXN DATA FOR THE CAMPAIGN PERIOD*/

	%IF %UPCASE(&TXN_TYPE.) EQ EARN %THEN 
	     %DO;
	           PROC SQL NOPRINT;
	                SELECT PARTNER_ID INTO: PARTNER_ID_LIST SEPARATED BY ", " FROM DWHLIB.PARTNER_LIST
	                WHERE P_COMMERCIAL_NAME IN (&P_NAME.);
	           QUIT;
			   %PUT &PARTNER_ID_LIST;

	                DATA %CMPRES(camplib.TEST_&camp_id.);
	                Set whouse.Activity_Subset_6Months ;
	                     WHERE  P_COMMERCIAL_NAME IN (&P_NAME.)   /* THIS IS EQUVALENT TO P_COMMERCIAL_NAME */
	                            AND 
	                            TRANSACTION_TYPE_ID IN (8, 295)
	                            AND
	                            "&STDT."d <= ACTIVITY_DATE  < "&ENDT."d + 1;
	                            		
			IF  ACTIVITY_VALUE  &Value. and ALLOCATED_POINTS  &point.;

			IF NOT MISSING (ACTIVITY_DATE) THEN DO;
						FORMAT ACTIVITY_DATE CMP_DTFMT.;
			END;
			IF NOT MISSING (ORDER_DATE) THEN DO;
						FORMAT ORDER_DATE CMP_DTFMT.;
			END;
			
			FORMAT PROMO_CODE_ID PID2PART. SOURCED_ASSOCIATION_ID SID2PART. ;
			run;

	      %END;
	      %ELSE %IF %UPCASE("&TXN_TYPE.") EQ "BURN" %then %do;
				%IF %upcase(&P_NAME.) IN "BIGBAZAAR" "BRANDFACTORY" "CENTRAL" "EZONE" "FOODHALL" "HOMETOWN" "FOODBAZAAR" "PANTALOONS" "FBB" "PLANETSPORTS" %THEN %DO;
	                PROC SQL NOPRINT;
	                     SELECT PARTNER_ID INTO: PARTNER_ID_LIST SEPARATED BY ", " FROM DWHLIB.PARTNER_LIST
	                     WHERE P_COMMERCIAL_NAME IN (&P_NAME.);
	                QUIT;
	     
	                DATA %CMPRES(camplib.TEST_&camp_id.);
	                Set whouse.Activity_Subset_6Months;
	                                           

	                           WHERE (ORDER_P_COMMERCIAL_NAME IN (&P_NAME.) OR P_COMMERCIAL_NAME IN (&P_NAME.))  /* THIS IS EQUVALENT TO P_COMMERCIAL_NAME = 'MMT_DOM_AIR_TCKT'*/
	                                 AND 
	                                 (TRANSACTION_TYPE_ID IN (6, 294))
	                                  AND
	                        		  (
										"&STDT."d <= ACTIVITY_DATE  < "&ENDT."d  + 1 
									   )
	                                  ;
		            IF ALLOCATED_POINTS  &POINT.;
					IF NOT MISSING (ACTIVITY_DATE) THEN DO;
						FORMAT ACTIVITY_DATE CMP_DTFMT.;
					END;
					IF NOT MISSING (ORDER_DATE) THEN DO;
						FORMAT ORDER_DATE CMP_DTFMT.;
					END;
	                FORMAT PROMO_CODE_ID PID2PART. SOURCED_ASSOCIATION_ID SID2PART.;
				run;
		      %END; 
			  %ELSE %IF NOT (%upcase(&P_NAME.) IN "BIGBAZAAR" "BRANDFACTORY" "CENTRAL" "EZONE" "FOODHALL" "HOMETOWN" "FOODBAZAAR" "PANTALOONS" "FBB" "PLANETSPORTS") %THEN %DO;
	                PROC SQL NOPRINT;
	                     SELECT PARTNER_ID INTO: PARTNER_ID_LIST SEPARATED BY ", " FROM DWHLIB.PARTNER_LIST
	                     WHERE P_COMMERCIAL_NAME IN (&P_NAME.);
	                QUIT;
	     
	                DATA %CMPRES(camplib.TEST_&camp_id.);
	                Set whouse.Activity_Subset_6Months;

	                           WHERE (ORDER_P_COMMERCIAL_NAME IN (&P_NAME.) OR P_COMMERCIAL_NAME IN (&P_NAME.))  /* THIS IS EQUVALENT TO P_COMMERCIAL_NAME = 'MMT_DOM_AIR_TCKT'*/
	                                 AND 
	                                 (TRANSACTION_TYPE_ID IN (6, 294))
	                                  AND
	                        		  (
									 	"&STDT."d <= ORDER_DATE  < "&ENDT."d  + 1
									   )
	                                  ;
	                IF  ALLOCATED_POINTS  &POINT.;
					IF NOT MISSING (ACTIVITY_DATE) THEN DO;
						FORMAT ACTIVITY_DATE CMP_DTFMT.;
					END;
					IF NOT MISSING (ORDER_DATE) THEN DO;
						FORMAT ORDER_DATE CMP_DTFMT.;
					END;
	                FORMAT PROMO_CODE_ID PID2PART. SOURCED_ASSOCIATION_ID SID2PART.;
								FORMAT PROMO_CODE_ID PID2PART. SOURCED_ASSOCIATION_ID SID2PART.;
				run;
			    %END; 
		   %END; 
	/*Check if any customer transactin exists*/
		data _null_;
			dsid = open("camplib.TEST_&camp_id.");
			rc = ATTRN(dsid,'any');
			call symputx('rc',rc);
		run;
		%PUT RC = &RC;
	%IF &RC > 0 %THEN %DO;

	/*Flagging for First Swipe at Partner*/

	DATA %CMPRES(CAMPLIB.BP_first_flag_&camp_id.);
	Title "Flagging for First Swipe at Partner";

	IF _N_ = 0  THEN SET opslib.FIRST_PARTNER_SWIPE_FINAL1(KEEP= LOY_CARD_NUMBER P_&PRT.);

	IF _N_ = 1 THEN DO;
		DECLARE HASH F(DATASET: 'opslib.FIRST_PARTNER_SWIPE_FINAL1 (KEEP = LOY_CARD_NUMBER P_&PRT. WHERE =( "&STDT."D <= DATEPART(P_&PRT.) < "&ENDT."D ))');
		F.DEFINEKEY("LOY_CARD_NUMBER");
		F.DEFINEDATA("P_&PRT.");
		F.DEFINEDONE();
	END;

	SET %CMPRES(camplib.TEST_&camp_id.) ;
		
	RC = F.FIND();
	IF RC = 0 THEN FIRST_CMPGN_SWIPE = 1;
	ELSE FIRST_CMPGN_SWIPE = 0;

	RUN;


	proc sql;
	CREATE INDEX LOY_CARD_NUMBER ON  %CMPRES(CAMPLIB.BP_first_flag_&camp_id.) (LOY_CARD_NUMBER);
	CREATE INDEX MEMBER_ID ON %CMPRES(CAMPLIB.BP_first_flag_&camp_id.) (MEMBER_ID);
	QUIT;


	/* EXTRACT DATA FOR ALL THE CARDS PERTAINING TO THE CARD-HOLDER IN DRF */

	PROC DATASETS LIB=DWHLIB NOLIST;
		delete
			%CMPRES(CMP_SRC_FLG_&CAMP_ID.) 
			%CMPRES(cmp_dmp_EFFECTIVE_&camp_id.)
			%CMPRES(cmpgn_card_mem_data_&camp_id.) 
		;
	quit;

	PROC COPY IN=camplib OUT=DWHLIB;
	SELECT %CMPRES(CMP_SRC_FLG_&CAMP_ID.);
	RUN;

	PROC SQL noprint _method;
	CONNECT TO ORACLE AS DWH(USER=DWH PASSWORD= manager path='DWHFO');
	EXECUTE( 
			CREATE table %CMPRES(CMPGN_CARD_MEM_DATA_&CAMP_ID.) AS 
			SELECT 
			DISTINCT 
					 A.*
					,B.MEMBER_ID
			FROM 
					CMP_SRC_FLG_&CAMP_ID. A
					left join 
				    Det_member_card_acc_map	B
					on
					A.LOY_CARD_NUMBER = B.LOY_CARD_NUMBER
			 		) BY DWH;

					DISCONNECT FROM DWH;
	QUIT;


	proc datasets lib=dwhlib nolist;
		delete %CMPRES(cmp_dmp_EFFECTIVE_&camp_id.);
		Delete %CMPRES(CMP_SRC_FLG_&CAMP_ID.);
	run;
	quit;


	/* check for missing member_id*/

	data %CMPRES(missing_mem_id_&camp_id.);
	set %CMPRES(dwhlib.cmpgn_card_mem_data_&camp_id.);
	if missing(member_id) then MISS + 1;
	IF MISS > 0 THEN DO;
	call symput ("FOOTNOTE", "MISSING MEMBER ID EXISTS for &camp_id : &prt.");
	END;
	ELSE DO;
	call symput ("FOOTNOTE", "ALL MEMBER ID EXISTS for &camp_id : &prt.");
	END;
	if missing(member_id);
	PUT "TOTAL MISSING LOY_CARD_NUMBER = " MISS ;
	run;
	footnote "&FOOTNOTE";


	/* reset the source flagging */;

		data %CMPRES(CAMPLIB.BP_left_JOIN_&camp_id.);
			if _n_ = 0 then set %CMPRES(dwhlib.cmpgn_card_mem_data_&camp_id.);
			if _n_  =1 then do;
				declare hash %CMPRES(h_&CAMP_ID.) (dataset:"%CMPRES(dwhlib.cmpgn_card_mem_data_&camp_id.) (DROP=SOURCE)", MULTIDATA:"Y", ORDERED:"Y");
				%CMPRES(h_&CAMP_ID..definekey("MEMBER_ID"));
				%CMPRES(h_&CAMP_ID..definedata("NL_CTRL", "NL_FLG","SMS_FLG","SMS_CTRL","TARGET","CONTROL","NET_TOTAL_POINTS", "CAMP_NO", "LCM_FLAG"));
				%CMPRES(h_&CAMP_ID..definedone());
				end;
			set %CMPRES(CAMPLIB.BP_first_flag_&camp_id.);

			rc = %CMPRES(h_&CAMP_ID..find());
				IF (RC=0) THEN DO;
				%CMPRES(h_&CAMP_ID..HAS_NEXT)(RESULT:R);
					DO WHILE (RC=0);
					RC=%CMPRES(h_&CAMP_ID..FIND_NEXT());
					%CMPRES(h_&CAMP_ID..HAS_NEXT)(RESULT:R);
					END;
				END;
				IF (R ~= 0) THEN CALL MISSING (NL_CTRL, NL_FLG,SMS_FLG,SMS_CTRL,TARGET,CONTROL,NET_TOTAL_POINTS, CAMP_NO, LCM_FLAG);
		run;

	/* CHECK TXN OF CUSTOMERS WHOSE MEMBER_ID NOT CAPTURED*/

		data %CMPRES(CAMPLIB.left_JOIN_2_&camp_id.);
			if _n_ = 0 then set %CMPRES(missing_mem_id_&camp_id.)(DROP=SOURCE MISS);
			if _n_  =1 then do;
				declare hash %CMPRES(h_&CAMP_ID.) (dataset:"%CMPRES(missing_mem_id_&camp_id.) (DROP=SOURCE MISS)", MULTIDATA:"Y", ORDERED:"Y");
				%CMPRES(h_&CAMP_ID..definekey)("loy_card_number");
				%CMPRES(h_&CAMP_ID..definedata)("NL_CTRL", "NL_FLG","SMS_FLG","SMS_CTRL","TARGET","CONTROL","NET_TOTAL_POINTS", "CAMP_NO", "LCM_FLAG");
				%CMPRES(h_&CAMP_ID..definedone());
				end;
			set %CMPRES(CAMPLIB.BP_first_flag_&camp_id.);

			rc = %CMPRES(h_&CAMP_ID..find());
				IF (RC=0) THEN DO;
				%CMPRES(h_&CAMP_ID..HAS_NEXT)(RESULT:R);
					DO WHILE (RC=0);
					RC=%CMPRES(h_&CAMP_ID..FIND_NEXT());
					%CMPRES(h_&CAMP_ID..HAS_NEXT)(RESULT:R);
					END;
				END;
				IF (R ~= 0) THEN CALL MISSING (NL_CTRL, NL_FLG,SMS_FLG,SMS_CTRL,TARGET,CONTROL,NET_TOTAL_POINTS, CAMP_NO, LCM_FLAG);
				if not missing(CAMP_NO);
		run;

		proc append base=%CMPRES(CAMPLIB.BP_left_JOIN_&camp_id.) (DROP=SOURCE) DATA=%CMPRES(CAMPLIB.left_JOIN_2_&camp_id.) FORCE;
		RUN;

		proc sort data=%CMPRES(CAMPLIB.BP_left_JOIN_&camp_id.) noduprecs;
		by _all_;
		run;

	/* Flag the non targeted customers */

		Data %CMPRES(BP_TOTAL_&camp_id.);
		SET %CMPRES(CAMPLIB.BP_left_JOIN_&camp_id.);
			IF MISSING(CAMP_NO) THEN DO;
				OTHERS	= 1 ;
				NL_CTRL	= 0 ;
				NL_FLG	= 0 ;	
				SMS_CTRL= 0 ;	
				SMS_FLG	= 0 ;	
				TARGET  = 0 ;		
				CONTROL = 0 ;
			IF MISSING(LCM_FLAG) THEN LCM_FLAG = "NO_LCM_FLAG" ;	
			END;
			ELSE DO;
				OTHERS	= 0 ;
			END;
		RUN;

	/*Collecting Unique Activities*/
	PROC SORT DATA = %CMPRES(BP_TOTAL_&camp_id.) OUT= %CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.) nodupkey;
	BY activity_id;
	RUN;

	/* CHEKC FOR MC_CODE TXN */
	%IF %LENGTH(&MC_CODE.) > 0 %then %do;
	 data camplib.bskt_&camp_id._&prt. ;
		if _n_ = 0 then set %CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.) (keep= INVOICE_NUMBER_STR activity_id);
		if _n_ = 1 then do;
			declare hash h_bsk (dataset:"%CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.) (keep= INVOICE_NUMBER_STR activity_id)");
			h_bsk.definekey("INVOICE_NUMBER_STR");
			h_bsk.definedata(ALL: "Y");
			h_bsk.definedone();
		end;

		set DWHLIB.BASKET_INFO (KEEP= DEP_CODE TXN_INV_NUM RENAME=(TXN_INV_NUM = INVOICE_NUMBER_STR));
		where upcase(DEP_CODE) in (%upcase(&mc_code.));

		DEP_CODE = PUT(DEP_CODE, $bsktmc2desc.);	

		RC = h_bsk.FIND();
		IF RC = 0;
	 RUN;

	 DATA %CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.);
		if _n_ = 0 then set %CMPRES(camplib.bskt_&camp_id._&prt.);
		if _n_ = 1 then do;
			declare hash h_bsk (dataset:"%CMPRES(camplib.bskt_&camp_id._&prt.)");
			h_bsk.definekey("activity_id");
			h_bsk.definedata(ALL: "Y");
			h_bsk.definedone();
		end;
		set %CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.);
	
		RC = h_bsk.FIND();
		IF RC = 0;
		IF MISSING(DEP_CODE) THEN DEP_CODE = "OTHER_MC'S";

	 RUN;
	%END;

	
	PROC EXPORT DATA=%CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.) OUTFILE="F:\Campaign_Bonus\&camp_id._bskt_&txn_type._&PRT..TXT"
	DBMS= DLM REPLACE;
	DELIMITER="|";
	RUN;


	ods html file="F:\Campaign_Analysis\ODS_REPORTS\&camp_id.&prt..xls";

	/* Creating Tabulate report on Imported data*/

	proc tabulate data=%CMPRES(camplib.cmp_dmp_EFFECTIVE_&camp_id.) F=12. MISSING;
	TITLE "COUNT OF DEPLOYED AND CONTROL DATA FOR CAMPAING:&camp_id.";
	TITLE2 " &camp_id. - &PRT. ";
	CLASS TARGET;

	VAR 	NL_FLG 
		SMS_FLG 
		SMS_CTRL
		NL_CTRL
	;
	TABLE TARGET="",(	NL_FLG
						SMS_FLG
						SMS_CTRL
						NL_CTRL
					)*sum=" " ALL="Total"*N="" / MISSTEXT='0' ROW=FLOAT
	;
	KEYLABEL N="";
	RUN;	


	/*PROC FORMAT;*/
	/*VALUE CMP*/
	/*		. = 'OTHERS';*/
	/*RUN;*/

	PROC SQL;
	TITLE " SUMMRY FOR CAMPAIGN : &camp_id. ";
	TITLE2 " &camp_id. - &PRT. ";
	CREATE TABLE %CMPRES(SUMMARY_&CAMP_ID.) AS
	SELECT 		COUNT(ACTIVITY_ID) AS TXN_COUNT 
			,	COUNT(DISTINCT(LOY_CARD_NUMBER)) AS LCN
			, 	SUM(ALLOCATED_POINTS) AS POINTS
			, 	SUM(ACTIVITY_VALUE) AS VALUE format = 16.
			,   NL_FLG	
			,	SMS_FLG
			,	OTHERS
			,	SMS_CTRL
			,	NL_CTRL
			

	FROM %CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.) 

	group by 	NL_FLG	
			,	SMS_FLG
			,	others
			,	sms_ctrl
			,	nl_ctrl;

	SELECT * FROM %CMPRES(SUMMARY_&CAMP_ID.);
	QUIT;


	PROC SQL;
	TITLE " TARGET AND CONTROL SEGMENTATION : &camp_id. ";
	TITLE2 " &camp_id. - &PRT. ";
	CREATE TABLE %CMPRES(SUMMARY_T_C_&CAMP_ID.) AS
	SELECT 		COUNT(ACTIVITY_ID) AS TXN_COUNT 
			,	COUNT(DISTINCT(LOY_CARD_NUMBER)) AS LCN
			, 	SUM(ALLOCATED_POINTS) AS POINTS
			, 	SUM(ACTIVITY_VALUE) AS VALUE format = 16.
			, 	TARGET
			,	CONTROL

	FROM %CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.) 

	group by  		TARGET
				,	CONTROL;

	SELECT * FROM %CMPRES(SUMMARY_T_C_&CAMP_ID.);
	QUIT;


	PROC SQL NOPRINT;
	TITLE " SOURCEWISE SUMMARY OF CAMPAIGN  : &camp_id. ";
	TITLE2 " &camp_id. - &PRT. ";
	CREATE TABLE %CMPRES(SUMMARY_SID_PID_&CAMP_ID.) AS
	SELECT 		COUNT(ACTIVITY_ID) AS TXN_COUNT 
			,	COUNT(DISTINCT(LOY_CARD_NUMBER)) AS LCN
			, 	SUM(ALLOCATED_POINTS) AS POINTS
			, 	SUM(ACTIVITY_VALUE) AS VALUE format = 16.
			,	PROMO_CODE_ID
			,	SOURCED_ASSOCIATION_ID
			, 	TARGET
			,	CONTROL

	FROM %CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.) 

	group by  		TARGET
				,	CONTROL
				,	SOURCED_ASSOCIATION_ID
				,	PROMO_CODE_ID;


	QUIT;


	ods listing close;
	ods results off;
	PROC TABULATE DATA= %CMPRES(SUMMARY_SID_PID_&CAMP_ID.) MISSING OUT=NEW;
	CLASS TARGET CONTROL ;
	CLASS PROMO_CODE_ID  ;
	CLASS SOURCED_ASSOCIATION_ID ;
	VAR TXN_COUNT LCN POINTS VALUE;
	TABLE (TXN_COUNT LCN POINTS VALUE),PROMO_CODE_ID*SOURCED_ASSOCIATION_ID*TARGET*CONTROL;
	RUN;
	ods results on;
	ods listing;


	PROC SQL;
	TITLE " SOURCEWISE SUMMARY OF CAMPAIGN  : &camp_id. ";
	TITLE2 " &camp_id. - &PRT. ";
	SELECT 	  TXN_COUNT_Sum AS TXN_COUNT
			, LCN_Sum AS LCN
			, POINTS_Sum AS POINTS	
			, VALUE_Sum	AS VALUE format = 16.
			, PROMO_CODE_ID	
			, SOURCED_ASSOCIATION_ID
			, TARGET
			, CONTROL
		FROM NEW(DROP=_:)
	;
	RUN;
	ods listing;


	PROC SQL;
	Title "Unique First Arrival at &PRT.";
	TITLE2 " &camp_id. - &PRT. ";
	SELECT TARGET, CONTROL, OTHERS, COUNT(DISTINCT LOY_CARD_NUMBER) AS FIRST_SWIPE_COUNT
	FROM %CMPRES(camplib.UNQ_ACT_&camp_id._&PRT.)
	WHERE FIRST_CMPGN_SWIPE EQ 1
	GROUP BY TARGET, CONTROL, OTHERS ;
	QUIT;

	Title;

	/* CHECK FOR MC_CODE EXISTANCE */
	%IF %LENGTH(&MC_CODE.) > 0 %then %do;

	PROC SQL;
	TITLE " TARGET AND CONTROL SEGMENTATION WITH MC_CODE: &CAMP_ID. ";
	CREATE TABLE %cmpres(MC_SUMMARY_&CAMP_ID._&prt.) AS
	SELECT 		COUNT(ACTIVITY_ID) AS TXN_COUNT 
			,	COUNT(DISTINCT(LOY_CARD_NUMBER)) AS LCN
			, 	SUM(ALLOCATED_POINTS) AS POINTS format = 16.
			, 	SUM(ACTIVITY_VALUE) AS VALUE format = 16.
			, 	TARGET
			,	CONTROL
			,	DEP_CODE
			,	NL_FLG 
			,	SMS_FLG 
			,	SMS_CTRL
			,	NL_CTRL
			,	OTHERS
			
	FROM %cmpres(camplib.UNQ_ACT_&camp_id._&PRT.)

	group by  		TARGET
				,	CONTROL
				, 	DEP_CODE
				,	NL_FLG 
				,	SMS_FLG 
				,	SMS_CTRL
				,	NL_CTRL
				,	OTHERS;

	SELECT * FROM %cmpres(MC_SUMMARY_&CAMP_ID._&prt.);
	QUIT;
	%END;

	/* CHECK FOR FORMAT EXISTANCE */
	OPTIONS FMTSEARCH=(FORMATS CAMPLIB WORK LIBRARY);
	%IF %sysfunc(cexist(camplib.formats.CA_FMT.format)) %THEN %DO;
		%IF "&TXN_TYPE." = "EARN" %THEN %DO;
			DATA %cmpres(slab_&camp_id._&camp_id._&PRT.);
			SET %cmpres(camplib.UNQ_ACT_&camp_id._&PRT.);
			SLAB = PUT(ACTIVITY_VALUE, CA_FMT.);
			RUN;
			%PUT NUMERIC FORMAT EXISTS FOR EARN CAMPAIGN;
		%END;
		%ELSE %IF "&TXN_TYPE." = "BURN" %THEN %DO;
			DATA %cmpres(slab_&camp_id._&camp_id._&PRT.);
			SET %cmpres(camplib.UNQ_ACT_&camp_id._&PRT.);
			SLAB = PUT(NET_TOTAL_POINTS, CA_FMT.);
			RUN;
			%PUT NUMERIC FORMAT EXISTS FOR BURN CAMPAIGN;
		%END;
		PROC SQL;
			TITLE " TARGET AND CONTROL SLAB-SEGMENTATION : &camp_id. ";
			SELECT 		COUNT(ACTIVITY_ID) AS TXN_COUNT 
					,	COUNT(DISTINCT(LOY_CARD_NUMBER)) AS LCN
					, 	SUM(ALLOCATED_POINTS) AS POINTS
					, 	SUM(ACTIVITY_VALUE) AS VALUE format = 16.
					, 	TARGET
					,	CONTROL
					,	SLAB
					,	NL_FLG 
					,	SMS_FLG 
					,	SMS_CTRL
					,	NL_CTRL
					,	OTHERS
					
			FROM 	%cmpres(slab_&camp_id._&camp_id._&PRT.)
			group by 	TARGET
					,	CONTROL
					, 	SLAB
					,	NL_FLG 
					,	SMS_FLG 
					,	SMS_CTRL
					,	NL_CTRL
					,	OTHERS;

/*			SELECT * FROM %cmpres(slab_SUMMARY_&CAMP_ID._&prt.);*/
		QUIT;
	PROC CATALOG CATALOG=camplib.FORMATS;
		delete CA_FMT.format;
	RUN;

	%END;
	%ELSE %IF %sysfunc(cexist(camplib.formats.CA_FMT.formatc)) %THEN %DO;
		%IF "&TXN_TYPE." = "EARN" %THEN %DO;
			DATA %cmpres(slab_&camp_id._&camp_id._&PRT.);
			SET %cmpres(camplib.UNQ_ACT_&camp_id._&PRT.);
			SLAB = PUT(ACTIVITY_VALUE, CA_FMT.);
			RUN;
			%PUT NUMERIC FORMAT EXISTS FOR EARN CAMPAIGN;
		%END;
		%ELSE %IF "&TXN_TYPE." = "BURN" %THEN %DO;
			DATA %cmpres(slab_&camp_id._&camp_id._&PRT.);
			SET camplib.UNQ_ACT_&camp_id._&PRT.;
			SLAB = PUT(NET_TOTAL_POINTS, CA_FMT.);
			RUN;
			%PUT CHARACTER FORMAT EXISTS FOR BURN CAMPAIGN;
		%END;
		PROC SQL;
			TITLE " TARGET AND CONTROL SLAB-SEGMENTATION : &camp_id. ";
			SELECT 		COUNT(ACTIVITY_ID) AS TXN_COUNT 
					,	COUNT(DISTINCT(LOY_CARD_NUMBER)) AS LCN
					, 	SUM(ALLOCATED_POINTS) AS POINTS
					, 	SUM(ACTIVITY_VALUE) AS VALUE format = 16.
					, 	TARGET
					,	CONTROL
					,	SLAB
					,	NL_FLG 
					,	SMS_FLG 
					,	SMS_CTRL
					,	NL_CTRL
					,	OTHERS
					
			FROM 	%cmpres(slab_&camp_id._&camp_id._&PRT.)
			group by 	TARGET
					,	CONTROL
					, 	SLAB
					,	NL_FLG 
					,	SMS_FLG 
					,	SMS_CTRL
					,	NL_CTRL
					,	OTHERS;

/*			SELECT * FROM %cmpres(slab_SUMMARY_&CAMP_ID._&prt.);*/
		QUIT;

	PROC CATALOG CATALOG=camplib.FORMATS;
		delete CA_FMT.formatc;
	RUN;
	QUIT;

	%END;
	%ELSE %DO;
		%PUT FORMAT DOES NOT EXISTS; 
	%END;


	/* CHECK FOR LCM_FLAG VALUE EXISTANCE */
	PROC SQL noprint;
		SELECT COUNT(DISTINCT LCM_FLAG) INTO : CNT_L_FLAG FROM %cmpres(camplib.UNQ_ACT_&camp_id._&PRT.);
	QUIT;

	%IF &CNT_L_FLAG > 1 %THEN %DO;
			PROC SQL;
			TITLE " TARGET AND CONTROL SLAB-SEGMENTATION : &CAMP_ID. ";
			SELECT 		COUNT(ACTIVITY_ID) AS TXN_COUNT 
					,	COUNT(DISTINCT(LOY_CARD_NUMBER)) AS LCN
					, 	SUM(ALLOCATED_POINTS) AS POINTS
					, 	SUM(ACTIVITY_VALUE) AS VALUE FORMAT = 16.
					, 	TARGET
					,	CONTROL
					,	CASE 
							WHEN LCM_FLAG IS MISSING THEN  "NO_LCM_FLAG"
							ELSE LCM_FLAG
							END AS LCM_FLAG
					,	NL_FLG 
					,	SMS_FLG 
					,	SMS_CTRL
					,	NL_CTRL
					,	OTHERS

			FROM 	%CMPRES(CAMPLIB.UNQ_ACT_&CAMP_ID._&PRT.)
			GROUP BY 	TARGET
					,	CONTROL
					, 	LCM_FLAG
					,	NL_FLG 
					,	SMS_FLG 
					,	SMS_CTRL
					,	NL_CTRL
					,	OTHERS;
			QUIT;
	 %END;
	

	ods html close;

	/* CLEAN THE LIBERARIES*/
	proc sql;
		DROP INDEX LOY_CARD_NUMBER from %cmpres(CAMPLIB.BP_first_flag_&camp_id.);
		DROP INDEX MEMbER_ID from %cmpres(CAMPLIB.BP_first_flag_&CAMP_ID.);
	QUIT;


	PROC DATASETS LIB=CAMPLIB NOLIST;
	DELETE
			%CMPRES(CMPGN_text_DATA_&CAMP_ID.)
			%CMPRES(CMPGN_DATA_&Camp_id.)
			%CMPRES(CMP_DMP_EFFECTIVE_&CAMP_ID.)
			%CMPRES(TEST_&camp_id.)
			%CMPRES(BP_first_flag_&camp_id.)
			%CMPRES(BP_left_JOIN_&camp_id.)
			%CMPRES(CMP_SRC_FLG_&CAMP_ID.)
			%CMPRES(left_JOIN_2_&camp_id.)
		;
	QUIT;

	PROC DATASETS LIB=DWHLIB NOLIST;
	DELETE
		%CMPRES(cmpgn_card_mem_data_&camp_id.)
			;
	QUIT;
	

	/* print the loy_card_number with missing member_id */
	%if %sysfunc(exist(%CMPRES(missing_mem_id_&camp_id.))) %then %do;
		proc print data=%CMPRES(missing_mem_id_&camp_id.);
		Title "ALL MISSING MEMBER_ID";
		run;
		Title;
		footnote;
	%END;
	%END;
	%ELSE %DO;
		Data _null_;
			PUT @15 "/--------------------------------------------------------------------\" ;
			PUT @15 "|...DATASET :  %CMPRES(camplib.TEST_&camp_id.)  DOES NOT CONTAIN ANY OBSESRVATION...|" ;
			PUT @15 "\--------------------------------------------------------------------/" ;
		run;
	%END;
		%LET L = %EVAL(&L + 1);
	%END;
%END;
OPTIONS FMTSEARCH=(FORMATS);
%MEND Campaign_analysis;
