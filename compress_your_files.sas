/************************************************************************
*       Program      :   compress_your_files.sas                         *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       :    LSRL-C006                                     *
*                                                                       *
*       Input        : OUTPUT FILES                       				*
*                                                     					*
*                                                                       *
*                                                                       *
*       Output       : ZIPPED FILE                     					*
*                                      									*
*                                                                       *
*                                                                       *
*       Dependencies :   None                                           *
*                                                                       *
*       Description  :                                                  *
*                                                                       *
*                                                                       *
*       Usage        :  To Zip Files                                    *
*                                                                       *
*                                                                       *
*                                                                       *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
*                                                                       *
*                                                                       *
************************************************************************/

options mprint mlogic symbolgen;

%macro compress_your_files/parmbuff;
%put Syspbuff contains: &syspbuff;
%local loc extn j Source destination;
%let j = 1;
%do %while (%qscan(&syspbuff,&j,%str(",")) ne %str());
     %if %eval(&j) eq 1 %then %do;
           %let loc = %substr(%qscan(&syspbuff.,&j,%str(,)),2);
           %put &loc.;
     %end;
     %let j = %eval(&j + 1);
     %if %eval(&j) eq 2 %then %do;
           %let destination = %qscan(&syspbuff,&j,%str(,));
           %put &destination.;
     %end;
     %let j = %eval(&j + 1);
     %if %eval(&j) eq 3 %then %do;
           %let zip_name = %qscan(&syspbuff,&j,%str(,));
           %put &zip_name.;
     %end;
     %let j = %eval(&j + 1);
     %if %eval(&j) eq 4 %then %do;
           %let extn = %substr(%qscan(&syspbuff,&j,%str(,)),1,%length(%qscan(&syspbuff,&j,%str(,)))-1);
           %put &extn.;
     %end;
     %let j = %eval(&j + 1);
%end;
%put &loc. &extn.;

filename filelist pipe "dir ""&loc""/b";
data read;
     infile filelist truncover lrecl=1000;
     input @;
     files = _infile_;
run;

proc sql noprint;
     select distinct files into :filelist separated by "|"
     from read
     %if %length(&extn.) gt 0 %then %do;
           where scan(files,-1,".") = "&extn.";
     %end;
quit;
%put &filelist.;
%put &loc.;

%let list = %superq(filelist);
%put &list.;

     ods package(ProdOutput) open nopf;
     %let i = 1;
     %do %while (%qscan(&list,&i,%str(|)) ne %str());
        %let curfile = %qscan(&list,&i,%str(|)) ;
           ods package(ProdOutput) 
     add file=%str("&loc.\&curfile.");
        %let i = %eval(&i +1);
     %end;

     ods package(ProdOutput) publish archive properties 
           (archive_name= "&zip_name..zip" archive_path="&destination.");
ods package(ProdOutput) close;

filename filelist clear;

%mend compress_your_files;

/*%zip_files (source_location, destination ,zip_name,<file_Extension>);*/
