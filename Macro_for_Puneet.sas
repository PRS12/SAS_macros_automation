%macro genrate_summary (DSN) / des="Puneet's Requested macro" ;
OPTIONS NOSYMBOLGEN NOMPRINT NOMLOGIC;

	/* Delete Old copy or reports */
	PROC DATASETS LIB=WORK NOLIST;
	DELETE Summary_REPORT: ;
	QUIT;

%if %sysfunc(EXIST(&dsn.)) %then %do;
	%put "dataset exists";
	DATA _NULL_;
		DSID = OPEN("&DSN.");
		NVARS = ATTRN(DSID,'NVARS');
		CALL SYMPUTX('NVARS',NVARS);
		DSID = CLOSE("&DSN");
	RUN;
	%PUT &NVARS;
	%LET I = 1;
	%DO %WHILE (&I <= &NVARS);
		DATA _NULL_;
		DSID = OPEN("&DSN.");
		IF UPCASE(VARTYPE(DSID,&I)) = "N" THEN DO;
			CALL SYMPUTX('PNAME',VARNAME(DSID,&I));
			DSID = CLOSE("&DSN");
		END;
		RUN;
		%IF %SYMEXIST(PNAME)  %THEN %DO;
			%PUT PNAME  = &PNAME. ;
			proc freq data=&DSN. NOPRINT;
	        table %upcase(&PNAME.) / list nocol nopercent out=%sysfunc(COMPRESS(&PNAME.)) (drop= percent rename=(&PNAME. = TXN_COUNT count=%upcase(&PNAME.)));
			PROC SORT DATA=%sysfunc(COMPRESS(&PNAME.)); BY TXN_COUNT; RUN;

		%if not (%SYMEXIST(first)) %then %do;
			data _null_;
			call symputx ('first',"&pname.");
			run;
		%end;
		%put first = &first.;

			%LET K = %EVAL(&I-1);
		%IF %SYSFUNC(EXIST(%cmpres(Summary_REPORT&K.))) %THEN %DO;
			DATA Summary_REPORT&I.;
			MERGE Summary_REPORT&K. &PNAME  ;
			BY Txn_Count;
			IF MISSING(&PNAME) THEN &PNAME. = 0;
			RUN;
		%END;
		%ELSE %DO;
			DATA Summary_REPORT&I.;
			MERGE &PNAME ;
			BY Txn_Count;
			IF MISSING(&PNAME) THEN &PNAME. = 0;
			RUN;
		%END;
		%END;
		%LET I = %EVAL(&I +1);
	%END;
	data final_summary;
		set &syslast.;
		ARRAY TOT{*} _NUMERIC_ ;
		TOTAL =0;
		DO j = 1 to dim(TOT);
			TOTAL = sum(TOTAL , TOT{j});
			if missing(tot{j}) then tot{j}=0;
		end;
		Total = total-Txn_count;
		drop j;
	run;

	proc print data=&syslast noobs;sum _all_;run;

	/* Delete Unwanted Datasets to save memory*/
	proc datasets lib=work NOLIST;
	save 
		%CMPRES(%QSCAN(&syslast.,-1,%STR(.)))
	%if %sysfunc(exist(%CMPRES(WORK.%QSCAN(&DSN.,-1,%STR(.))))) %THEN %DO;
	  	%CMPRES(%QSCAN(&DSN.,-1,%STR(.)))
	%END;
	;
	quit;
%END;
%else %do;
	%put "dataset does not exists";
%end;
%mend genrate_summary;



