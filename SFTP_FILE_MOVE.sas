/************************************************************************
*       Program      :                                                  *
*             /sasdata/core_etl/prod/sas/sasautos/SFTP_FILE_MOVE.sas    *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : LSRL-273                                         *
*                                                                       *
*       Input        : remote_ip: Remote machine to which file(s) need  * 
*                      to be posted.                                    *
*                                                                       *
*                      user: The user ID to be used for logging on to   *
*                                                                       *
*                      passfile_loc: The location of the file containing*
*                      the password for the user stated above.          *
*                                                                       *
*                         password file: Location of the password file  *
*                         "&passfile_loc./&user._&remote_machine..txt"  *
*                         where remote_machine is defined by replacing  *
*                         dots in remote_ip.                            *
*                                                                       *
*                      source_loc: The location of the file(s) to be    *
*                                  transferred.                         *
*                                                                       *
*                      source_file: The file to be transferred. If      *
*                                   source_file is empty then all files *
*                                   are transferred.                    *
*                                                                       *
*                      target_loc: The location in the remote machine   *
*                                  to which file(s) need to be          *
*                                  transferred.                         *
*                                                                       *
*                      compress: Zip the file(s) before transfer.       *
*                                                                       *
*                      notify: Notify the sender through email, the     *
*                              details of the transfer.                 *
*                                                                       *
*                                                                       *
*                                                                       *
*       Output       :                                                  *
*                                                                       *
*                                                                       *
*                                                                       *
*       Dependencies :                                                  *
*                                                                       *
*       Description  :                                                  *
*                                                                       *
*                                                                       *
*       Usage        :                                                  *
*                %sftp_file_move_dev(                                   *  
*	remote_ip=%str(10.200.1.7)                                    *    
*	, user=%STR(BIU_ETL)                                          *
*	, passfile_loc=%str(/home/PAYBACKSASPROD/etl_adm)             *
*	, source_loc=%str(/home/PAYBACKSASPROD/etl_adm)               *
*	, source_file=%str(sqlnet.log)                                *
*	, target_loc=%str(/REPORTING/TEST)                            *
*	, put_get=1                                                   *
*	, overwrite=1                                                 *
*	, notify=1                                                    * 
*         );                                                            *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*       LSRL-273    05NOV2013   Added time stamp to the log creation step *
*                               (C0001)                                 *
*       LSRL-273    14NOV2013   Added transfer of the file from server  *
*                               back to this machine,explicit overwrite *
*                               option and email notification. (C0002)  * 	
************************************************************************/

%include "/sasdata/core_etl/prod/sas/sasautos/send_mail.sas" / source2;

%MACRO sftp_file_move(
	remote_ip=
	, user=
	, passfile_loc=
	, source_loc=
	, source_file=
	, target_loc=
	/* C0002 */
	, put_get=1
	, overwrite=1
	, compress=
	, notify=
	, notify_list=
);

	options 
		nomprint 
		nomlogic 
		nosymbolgen
	;


	/* Authentication step */

	data _null_;
		remote_machine=translate("&remote_ip", '_','.');
		call symput("remote_machine", remote_machine);
	run;

	%put &remote_machine.;
	%put &user.;

	
	%if &user. ^= BIU_ETL and &user. ^= ETL_ADM and &user. ^= DI_ADM %then
	%do;

			data _null_;
				infile "&passfile_loc./&user._&remote_machine..txt";
				format password $30.;
				input password $;
				call symput("password", strip(password));
			run;
	%end;
	filename userid pipe 'whoami';

	data _null_;
		format userid $30.;
		infile userid;
		input userid $;
		call symput('userid', strip(userid));
	run;

	%put &userid;

	/* Authentication completed. Transfer of the files */

	filename SFTPCMD "/home/PAYBACKSASPROD/&userid./sftp_cmd.sh";

	

	data _null_;
		file SFTPCMD;
		put "#!/bin/sh";
	
	%if &user. ^= BIU_ETL and &user. ^= ETL_ADM and &user. ^= DI_ADM %then
	%do;	

			put "lftp sftp://&user.:&password.@&remote_ip << EOF"; 

	%end;
	%if &user. = BIU_ETL or &user. = ETL_ADM or &user. = DI_ADM %then 
	%do;

			put "sftp &user.@&remote_ip << EOF"; 

	%end;	
	/* C0002 */
	%if &overwrite ~= 1 %then %do; 
		put "set xfer:clobber off";
	%end;

	/* C0002 */
	%if &put_get.=1 %then %do;
		put "lcd &source_loc."; 
		put "cd &target_loc.";
	%end;
	%else %do;
		put "cd &source_loc."; 
		put "lcd &target_loc.";
	%end;

	/* C0002 */
	%if &put_get.=1 %then %do;
		put "mput &source_file."; 
		put "ls";
	%end;
	%else %do;
		put "mget &source_file."; 
	%end;
		put "bye"; 
	run;
	
	/* Secure the sftp script */
	systask command "chmod 700 /home/PAYBACKSASPROD/&userid./sftp_cmd.sh" wait;

	/* C0001 */
	data _null_;
		call symput("sys_time", compress(scan("&systime.", 1, ":") || "_" || scan("&systime.", 2, ":")));
	run;

	%put Current Time: &sys_time;

	/* C0002 */
	%if &put_get=1 %then %do;
		/* Execute the sftp script */
		systask command "cd /home/PAYBACKSASPROD/&userid.;./sftp_cmd.sh > /home/PAYBACKSASPROD/&userid./sftp_cmd_&remote_machine._&sysdate9._&sys_time..log;" shell wait;
		/* C0001 ends */
	
		/* Secure the log of the sftp execution */
		systask command "chmod 700 /home/PAYBACKSASPROD/&userid./sftp_cmd_&remote_machine._&sysdate9._&sys_time..log" wait;
	%end;
	%else %do;
		systask command "cd /home/PAYBACKSASPROD/&userid.;./sftp_cmd.sh" wait shell;	

		/* Listing of the target directory to see if the file has arrived or not. */
		systask command "ls -rlt &target_loc./&source_file. > /home/PAYBACKSASPROD/&userid./sftp_cmd_&remote_machine._&sysdate9._&sys_time..log;" shell wait;
	%end;

	/* Remove the sftp script */
	systask command "rm -f /home/PAYBACKSASPROD/&userid./sftp_cmd.sh" wait;

	/* C0002: Notify user(s) if notify option is set to 1 */
	%if &notify.=1 %then %do;
		%if &put_get.=1 %then %do;
			%send_mail(
				to_list=&notify_list.
				, sub=%str(SFTP file transfer process report)
				, body=%str(PFA the report attached for transfer of file(s) from:|&source_loc./&source_file. to &target_loc.|Please note that this was a PUT operation| Thanks, BIU.)
				, attachment=%str("/home/PAYBACKSASPROD/&userid./sftp_cmd_&remote_machine._&sysdate9._&sys_time..log")
			);
		%end;
		%else %do;
			%send_mail(
				to_list=&notify_list.
				, sub=%str(SFTP file transfer process report)
				, body=%str(PFA the report attached for transfer of file(s) from:|&source_loc./&source_file. to &target_loc.|Please note that this was a GET operation| Thanks, BIU.)
				, attachment=%str("/home/PAYBACKSASPROD/&userid./sftp_cmd_&remote_machine._&sysdate9._&sys_time..log")
			);
		%end;
	%end;
	
%MEND sftp_file_move;
