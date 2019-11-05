/************************************************************************
*       Program      :                                                  *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       :                                                  *
*                                                                       *
*       Input        :                                                  *
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
*       LSRL-273		10AUG2012	Added NET_TOTAL_POINTS to selection *
*                               data collation (C0001)                  *
*		    		 :15AUG2012 (VIKAS)	ADDED  							*
*								user.campaignattribute.Net_Points 		*
*								TO THE SELECCTION						*
*								AND MADE CAMP_NO A CHARACHTER VARIABLE	*
*					 :03Sep12 (Vikas) Add lcm_flag						* 
************************************************************************/
options Nomprint Nomlogic Nosymbolgen minoperator;

%macro read_cmpgn_files (filepath=, camp_id=, outdsn=);
       
filename indata pipe %nrquote("dir ""&filepath."" /b") ; 

data kip;
infile indata truncover ;
input f2r $100.;
run;

proc datasets library=%scan(&outdsn.,1,%str(.)) nolist;
delete     
   %scan(&outdsn.,2,%str(.))
;
delete
   campaign_base
;
quit;

filename indata clear ;

proc sql noprint;
        select f2r into: file_list separated by "|" from kip;
quit;

%let i = 1;
%let ARG=%superq(file_list);

%do %while(%qscan(&arg,&i,%str(|)) ~= %str());
               
               %let curr_file=%qscan(&arg,&i,%str(|));

               filename currfile %nrquote("&filepath.\&curr_file.");

                   %if %INDEX(%UPCASE(&curr_file.), CSV) > 0 %then %do;
                        %let delimit=%STR(,);
                   %END;
                   %else %do;
                        %let delimit=%STR(|);
                   %end;
                   /* C0001: Check for existence of NET_TOTAL_POINTS in the header */
                   data _null_;
                    infile currfile lrecl=1000 firstobs = 1 obs=1;
                             input;
                             i = 1;
                             do while(scan(_infile_, i , "&delimit.") ~= "");
                                  FIELD_READ = scan(_infile_, i, "&delimit.","M");
                                  if INDEX(upcase(strip(field_read)), 'NET_TOTAL_POINTS') then do;
                                        CALL SYMPUTX('net_total_points_pos', i);
                                       leave;
                                  end;
                                  ELSE if INDEX(upcase(strip(field_read)), 'USER.CAMPAIGNATTRIBUTE.NET_POINTS') then do;
                                        CALL SYMPUTX('net_total_points_pos', i);
                                       leave;
                                  end;
                                   else DO;
                                        CALL SYMPUTX('net_total_points_pos', 0);
                                   END;
                                  i = i + 1;
                              end;
             run;

					%put position of net_total_points column => &net_total_points_pos.;

                   /* C0001: Check for existence of LCM_FLAG in the header */
                   data _null_;
                    infile currfile lrecl=1000 firstobs = 1 obs=1 dsd dlm="&delimit.";
                             input;
                             i = 1;
                             do while(scan(_infile_, i , "&delimit.") ~= "");
                                  FIELD_READ = scan(_infile_, i, "&delimit.","M");
                                  if index(upcase(strip(field_read)), 'LCM_FLAG') then do;
                                        CALL SYMPUTX('LCM', i);
                                       leave;
                                  end;
                                  ELSE if index(upcase(strip(field_read)), 'MEMBER_STATUS') then do;
                                        CALL SYMPUTX('LCM', i);
                                        leave;
                                  end;
                                   ELSE do;
                                        CALL SYMPUTX('LCM', 0);
                                   END;
                                  i = i + 1;
                              end;
             run;

                   %put position of LCM_FLAG column => &LCM.;

               data temp;
/*(keep=loy_card_number source camp_no net_total_points LCM_FLAG);*/
                    infile currfile lrecl=1000 firstobs = 2 dsd dlm="&delimit.";
					format column $16. source $200. LCM_FLAG $25. LOY_CARD_NUMBER $20.;
                    input;
                    column=strip(_infile_);
                    source=upcase("&filepath.\&curr_file.");
                            camp_no = %CMPRES("&camp_id.");

                             /* C0001: Capture the NET_TOTAL_POINTS in the data files when available */

                             %if %cmpres(&net_total_points_pos.) > 0 %then %do;
                                   net_total_points = input(scan(_infile_, &net_total_points_pos., "&delimit.","M"), best12.);
                             %end;
                             %else %do;
                                   net_total_points = . ;
                             %end;

                             %if &LCM. > 0 %then %do;
                                   LCM_FLAG = scan(_infile_, &LCM., "&delimit.","M");
                             %end;
                             %else %do;
                                   LCM_FLAG = '';
                             %end;

                        i = 1;
                        do while(scan(_infile_, i , "&delimit.") ~= "");
                             FIELD_READ = scan(_infile_, i, "&delimit.");
                            if substr(field_read, 1, 1) = "9" and length(field_read) = 16 then do;
                                 LOY_CARD_NUMBER = FIELD_READ;
                                 output;
                                 leave;
                            end;
                            i = i + 1;
                        end;
               run;

               proc append base=%CMPRES(&OUTDSN.) data = temp force;
               run;
             %let i = %eval(&i.+1);
%end;
%mend read_cmpgn_files;
