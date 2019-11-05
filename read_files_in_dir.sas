options mprint mlogic symbolgen;

%macro read_files_in_dir(filepath=);
                
filename indata pipe %nrquote("dir ""&filepath."" /b") ; 

data kip;
  infile indata truncover ;
  input f2r $100.;
run;

proc datasets library=templib nolist;
	delete	
		camp_dump
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

                        data temp(keep=loy_card_number source);
                             infile currfile lrecl=1000 firstobs = 2;
                             input;
                             format column $16.;
                             format source $200.;
                             column=strip(_infile_);
                             source=upcase("&filepath.\&curr_file.");
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

                        proc append base=templib.Camp_Dump data = temp force;
                        run;


/*                   filename currfile close;*/

                     %let i = %eval(&i.+1);

                %end;

%mend read_files_in_dir;



