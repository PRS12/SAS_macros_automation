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

%macro summarize (
	classlist=
	, nway=
	, types=
	, ways=
	, varlist=
	, sumvarlist=
	, nuniquevarlist=
);

%global classlist_fmted;
%global varlist_fmted;
%global sumvarlist_fmted;
%global nuniquevarlist_fmted;

data _null_;
	
	if _n_ = 1 then do;

	end;

run;

%mend summarize;
