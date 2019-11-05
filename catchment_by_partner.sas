/************************************************************************
*       Program      : G:\sas\common\utils\catchment_by_partner.sas     *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : LSRL\273 or AMR                                  *
*                                                                       *
*       Input        : PARAMETERS FROM DEFINITION                       *
*                                                                       *
*                                                                       *
*                                                                       *
*       Output       : TEMPLIB.MEMBERS_WITHIN_&THRESHOLD.               *
*                                                                       *
*                                                                       *
*                                                                       *
*       Dependencies :                                                  *
*                                                                       *
*       Description  : Captures list of members living within the       *
*                      specified distance of a list of pincodes.        *
*                                                                       *
*       Usage        :                                                  *
*	%catchment_by_partner(												*
*	catchment_dsn=whouse.CATCHMENT_DISTANCE_MASTER_cmpgn				*
*	, partner_ziplist=													*
*	, zipcol=zip														*
*	, cmpgn_dsn=%str(whouse.member_cmpgn_subset							*
*		(keep=															*
*			member_id 													*
*			member_zip 													*
*			member_account_number 										*
*			loy_card_number												*
*		))																*
*	, mem_zipcol=member_zip												*
*	, threshold=5														*
*	);																	*
*																		*
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
************************************************************************/

%macro catchment_by_partner(
	catchment_dsn=whouse.CATCHMENT_DISTANCE_MASTER_cmpgn
	, partner_ziplist=
	, zipcol=zip
	, cmpgn_dsn=%str(whouse.member_cmpgn_subset(keep=member_id member_zip member_account_number loy_card_number))	
	, mem_zipcol=member_zip
	, threshold=5
);

	%if %cmpres("&partner_ziplist.") = "" %then %do;
		%put ERROR: No partner zipcode list provided.;
		%put ERROR: Program aborting.;
		%abort RETURN;
	%end;

	data TEMP;
		if _n_ = 1 then do;
			declare hash parthash(dataset:"&PARTNER_ZIPLIST.");
			parthash.definekey("&zipcol.");
			parthash.definedone();
		end;

		SET &catchment_dsn.;
		where
			dist_in_kms <= &threshold.
		;

		&zipcol. = zip1;
		member_zip = zip2;
		distance_band = "<=&THRESHOLD.";

		if parthash.find() = 0;
		keep member_zip distance_band;
	run;

	data cmpgn_temp / view=CMPGN_TEMP;
		SET &cmpgn_dsn.;

		%if "&mem_zipcol." ~= "zip" %THEN %DO;
			zip = &mem_zipcol.;
			drop &mem_zipcol.;
		%end;
	run;

	data %cmpres(templib.members_within_&threshold.kms);

/*		format distance_band $5.;*/
	
		if _N_ = 1 then do;
			declare hash ziphash(dataset:"TEMP");
			ziphash.definekey("member_zip");
/*			ziphash.definedata("distance_band");*/
			ziphash.definedone();

		end;

		set cmpgn_temp (rename=(zip=member_zip));

		if ziphash.find() = 0;
	run;

%mend catchment_by_partner;

