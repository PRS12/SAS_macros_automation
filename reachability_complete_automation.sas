%macro check_n_import_files;

%LET remote_ip=10.200.1.7;
%LET passfile_loc=/home/PAYBACKSASPROD/etl_adm;
%LET user=BIU_ETL;
%LET source_loc=%str(/RECURRING_REQUIREMENT/OPS/REACHABILITY/INCOMING/CURED/);

	data _null_;
		remote_machine=translate("&remote_ip", '_','.');
		call symput("remote_machine", remote_machine);
	run;

	%put &remote_machine.;

	data _null_;
		infile "&passfile_loc./&user._&remote_machine..txt";
		format password $30.;
		input password $;
		call symput("password", strip(password));
	run;

	filename userid pipe 'whoami';

	data _null_;
		format userid $30.;
		infile userid;
		input userid $;
		call symput('userid', strip(userid));
	run;

	%put &userid;

	/* Authentication completed. Transfer of the files */

	filename SFTPCMD "/home/PAYBACKSASPROD/&userid./sftp_cmd_rch.sh";

	data _null_;
		file SFTPCMD;
		put "#!/bin/sh";
		put "lftp sftp://&user.:&password.@&remote_ip << EOF"; 
		put "cd &source_loc."; 
		put "ls";
	run;
	data _null_;
		call symput("sys_time", compress(scan("&systime.", 1, ":") || "_" || scan("&systime.", 2, ":")));
	run;

	%put Current Time: &sys_time;
	/* Secure the sftp script */
	systask command "cd /home/PAYBACKSASPROD/&userid.;.  ./sftp_cmd_rch.sh > /home/PAYBACKSASPROD/&userid./sftp_cmd_rch_&sys_time..log;" shell wait;
		systask command "chmod 700 /home/PAYBACKSASPROD/&userid./sftp_cmd_rch_&sys_time..log" wait;

data _null_;
	call symput("CURE_DATE", PUT(intnx("WEEK.3", "&RUNDATE."D, +0, "B"), date9.)); 
run;
%PUT  &CURE_DATE.;

			data check1;
			infile "/home/PAYBACKSASPROD/&userid./sftp_cmd_rch_&sys_time..log"  truncover;
			input var $500.;
			format size_mbl1 size_eml1 8.;
			if index(var,"&CURE_DATE.") > 0 then
					ind =1;
			else 
					ind = 0;
			curr_file = strip(scan(var,9,' '));
			if ind =1 ;
			if index(var,"obile") >0 then do;
			size_mbl1=strip(scan(var,5,' '));
			call symputx('mbl1',size_mbl1);
				end;
			if index(var,"mail") >0 then do;
			size_eml1=strip(scan(var,5,' '));
			call symputx('eml1',size_eml1);
				end;	
			run;

			%put &mbl1. &eml1;

					Data _null_;
					a =sleep(30,1);
					run;

			data check2;
			infile "/home/PAYBACKSASPROD/&userid./sftp_cmd_rch_&sys_time..log"  truncover;
			input var $500.;
			format size_mbl2 size_eml2 8.;
			if index(var,"&CURE_DATE.") > 0 then
					ind =1;
			else 
					ind = 0;
			curr_file = strip(scan(var,9,' '));
			if ind =1 ;
			if index(var,"obile") >0 then do;
			size_mbl2=strip(scan(var,5,' '));
			call symputx('mbl2',size_mbl2);
				end;
			if index(var,"mail") >0 then do;
			size_eml2=strip(scan(var,5,' '));
			call symputx('eml2',size_eml2);
				end;	
			run;

			%put &mbl2. &eml2;
	
			proc sort data=check1;
				by curr_file;
			run;
			proc sort data=check2;
				by curr_file;
			run;

	data check12;
	merge check1 check2;
	by curr_file;
	mbl_diff=size_mbl2 -size_mbl1;
	eml_diff=size_eml2 - size_eml1;
	if index(curr_file,"obile") >0 then do;
	call symputx('mbl_diff',mbl_diff);end;
	if index(curr_file,"mail") >0 then do;
	call symputx('eml_diff',eml_diff);end;
	run;
%put &mbl_diff &eml_diff;

%if %eval(&mbl_diff) = 0 and %eval(&eml_diff) = 0 

	%then %do;

 %send_mail(
	  to_list=%str('imran.anwar@payback.net' 'sunil.pinupolu@payback.net' )
	, cc_list=%str('anantharaman.mr@payback.net')
    , sub=%str(NOTE: Update of Reachability marts)
    , body=%str(Hi All,|Import step of reachability files for this week is in progress.|
                Please stop using reachability marts.|Marts are being updated.)
	);
			%include "/sasdata/core_etl/prod/sas/sasautos/SFTP_FILE_MOVE.sas" / source2;

			%SFTP_FILE_MOVE(
			     remote_ip=%str(10.200.1.7)
			     , user=%STR(BIU_ETL)
			     , passfile_loc=%str(/home/PAYBACKSASPROD/etl_adm)
			     , source_loc=%str(/RECURRING_REQUIREMENT/OPS/REACHABILITY/INCOMING/CURED)
			     , source_file=%str(reachable_mobile_&CURE_DATE..txt)
			     , target_loc=%str(/sasdata/core_etl/prod/incoming/operations/weekly/reachability)
			     , put_get=0
			     , overwrite=1
			     , notify=1
			     , notify_list=%str('imran.anwar@payback.net' 'anantharaman.mr@payback.net' 'sunil.pinupolu@payback.net')
			);


			%SFTP_FILE_MOVE(
			     remote_ip=%str(10.200.1.7)
			     , user=%STR(BIU_ETL)
			     , passfile_loc=%str(/home/PAYBACKSASPROD/etl_adm)
			     , source_loc=%str(/RECURRING_REQUIREMENT/OPS/REACHABILITY/INCOMING/CURED)
			     , source_file=%str(reachable_email_&CURE_DATE..txt)
			     , target_loc=%str(/sasdata/core_etl/prod/incoming/operations/weekly/reachability)
			     , put_get=0
			     , overwrite=1
			     , notify=1
			     , notify_list=%str('imran.anwar@payback.net' 'anantharaman.mr@payback.net' 'sunil.pinupolu@payback.net')
			);

			data TEMPLIB.reachable_email;
			infile "/sasdata/core_etl/prod/incoming/operations/weekly/reachability/reachable_email_&CURE_DATE..txt" firstobs=2 dlm="|";
			input email :$200. corrected_email_address :$200.;
			run;

			data TEMPLIB.reachable_Mobile;
			infile "/sasdata/core_etl/prod/incoming/operations/weekly/reachability/reachable_mobile_&CURE_DATE..txt" firstobs=2 dlm="|";
			input loy_card_number :$16. mobile_no :$10.;
			run;

%if %sysfunc(exist(TEMPLIB.reachable_email)) and %sysfunc(exist(TEMPLIB.reachable_Mobile)) %then %do;

 %send_mail(to_list=%str('sudhakar.srinias@payback.in' 'dharmendrasinh.chavda@payback.in'
			'Lakshmikanth.p@payback.net' 'Rajiv.Reddy@payback.net')
		, cc_list=%str('sumit.kumar@payback.net' 'anantharaman.mr@payback.net' 'Raghavendra.pawar@payback.net')
		, sub=%str(DONE: Cured Reachable Files Import Step Completed.)
		, body = %str(Hi All,|Process of Reachability update is started.|
		Please wait for the process to complete.)
	  );
  	%end;
			proc datasets lib=work;
			delete 
				check1
				check2
				check12;
			run;
			quit;

	%end;
	%else %do;

	 %send_mail(
	  to_list=%str('sudhakar.srinias@payback.in' 'dharmendrasinh.chavda@payback.in' )
	, cc_list=%str('anantharaman.mr@payback.net')
    , sub=%str(download and import of cured reachable files)
    , body=%str(Hi All,|reachability files for this week could not be imported.|
                Please check for the presence of files or format of files.)
	);
		%abort ;
	%end;
%mend check_n_import_files;

%check_n_import_files;

