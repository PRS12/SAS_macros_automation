/************************************************************************
*       Program      :                                                  *
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
*       History      :  11-July-2012                                    *
*       (Analyst)     (Date)    (Changes)                               *
*	 				                                *
*                                                                       *
************************************************************************/

%macro gen_excl_lst_by_dep_dt
(
	dep_dt=
	, channel=
	, limit=2
	, test_data=
)
;

	options obs=max;

	%if %upcase("&CHANNEL.") = "EML" %then %do;
		%let var=corrected_email_address;
	%end;
	%else %if %upcase("&CHANNEL.") = "SMS" %then %do;
		%let var=cured_mobile;
	%end;

	%let start_dt="&dep_dt."d;
	%let end_dt=intnx("DAY", "&dep_dt."D, 7); 

	proc summary data = SUPPLIB.DRF_&channel. nway;
		where
			&start_dt. <= dep_date 	< &end_dt.
			and
			upcase(strip(MAILING_LIST)) = "T"
		;
		
		class
			&VAR.
		;
		OUTPUT out = drf_&channel. (where=(count >= &limit.) RENAME=(_FREQ_ = count) keep=&VAR. _freq_)
		;
	quit;			


	DATA &test_data._final;		
		if _n_ = 1 then do;
			declare hash remhash(hashexp: 16, dataset:"drf_&channel.");
			%if %upcase("&CHANNEL.") = "EML" %then %do;
				remhash.definekey("corrected_email_address");
			%end;
			%else %if %upcase("&CHANNEL.") = "SMS" %then %do;
				remhash.definekey("cured_mobile");
			%end;
			remhash.definedone();
		end;
	
		set &test_data.;

		rc = REMHASH.FIND();

		IF RC ~= 0;
		DROP RC;
	run;


%mend gen_excl_lst_by_dep_dt;



