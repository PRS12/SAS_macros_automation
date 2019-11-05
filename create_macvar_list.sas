/************************************************************************
*       Program      : summarize.sas                                    *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       :                                                  *
*                                                                       *
*       Input        :                                                  *
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
*                                                                       *
*                                                                       *
*                                                                       *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
************************************************************************/

%macro create_macvar_list(
	source=
	, target=
	, prefix=
	, suffix=
	, separator=%str(,)
	, quoted=
);

	%let counter=1;
	%do %while (%scan(%str(&source.), &counter., %str( )) ~= %str());

		%let temp=%scan(%str(&source.), &counter., %str( ));

		%if &counter.=1 %then %do;
			%IF %upcase(%cmpres("&quoted.")) = "Y" or %upcase(%cmpres("&quoted.")) = "YES" %then %do; 
				%let source_fmted=%cmpres("&prefix.&temp.&suffix.");
			%end;
			%else %do;
				%let source_fmted=%cmpres(&prefix.&temp.&suffix.);
			%end;
		%end;
		%else %do;
			%IF %upcase(%cmpres("&quoted.")) = "Y" or %upcase(%cmpres("&quoted.")) = "YES" %then %do; 
				%let source_fmted=%str(&source_fmted.&separator.%cmpres("&prefix.&temp.&suffix."));		
			%end;
			%else %do;
				%let source_fmted=%str(&source_fmted.&separator.%cmpres(&prefix.&temp.&suffix.));		
			%end;
		%end;

		%let counter=%eval(&counter.+1);

	%end;

	%let &target=&source_fmted.;

%mend create_macvar_list;
