options mprint mlogic symbolgen minoperator;

%macro read_cmpgn_files_dev (filepath=, outdsn=);
       
filename indata pipe %nrquote("dir ""&filepath."" /b"); 

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

	/*
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

	*/
               data temp;

					format 
						source $200.
						LOY_CARD_NUMBER $20.
						net_total_points best12. 
					;

                    infile currfile lrecl=1000 firstobs = 2 dsd dlm="&delimit.";

					input
					;

					source = strip("&filepath.\&curr_file.");

                    camp_no = input(scan("&curr_file.", 1, '_'), 8.);

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
					;					
               run;

               proc append base=%CMPRES(&OUTDSN.) data = temp force;
               run;

             %let i = %eval(&i.+1);
%end;

%mend read_cmpgn_files_dev;


