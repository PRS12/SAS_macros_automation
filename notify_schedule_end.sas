
%macro notify_schedule_end(schedule=);
	%include "/sasdata/core_etl/prod/sas/sasautos/send_mail.sas";
	%include "/sasdata/core_etl/prod/sas/sasautos/check_sas_log.sas";

	%let logloc=%sysget(LOGDIR);

	%check_sas_log(log_location=%str(&logloc.));

	%if &nobs. <= 0 %then %do;

	%send_mail(
		to_list=%str('mudit.kulshreshtha@payback.net' 'ankush.talwar@payback.net' 'raghavendra.pawar@payback.net' 'sudhakar.srinivas@payback.in' 'dharmendrasinh.chavda@payback.in')
		, cc_list=%str('amit.sharma1@payback.in' 'hemant.kamal@payback.net')
		, sub=%str(DONE: Ending schedule: &schedule successfully.)
		, body=%str(Ending the schedule: &schedule..|The logs for the run are attached for review. | Thank you, |Core ETL team,|PB-Analytics.)
		, attachment=%str("&logloc./pmodulesrun_log.xml")
	);

	%end;
	%else %do;

		FILENAME tmpmsg "/home/PAYBACKSASPROD/etl_adm/tmpmsg.log";

		proc printto print=tmpmsg;
		run;

		proc print data=checklog noobs;
		run;

		proc printto;
		run;

		%send_mail(
		to_list=%str('sudhakar.srinias@payback.in' 'dharmendrasinh.chavda@payback.in')
		, cc_list=%str('amit.sharma1@payback.in' )
		, sub=%str(ERROR: Ending schedule: &schedule with errors.)
		, body=%str(Ending the schedule : &schedule with errors. | Refer to tmpmsg.log for details.  | Thank you, |Core ETL team,|PB-Analytics.)
		, attachment=%str("&logloc./pmodulesrun_log.xml" "/home/PAYBACKSASPROD/etl_adm/tmpmsg.log")
		);

		systask command "rm -f /home/PAYBACKSASPROD/etl_adm/tmpmsg.log" nowait shell;


	%end;

%mend notify_schedule_end;
