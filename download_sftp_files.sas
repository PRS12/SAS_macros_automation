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
*						to the local hard drive.						*                												    *
*                                                                       *
*       Usage        : Download Files from Sftp to Local Drives         *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
\***********************************************************************/

%MACRO download_sftp_files(sftppath=%str()
				,destination=%str()
				,user=%str()
				,pswd=%str()
				,host=%STR()
			 );


/*Setting SFTP Connection to Download Files*/

	Filename sftpcom "F:\bin\&sysuserid._sftp.txt";
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

	Filename sftpbat "F:\bin\sftp.bat";
	data _null_;
	file sftpbat;
	Put "F:\temp_SASsoftware\WinSCP\winscp.com /script=F:\bin\&sysuserid._sftp.txt -log=F:\bin\logg\temp_sftp_log.txt";
	run;

	Filename invok pipe "F:\bin\sftp.bat";
	DATA _NULL_;
	infile invok;
	input;
	put _infile_;
	run;
	
%MEND Download_Sftp_Files;
/**/
/*%download_sftp_files(sftppath=%str(/REPORTING/hometown_SEG3.txt)*/
/*				,destination=%str(G:\REPORTING\)*/
/*				,user=%str(r.pawar)*/
/*				,pswd=%str(Bitty50LIBRa23sELl&)*/
/*				,host=%STR(10.200.1.7)*/
/*			 );*/
