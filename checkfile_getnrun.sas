
/***********************************************************************\
*       Program      : Download_Sftp_Files.sas			                *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Imran Anwar(Emp.No. 334)                         *
*                                                                       *
*       Input        :                              					*
*                                                                       *
*       Output       :                                                  *
*                                                                       *
*       Dependencies : SFTP software installed on server                *
*                                                                       *
*       Description  : Macro to download files from sftp loaction		*
*						to the local hard drive after checking and   	*                												    *
*                       trigger process.                                *
*       Usage        : Download Files from Sftp to Local Drives         *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
\***********************************************************************/

%MACRO checkfile_getnrun(
				sftppath=%str()
				,destination=%str()
				,user=%str()
				,pswd=%str()
				,host=%STR()
				,fpr_email=()
			 );

Data _null_;
a = "&sftppath.";
b = "&destination.";
call symputx('sftppath',a); 
call symputx('destination',b);
run;


%include 'g:\sas\common\sasautos\Notifications_email_creds.sas';

options mlogic mprint symbolgen;

/*get the name of the file to be moved to local directory*/
%local loc ;
%local project;
%let loc = %sysfunc(translate(%quote(%sysfunc(translate(%quote(%str(&sftppath)),'','"'))),'',"'"));
%put loc = &loc;
%let loc= %sysfunc(compress(%quote(%str(&sftppath)),"'"));
%put &loc.;


%let eml_list=&fpr_email.;
%let file = %qscan(%upcase(&loc.,-1,"/"));
%let dir = %substr(&loc.,1,%eval(%length(&loc.)-%length(&file.)-1));
%let project = %qscan(%upcase(&loc.,-2,"/."));


%put requested_file = &file.;
%put &dir.;
%put &project.;



/*Check for the usage of requried file at SFTP locaiton*/
Filename sftpcom "F:\bin\&sysuserid.check_&file._on_sftp.txt";
data _null_;
     file sftpcom;
     put "open sftp://&user.:&pswd.@&host.";
     put "cd &dir.";
     put "dir ";
     stop;
run;

%global file_existency;

%let fileexist = 0;
%let cntr = 0;

%do %while(&fileexist ne 1 and &cntr le 6);

	%let cntr = %eval(&cntr + 1);

	Filename sftpbat "F:\bin\check_&file._sftp.bat";
	 data _null_;
	     file sftpbat;
	     Put "F:\temp_SASsoftware\WinSCP\winscp.com /script=F:\bin\&sysuserid.check_&file._on_sftp.txt -log=F:\bin\logg\check_file_&file._on_sftp.txt";
	 run;

	Filename invok pipe "F:\bin\check_&file._sftp.bat";
	 DATA _NULL_;
		 infile invok;
		 input ;
		 put _infile_;
	 run;

	 DATA sample_invok;
		 infile "F:\bin\logg\check_file_&file._on_sftp.txt" lrecl=10000 truncover;
		 input file_names $ 1000.;
		 if not find(file_names,'users','i') then delete;
		 file_names = upcase(scan(file_names, -1," "));
	 run;


	 data test_invok;
	 set sample_invok;
	 where file_names="&file.";
		 
		 if (strip(file_names)) = "&file" then 
			do;
				call symputx ('fileexist', 1,'l');
				call symputx ('file_existency',1);
			end;
		else do;
				call symputx ('fileexist', 0,'l');
				call symputx ('file_existency',0);
		end;
		run;

	 data _null_;
	 	systask command "del /Q ""F:\bin\logg\check_file_&file._on_sftp.txt""";
	 run;

	%if &fileexist ne 1 %then %do;
	
		 %if &cntr. =1  %then %do;
		
		
	filename sendmail email 
			to = &eml_list.
			subject= "ERROR: FILE for Preparation of &file. not found"
			;

	data _null_;
		file sendmail;
		
		put #2 @3 "Hi All,";
		put #4 @5 "File for the process to run is not available on the sftp location &sftppath..";
		put #6 @5 "Please put the file in the respective folder within two minutes and notify.";
		PUT #8 @2 "Thanks,";
		PUT #9 @2 "Data Innovation & Delivery,";
		PUT #10 @2 "Business Intelligence Unit,";
		PUT #11 @2 "PAYBACK INDIA";

	%end;
		 %if &cntr. le 3 %then %do;
			data _null_;
				call sleep(60,1);	
			run;
		%end;
		%else %if (&cntr. gt 3 and &cntr. lt 6) %then %do;
			data _null_;
				call sleep(120,1);	
			run;	
		%end;
	%end;
%end;

/*Setting SFTP Connection to Download Files*/

%if &fileexist = 1 %then %do;

	Filename sftpcom "F:\bin\&sysuserid.get_&file._from_sftp.txt";
	data _null_;
	file sftpcom;
	put "open sftp://&user.:&pswd.@&host.";
	put "pwd";
	put "dir";
	put "bin";
	put "option confirm off";
	put "get ""&sftpPATH"" ""&destination"" ";
	put "CLOSE";
	put "exit";
	put "exit";
	stop;
	run;

	Filename sftpbat "F:\bin\get_&file._sftp.bat";
	data _null_;
	file sftpbat;
	Put "F:\temp_SASsoftware\WinSCP\winscp.com /script=F:\bin\&sysuserid.get_&file._from_sftp.txt -log=F:\bin\logg\get_&file._from_sftp.txt";
	run;

	Filename invok pipe "F:\bin\get_&file._sftp.bat";
	DATA _NULL_;
	infile invok;
	input;
	put _infile_;
	run;

	 data _null_;
	 	systask command "del /Q ""F:\bin\logg\get_&file._from_sftp.txt""";
		systask command "del /Q ""F:\bin\check_&file._sftp.bat""";
		systask command "del /Q ""F:\bin\&sysuserid.check_&file._on_sftp.txt""";
	 run;


	 %include "G:\sas\common\sasautos\Notifications_email_creds.sas";
	filename sendmail email 
			to = &eml_list.
			subject= "Preparation of &file."
			;

data _null_;
		file sendmail;
		
		put #2 @3 "Hi All,";
		put #4 @5 "Process of Recurring Adhoc for INPUT FILE &project. has started";
		put #6 @5 "Please wait for the process to complete.";
		PUT #8 @2 "Thanks,";
		PUT #9 @2 "Data Innovation & Delivery,";
		PUT #10 @2 "Business Intelligence Unit,";
		PUT #11 @2 "PAYBACK INDIA";
run;
%end;	
%else %do;
	

filename sendmail email 
			to = &eml_list.
			subject= "ERROR: FILE for Preparation of &file. not found"
			;

data _null_;
		file sendmail;
		
		put #2 @3 "Hi All,";
		put #4 @5 "File for the process to run is not available on the specified sftp location &sftppath..";
		put #6 @5 "Process to generate report &file. could not be completed due to unavailability of input file.";
		PUT #8 @2 "Thanks,";
		PUT #9 @2 "Data Innovation & Delivery,";
		PUT #10 @2 "Business Intelligence Unit,";
		PUT #11 @2 "PAYBACK INDIA";
		
run;

%end;
%MEND checkfile_getnrun;
