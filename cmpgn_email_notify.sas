%macro cmpgn_email_notify(msgtype=);

	%let SCH_PRE_CMPGN_READ_MSG=%nrstr(Schedule to read Campaign input data files. Find below the summary);

	%if %SYSFUNC(CMPRES(UPCASE("&msgtype."))="CMPGN_INPUT" %then %do;
		%collect_ops_extract_info(dsn=emaildsn /* Output dataset */);
	
		filename notify email 
			TO=&EMLDATA_TEAM.
			CC=&SASADM.
			SUBJ="Campaign Input run summary, Status=SUCCESS"
		;
	
		data _null_;
			set emaildsn;
			file notify;
			put "Filetype"
				"Period"
				"Recs in FF"
				"Recs in SAS DS"
				"Logged_DTTM"
			;
			put filetype Period INRECS OUTRECS Logged_DTTM;
		run;
	%end;
	%else %if %SYSFUNC(CMPRES(UPCASE("&msgtype."))="CMPGN_INPUT" %then %do;
		filename notify email 
			TO=&EMLDATA_TEAM.
			CC=&SASADM.
			SUBJ="ERROR: Campaign Input process, Status: Unsuccessful"
		;
		data _null_;
			set emaildsn;
			file notify;
			put "Campaign input process ended abruptly.";
			put "Please refer to the logs or contact &EMLDATA_TEAM.";
			put "NOTE: Please do not reply to this email.";
		end;
	%end;		

%mend cmpgn_email_notify;
