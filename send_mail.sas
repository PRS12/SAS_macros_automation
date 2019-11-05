/************************************************************************************
*       Program      : Generate_email.sas											*
*		Owner        : Analytics, LSRPL                                 			*
*                                                                       			*
*       Author       : core_tel/PAYBACK                                   			*
*                                                                       			*
*       Input        : TO= AND SUBJECT= are mandatory			        			*
*                      CC=, ATTACH=, BODY=write the body of email where each line   *
*					   is separated by | as a delimiter 							*
*																					*
*		Eg:																			*
*																					*
*-1)%send_email(TO=abc@payback.net, SUBJECT= Bonus Points );   						*
*																					*
*-2)%send_email(TO=abc@payback.net bcd@payback.net, SUBJECT= Bonus Points );   		*
*																					*	
*-3)%send_email(TO=abc@payback.net bcd@payback.net, SUBJECT= Bonus Points, 			*
*				   CC=cde@payback.net def@payback.net );   							*
*																					*
*-4)%send_email(TO=abc@payback.net bcd@payback.net, SUBJECT= Bonus Points,		 	*
*				   CC=cde@payback.net def@payback.net, ATTACH=G:\sas\bonus.xls,		*	
*				   BODY1 = %str(Hi All,| Data for the specific report is			*
*					placed at path:|enter the path of the data |					*
*					Many Thanks.);													*
*       Output       : Sends mail with given details                    			*
*                                                                       			*
*                                                                       			*
* Dependencies : /sasdata/core_etl/prod/sas/sasautos/Notifications_email_creds.sas	*
*                                                                       			*
* Description  : Sends mail with the given details                					*
*																					*
* Usage        : used to automated the processes with email notification			*
*                                                                       			*
*                                                                       			*
* History      :                                                  					*
* (Analyst)     	(Date)    	(Changes)                               			*
*                                                        							*
************************************************************************************/


%macro send_mail(
	to_list=
	, cc_list=
	, sub=
	, attachment=
	, body=
);

%include "/sasdata/core_etl/prod/sas/sasautos/Notifications_email_creds.sas" /source2;

filename mailfile email 
	%if %str(&to_list.) ~= %str() %then %do;
		to=(&to_list.) 
	%end;

	%if %str(&cc_list.) ~= %str() %then %do;
		cc=(&cc_list.)
	%end;

	%if %str(&attachment.) ~= %str() %then %do;
		attach=(&attachment.) 
	%end;
	subject="&sub."
; 

%put &body.;

data _null_;
	file mailfile; 
	format message_line $100.; 

		%let cnt = %eval(%length(&body.) - %length(%sysfunc(compress(&body.,|))) +1);
		%put --------------- &cnt.;

		%do z = 1 %to &cnt.;
			%let line=%scan(&body.,&z.,%str(|));
			message_line="&line.";
			%if &z.=1 %then %do;
				put message_line;
				put;
			%end;
			%else %do;
				put @15 message_line;
			%end;
			put;
		%end;  
	put ;
	put ;
	put "Data Innovation & Delivery,";
	Put "Business Intelligence Unit,";
	put "Loyalty Solutions and Research Private Limited";
run;
%mend send_mail;
