/************************************************************************
*       Program      : /sasdata/core_etl/prod/sas/sasautos/             *
*                                            partner_list_loop.sas      *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : lsrl/273                                         *
*                                                                       *
*       Input        : dwhlib.partner_list                              *
*                                                                       *
*                                                                       *
*                                                                       *
*       Output       : macro variables with:                            *
*                           <p_commercial_name>_plist                   *
*                                                                       *
*                                                                       *
*       Dependencies : /sasdata/core_etl/prod/sas/sasautos/init_env.sas *
*                                                                       *
*       Description  : Collects the list of partner_ids into a macro    *
*                      variable, 1 per partner based on p_commercial_name *
*                      as defined in DWHLIB.PARTNER_LIST.               *
*       Usage        : As is.                                           *
*                                                                       *
*                                                                       *
*                                                                       *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*      LSRL/273     21NOV2013   Created.                                *
*                                                                       *
************************************************************************/

%macro partner_list_loop;

OPTIONS NOMPRINT NOMLOGIC NOSYMBOLGEN;

DATA PARTNER_LIST;
	SET dwhlib.partner_list;
	if PARTNER_TYPE in ("AFFILIATE") THEN P_COMMERCIAL_NAME = "AFFILIATE";
	if PARTNER_TYPE in ("LIFESTYLE") THEN P_COMMERCIAL_NAME = "LIFESTYLE";
	IF partner_type = "MMT" then P_COMMERCIAL_NAME = "MMT";

	IF P_COMMERCIAL_NAME NOT IN ('ADGLOBAL360INDIAPRIVATELIMITED');
RUN;


proc sql noprint;
	select distinct p_commercial_name into: all_partners separated by "|" from partner_list 
	where 
		p_commercial_name not in ("OTHERRETAIL")
		and
		NOT anydigit(substr(strip(p_commercial_name),1,1)) 
	;
quit;

proc sql noprint;

	%let i=1;
	%do %while(%scan(&all_partners.,&i.,%str(|))~=%str());

			%let curr_partner=%scan(&all_partners.,&i.,%str(|));

			%GLOBAL %cmpres(&curr_partner._plist);

			select distinct partner_id into : %cmpres(&curr_partner._plist) separated by "," from partner_list where		
			strip(upcase(p_Commercial_name))=strip(upcase("&curr_partner."));
		%let i=%eval(&i.+1);		
	%end;
quit;

%mend partner_list_loop;
