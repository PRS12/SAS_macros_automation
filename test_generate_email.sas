/************************************************************************************
*       Program      : Generate_email.sas											*
*		Owner        : Analytics, LSRPL                                 			*
*                                                                       			*
*       Author       : LSRL/324                                            			*
*                                                                       			*
*       Input        : TO= AND SUBJECT= are mandatory			        			*
*                      CC=, ATTACH=, BODY1= upto BODY7= 	are optional			*
*					   Can give multiple email ids in to= cc= separated by space	*
*					   Include in %str() if there are commas in the body1=, body2=,... *
*																					*
*		Eg:																			*
*																					*
-1)%generate_email(TO=abc@payback.net, SUBJECT= Bonus Points );   					*

-2)%generate_email(TO=abc@payback.net bcd@payback.net, SUBJECT= Bonus Points );   	*

-3)%generate_email(TO=abc@payback.net bcd@payback.net, SUBJECT= Bonus Points, 		
				   CC=cde@payback.net def@payback.net );   							*

-4)%generate_email(TO=abc@payback.net bcd@payback.net, SUBJECT= Bonus Points,		 
				   CC=cde@payback.net def@payback.net, ATTACH=G:\sas\bonus.xls,		
				   BODY1 = %str(Hi,), BODY2= Bonus points data has uploaded );		*
*																					*
*       Output       : Sends mail with given details                    			*
*                                                                       			*
*                                                                       			*
*       Dependencies : G:\sas\common\sasautos\Notifications_email_creds.sas			*
*                                                                       			*
*       Description  : Sends mail with the given details                			*
*																					*
*       Usage        :                                                  			*
*                                                                       			*
*                                                                       			*
*       History      :                                                  			*
*       (Analyst)     	(Date)    	(Changes)                               		*
*                                                                       			*
*        LSRL/324		01oct2012	Created                                         
*		 LSRL/324		31oct2012	Added 5 more statements in the body of the mail *
*									and can attach multiple files					*
************************************************************************************/



%macro Test_generate_email(to=, CC=a, subject=, Attach=a, body1=  ~ ,  body2 = ~  , body3=  ~ , body4 =  ~ , body5 = ~ , body6 = ~ , body7 = ~ , body8=  ~ ,  body9 = ~  , body10=  ~ , body11 =  ~ , body12 = ~ , body13 = ~ , body14 = ~);

%include "/sasdata/core_etl/prod/sas/sasautos/Notifications_email_creds.sas";

/*%from_mail();*/

	%macro multi(var=,varname=);

	%let cnt = %eval(%sysfunc(countc("&var.",' '))+1);

	%global &varname.;
	%let &varname. =  ;

	%do i = 1 %to &cnt.;
		%let mail_id = %cmpres(%str(%")%scan(&var.,&i.," ")%str(%"));
		%let &varname. = &&&varname. &mail_id.; 				
	%end;
	%put &&&varname.;

	%mend multi;

%multi(var=&to., varname=macto);

%put &macto.;

%if %length(%cmpres(&cc.)) > 1 and %length(%cmpres(&attach.)) > 1 %then
		%do;
			%multi(var=&cc., varname=macCC);
			%multi(var=&attach., varname=macATTACH);
			%put &macCC.;
			%put &macattach.;
			filename mail email to=(&macto.) cc= (&macCC.) subject="&subject." attach=(&macATTACH.) ; 
		%end;
%else
	 %if %length(%cmpres(&cc.)) > 1 %then
		%do; 
			%multi(var=&cc., varname=macCC);
			filename mail email to=(&macto.) cc= (&macCC.) subject="&subject."  ; 
		%end;
	%else
		%if %length(%cmpres(&attach.)) > 1 %then	
			%do; 
				%multi(var=&attach., varname=macATTACH);
				%put &macattach.;
				filename mail email to=(&macto.) attach=(&macATTACH.) subject="&subject."  ; 
			%end;
		%else
			%do;
				filename mail email to=(&macto.) subject="&subject." ; 
			%end;

data _null_;
	file mail;
	body1 = translate("&body1."," " ,"~");
	body2 = translate("&body2."," " ,"~");
	body3 = translate("&body3."," " ,"~");
	body4 = translate("&body4."," " ,"~");
	body5 = translate("&body5."," " ,"~");
	body6 = translate("&body6."," " ,"~");
	body7 = translate("&body7."," " ,"~");
	body8 = translate("&body8."," " ,"~");
	body9 = translate("&body9."," " ,"~");
	body10 = translate("&body10."," " ,"~");
	body11 = translate("&body11."," " ,"~");
	body12 = translate("&body12."," " ,"~");
	body13 = translate("&body13."," " ,"~");
	body14 = translate("&body14."," " ,"~");
    
	put #1 @2 body1;
	put #3 @7 body2;
	put #4 @7 body3;
	put #5 @7 body4;
	put #6 @7 body5;
	put #7 @7 body6;
	put #8 @7 body7;
	put #9 @7 body8;
	put #10 @7 body9;
	put #11 @7 body10;
	put #12 @7 body11;
	put #13 @7 body12;
	put #14 @7 body13;
	put #15 @7 body14;

	put "       ";	
	put "Best Regards,";
	put "Data Innovation & Delivery,";
	Put "Business Intelligence Unit,";
	put "Loyalty Solutions and Research Private Limited";
	put "PAYBACK INDIA";
run;
%mend;



