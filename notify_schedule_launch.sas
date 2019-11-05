%macro notify_schedule_launch(schedule=);

%include "/sasdata/core_etl/prod/sas/sasautos/send_mail.sas";

%let logloc=%sysget(LOGDIR);

%put Log directory for this session: &logloc.;

%send_mail(
	to_list=%str('mudit.kulshreshtha@payback.net' 'ankush.talwar@payback.net' 'raghavendra.pawar@payback.net' 'sudhakar.srinias@payback.in' 'dharmendrasinh.chavda@payback.in' )
	, cc_list=%str('amit.sharma@payback.in' 'hemant.kamal@payback.net')
	, sub=%str(Launching schedule: &schedule.)
	, body=%str(Launching schedule: &schedule. please find the logs at &logloc.)
	, attachment=
);

%mend notify_schedule_launch;

