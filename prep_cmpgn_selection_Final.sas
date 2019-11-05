
options obs=max; /* errorabend ; */

%MACRO selection( 
				TYPE = NL /* or 'SMS'*/

				/* Campaign IDs. This process can accommodate upto 20 campaigns per cycle. Can be enhanced. */
				, C1_ID	= 0
              	, C2_ID	= 0
				, C3_ID	= 0
				, C4_ID	= 0
				, C5_ID	= 0
				, C6_ID	= 0
				, C7_ID	= 0
				, C8_ID	= 0
				, C9_ID	= 0
				, C10_ID= 0
				, C11_ID= 0
              	, C12_ID= 0
				, C13_ID= 0
				, C14_ID= 0
				, C15_ID= 0
				, C16_ID= 0
				, C17_ID= 0
				, C18_ID= 0
				, C19_ID= 0
				, C20_ID= 0

				/* DRF Selection criteria corresponding to every campaign */
				, FORMULA1=
				, FORMULA2=  
				, FORMULA3= 
				, FORMULA4= 
				, FORMULA5=  
				, FORMULA6= 
				, FORMULA7=  
				, FORMULA8=  
				, FORMULA9=  
				, FORMULA10=
				, FORMULA11=   
				, FORMULA12=  
				, FORMULA13= 
				, FORMULA14= 
				, FORMULA15=  
				, FORMULA16= 
				, FORMULA17=  
				, FORMULA18=  
				, FORMULA19=  
				, FORMULA20=
				/* Provide inputs to LIMIT the selection test data population */
				, LIMIT1=0
				, LIMIT2=0
				, LIMIT3=0
				, LIMIT4=0
				, LIMIT5=0
				, LIMIT6=0
				, LIMIT7=0
				, LIMIT8=0
				, LIMIT9=0
				, LIMIT10=0
				, LIMIT11=0
				, LIMIT12=0
				, LIMIT13=0
				, LIMIT14=0
				, LIMIT15=0
				, LIMIT16=0
				, LIMIT17=0
				, LIMIT18=0
				, LIMIT19=0
				, LIMIT20=0
				/* Other sources to lookup for any adhoc input for a given cycle */
				, ADD_DATA = 0 
/*				, actvity = 0 */
				, EXPORT=1
				, SAMPLE_MODE = 0 
				);
		
Data _null_ ;
	a = put(date(),yymmdd10.) ;
	call symput('DATUM',a) ;
run ; 

%LET date_today = %SUBSTR(&DATUM,9,2).%SUBSTR(&DATUM,6,2).%SUBSTR(&DATUM,1,4) ;
%LET date_table = %SUBSTR(&DATUM,1,4)%SUBSTR(&DATUM,6,2)%SUBSTR(&DATUM,9,2) ;

%PUT &date_today ;
%PUT &date_table ;

%LET JOIN = LOY_CARD_NUMBER ;
%LET MAIN_TABLE = WHOUSE.NL_POTENTIAL;

%IF &TYPE = SMS %THEN 
	%DO ; 
		%LET MAIN_TABLE = WHOUSE.SMS_POTENTIAL; 
	%END;

%IF &TYPE = NL   %THEN 
	%LET  ADDRESS = CORRECTED_EMAIL_ADDRESS ;

%IF &TYPE = SMS  %THEN 
	%LET  ADDRESS = CURED_MOBILE ;
 
 
data _null_;
a = today()  ;
if weekday(a) ge 4 then
	last_wed = put(intnx('days',a,-(weekday(a)-4)),date9.);
else
	last_wed = put(intnx('days',a,-(weekday(a)+3)),date9.);
format a date9. ;
put a last_Wed;
call symput('m_last_wed',last_wed);
run;

%put &m_last_wed;

/* ------------- Initial or later run check ------------- */
proc sql;
select count(*) into :chk from sashelp.vtable 
where memname = upcase("&type._SELECTION") and libname="TEMPLIB" and datepart(crdate) ge "&m_last_wed"d
and nobs>50;
quit;
 
%if  &chk = 0 %then
		/*		Initial Run in that week 	*/
		%do;
			DATA SELECTION(drop=burn_points_: earn_points_: no_trx_3m_: no_trx_6m_: sales_3m_: sales_6m_:);
			SET WHOUSE.&type._POTENTIAL;

				campaign_1 = 0;
				campaign_2 = 0;
			 
				%DO I = 1 %TO 20; 
					%if %length(&&FORMULA&I.) > 0 %then 
						%do;
							if campaign_1 = 0   and (   &&FORMULA&I.  ) then do; 
												campaign_1 = &&c&i._id.; 
												Priority_1 = &i; 
							end;
							else if campaign_2 = 0   and (   &&FORMULA&I.  ) then do; 
												campaign_2 = &&c&i._id.; 
												Priority_2 = &i; 
								 end;
						%end;
				%END;
			run;


			data selection1;
				retain tmp ;
				set selection(where=(campaign_1 > 0 or campaign_2 > 0));
				by &address.;
				if first.&address. then
					do;
							tmp 	 = 1;
							campaign = campaign_1;
							priority = priority_1;
							output;

						if campaign_2 > 0 then 
						do;
							campaign = campaign_2;
							tmp		 = tmp +1;
							priority = priority_2;
							output;	
						end;
					end;
				else
					do;
							campaign = campaign_1;
							tmp		 = tmp + 1 ;
							priority = priority_1;
							output;	

							priority = priority_2;
							campaign = campaign_2;
							output;
						end;					
			run;

			proc sort 	data=selection1(where=(campaign>0 ) ) 
						out=selection2 nodupkey;
				by &address. priority;
			run;

			data Templib.&type._selection;
				set selection2;
					by &address.;
				if first.&address. then cnt = 1;
				else cnt+1;
				if cnt le 2;
			run;

		%end;
%else
	%if %sysfunc(exist(templib.&type._SELECTION)) %then
		%do;
			/*	Not Initial run in that week*/
			proc sql;
			create table selection as
				select 
					a.*,
					b.campaign_1,
					b.campaign_2,
					b.priority_1,
					b.priority_2

				from whouse.&type._potential a left join templib.&type._selection b on
				a.loy_card_number = b.loy_card_number;
			quit;

			/* Assing campaing ids based on the given condition */

			Data selection(drop=burn_points_: earn_points_: no_trx_3m_: no_trx_6m_: sales_3m_: sales_6m_:);
				set selection;
				%DO I = 1 %TO 20; 
						%if %length(&&FORMULA&I.) > 0 %then 
							%do;
								if campaign_1 = 0   and (   &&FORMULA&I.  ) then do; 
													campaign_1 = &&c&i._id.; 
													Priority_1 = &i; 
								end;
								else if campaign_2 = 0   and (   &&FORMULA&I.  ) then do; 
													campaign_2 = &&c&i._id.; 
													Priority_2 = &i; 
								end;
							%end;

				%END;
			run;

		    proc sort data=selection;
			by &address.;
			run;

			/* Taking top 2 priority campaigns for Mobile/Email */
			data selection1;
				retain tmp ;
				set selection(where=(campaign_1 > 0 or campaign_2 > 0));
				by &address.;
				if first.&address. then
					do;
							tmp 	 = 1;
							campaign = campaign_1;
							priority = priority_1;
							output;

						if campaign_2 > 0 then 
						do;
							campaign = campaign_2;
							tmp		 = tmp +1;
							priority = priority_2;
							output;	
						end;
					end;
				else
					do;
							campaign = campaign_1;
							tmp		 = tmp + 1 ;
							priority = priority_1;
							output;	

							priority = priority_2;
							campaign = campaign_2;
							output;
						end;					
			run;

			proc sort 	data=selection1(where=(campaign>0 ) ) 
						out=selection2 nodupkey;
				by &address. priority;
			run;

			data Templib.&type._selection_2;
				set selection2;
					by &address.;
				if first.&address. then cnt = 1;
				else cnt+1;
				if cnt le 2;
			run;
		%end;
	%else
		%do; %put ------------  TEMPLIB.&TYPE._selection dataset doesnot exist  ------------ ; %end;
		

	

/* -------- Spliting into diffrent campaigns data -------- */	
data %do i = 1 %to 20;
			%if %length(&&FORMULA&I.) > 0 %then
				&type._&&c&i._id._selection;
	 %end;
	 ;
	set Templib.&TYPE._selection_2;
	%do i = 1 %to 20;
	%if %length(&&FORMULA&I.) > 0 %then
		%do;
			if campaign = &&c&i._id.  then
					output &type._&&c&i._id._selection;
		%end;
	%end;
run;

%do i = 1 %to 20;
			%if %length(&&FORMULA&I.) > 0 %then
			%do;
				proc sort data=&type._&&c&i._id._selection;
					by &ADDRESS. precedence descending net_total_points;
				run;

				proc sort data=&type._&&c&i._id._selection out=&type._&&c&i._id._selection_data nodupkey;
					by &ADDRESS.;
				run;

										/* --- Spliting into Ctrl and test datasets --- */

					proc sql;
					select nobs into :tot_cnt from sashelp.vtable where libname = "WORK" and memname = upcase("&type._&&c&i._id._selection_data");
					quit;

					%let cntl_cnt = %sysfunc(round(%sysevalf(&tot_cnt * 0.10)));

					proc surveyselect data=&type._&&c&i._id._selection_data (keep=LOY_CARD_NUMBER) method=srs N=&cntl_cnt. 
						out=&type._&&c&i._id._SELECTION_CTRL;
					run;

					data &type._&&c&i._id._SELECTION_FINAL;
						IF _N_ = 1 then 
						do;
							declare hash ctlhash(dataset:"&type._&&c&i._id._SELECTION_CTRL");
							ctlhash.definekey("LOY_CARD_NUMBER");
							ctlhash.definedone();
						end;
						
					set &type._&&c&i._id._selection_data;
					
					rc = ctlhash.find();

					controlgroup = 0;
					if rc = 0 then controlgroup = 1;
					drop rc;
					run;

					proc export data=&type._&&c&i._id._SELECTION_FINAL(WHERE = (controlgroup = 0) KEEP= &JOIN NET_TOTAL_POINTS &ADDRESS DOB  controlgroup)
					outfile="g:\sas\common\output\&type._&&c&i._id._SELECTION_testdata.TXT"
					dbms=dlm replace;
					delimiter='|';
					run;

					proc export data=&type._&&c&i._id._SELECTION_FINAL(WHERE = (controlgroup = 1) KEEP= &JOIN NET_TOTAL_POINTS &ADDRESS DOB  controlgroup)
					outfile="g:\sas\common\output\&type._&&c&i._id._SELECTION_CTLDATA.TXT"
					dbms=dlm replace;
					delimiter='|';
					run;

			%end;
%end;

proc sort data=templib.SMS_selection  NODUPKEY;
by CURED_MOBILE loy_card_number;
run;

%mend;
