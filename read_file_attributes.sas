/***********************************************************************\
*       Program      : G:\sas\common\sasautos\read_file_attributes.SAS  *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Vikas Sinha				                        *
*                                                                       *
*       Output       : It gives out the property of a file or directory *
*                                                                       *
*       Dependencies : NONE                                             *
*                                                                       *
*       Description  : READ_FILE_ATTRIBUTES							    *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
\***********************************************************************/

%macro read_file_attributes(directory);
%local dir_rc file_rc;
	proc format ;
		picture kbfmt 
			low - high = "0000000009.99 kb";
		picture bytfmt
			low - high = "0000000009.99 Bytes";
	run;

/*Check if Directory Exists*/
%let rc = %sysfunc(filename(chkdir,&directory.));
	%if %sysfunc(dopen(&chkdir.)) %then %do;
		filename read pipe "dir ""&directory."" /b";
		 data temp_file;
		  infile read lrecl=10000;
		  input @;
		  var_file = _infile_;
		  chk_file_ext=  scan(var_file,-1,"/");
		  if find(chk_file_ext,".","i") then file_ext=chk_file_ext;
		  if missing(file_ext) then delete;
		  drop file_ext chk_file_ext;
		run;
		%let dir_rc = 1;
	 %end;
	 %else %do;
		%put direcoty does not exists;

/*Check if file Exists*/
		%if %sysfunc(fexist(&chkdir.)) %then %do;
			data temp_file;
				var_file = "&directory.";
			run;
			%let file_rc = 1;
		%end;

	 %end;

/*Read the attributes only if either directry or file exists*/
%if &dir_rc = 1 or &file_rc = 1 %then %do;

		data dir_file_attbr;
		  set temp_file;

		  %if &dir_rc. = 1 %then %do;
			source = "&directory."||"/"||var_file;
		  %end;
		  %else %if &file_rc. = 1 %then %do;
		  	source = "&directory.";
		  %end;
			fname = filename('currfile',"'"||source||"'");
				fid = fopen('currfile');
				fsize_bytes = input(finfo(fid,'file size (bytes)'),16.2);
				fsize_kb = divide(input(fsize_bytes,12.),1024);
				f_cr_date = finfo(fid,'create time');
				f_mo_date = finfo(fid,'Last Modified');
				fcid = fclose(fid);
			file_create_date = input(f_cr_date,datetime19.);
			file_mod_date = input(f_mo_date,datetime19.);
			format file_create_date file_mod_date datetime19. fsize_bytes bytfmt. fsize_kb kbfmt.;
		 drop f_cr_date f_mo_date fcid fid fname ;
		run ;

	proc datasets lib=work nolist nowarn;
	delete 
			temp_file;
	run;
	quit;
%end;
%else %do;
	%put Given path is invalild.;
%end;
%mend read_file_attributes;


option nomlogic nomprint nosymbolgen;
%read_file_attributes(put the unquoted file or dir location);


