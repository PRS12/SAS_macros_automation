/************************************************************************
*       Program      : /sasdata/core_etl/prod/sas/sasautos/GetPartnerID.sas *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Anantha Raman M.R. (LSRL-273)                    *
*                                                                       *
*       Input        : DWHLIB.PARTNER_LIST                              *
*                                                                       *
*                                                                       *
*                                                                       *
*       Output       : Macro variable: Partner_ID_List                  *
*                                                                       *
*                                                                       *
*                                                                       *
*       Dependencies : DWHLIB.PARTNER_LIST                              *
*                                                                       *
*       Description  : This macro is intended to collate all partner_id *
*                      pertaining to a given business selection of      *
*                      partner and/or partner_type.                     *
*       Usage        :                                                  *
*                                                                       *
*                                                                       *
*                                                                       *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*       LSRL-273 26SEP2013     Created.                                 *
*                                                                       *
************************************************************************/

%macro GetPartnerID(partner=,partner_type=);
	%global partner_ID_list;
	proc sql noprint;
		select 
			distinct partner_id into: partner_id_list separated by "," 
		from
			dwhlib.partner_list
		where
			%if &partner.~=%str() or &partner_type.~=%str() %then %do;
				%if &partner.~=%str() %then %do;
					p_commercial_name in (&partner.)
				%end;
				%if &partner.~=%str() and &partner_type.~=%str() %then %do;
					and
				%end;
				%if &partner_type.~=%str() %then %do;
					partner_type in (&partner_type.)
				%end;
			%end;
		;
	quit;


%mend GetPartnerID;
