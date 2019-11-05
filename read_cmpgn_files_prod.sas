	* options NOmprint NOmlogic NOsymbolgen minoperator;

%macro read_cmpgn_files_PROD (filepath=, outdsn=);
       
filename indata pipe %nrquote("dir ""&filepath."" /b") ; 

data kip;
infile indata truncover ;
input f2r $100.;
run;

/* Clear any pre-processed file */
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
							 pos_ntp=0;
							 pos_df=0;
							 pos_lcm=0;

                             do while(scan(_infile_, i , "&delimit.", "M") ~= "");
                                  FIELD_READ = scan(_infile_, i, "&delimit.","M");
                                  if INDEX(upcase(strip(field_read)), 'NET_TOTAL_POINTS') then do;
								  	POS_ntp=i;
                                  end;
                                  ELSE if INDEX(upcase(strip(field_read)), 'USER.CAMPAIGNATTRIBUTE.NET_POINTS') then do;
									pos_ntp = i;
                                  end;
					  ELSE IF INDEX(upcase(strip(field_read)), 'DATA_FLAG') then do;
								  	pos_df=i;
					end;

					ELSE IF INDEX(upcase(strip(field_read)), 'LCM_FLAG') then do;
								  	 pos_lcm=i;
					  end;
				   				   
                                  i = i + 1;
                              end;

					          CALL SYMPUTX('net_total_points_pos', pos_ntp);
					          CALL SYMPUTX('DATA_FLAG_POS', pos_DF);
						 CALL SYMPUTX('LCM_FLAG_POS', pos_lcm);
             		run;

					%put position of net_total_points column => &net_total_points_pos.;
					%put position of DATA_FLAG column => &DATA_FLAG_POS.;
					%put position of LCM_FLAG_POS column => &LCM_FLAG_POS.;

               data temp;

					format 
						source $200.
						LOY_CARD_NUMBER $20.
						net_total_points best12.
						DATA_FLAG $5. 
					;

                    infile currfile lrecl=1000 firstobs = 2 dsd dlm="&delimit.";

					input
					;
					source = strip("&filepath.\&curr_file.");

                    camp_no = input(scan("&curr_file.", 1, '_'), 8.);

                    if %cmpres(&net_total_points_pos.) > 0 then do;
                          net_total_points = input(scan(_infile_, &net_total_points_pos., "&delimit.", "M"), best12.);
                    end;

                    if %cmpres(&data_flag_pos.) > 0 then do;
                          DATA_FLAG = scan(_infile_, &DATA_FLAG_POS., "&delimit.", "M");
                    end;
			
			if %cmpres(&LCM_FLAG_POS.) > 0 then do;
                          LCM_FLAG = scan(_infile_, &LCM_FLAG_POS., "&delimit.", "M");
                    end;


                    i = 1;
                    do while(scan(_infile_, i , "&delimit.", "M") ~= "");
                       FIELD_READ = scan(_infile_, i, "&delimit.", "M");
                       if substr(field_read, 1, 1) = "9" and length(field_read) = 16 then do;
                          LOY_CARD_NUMBER = FIELD_READ;
                          output;
                          leave;
                       end;
                       i = i + 1;
                    end;


					keep 
						loy_card_number 
						source
						camp_no 
						net_total_points 
						Data_flag
						LCM_FLAG
					;					
               run;

               proc append base=%CMPRES(&OUTDSN.) data = temp force;
               run;

             %let i = %eval(&i.+1);
%end;

%mend read_cmpgn_files_PROD;


