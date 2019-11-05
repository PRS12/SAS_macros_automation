/************************************************************************
*       Program      : prep_member_association_vector.sas               *
*                                                                       *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : LSRL-273                                         *
*                                                                       *
*       Input        : DWHLIB.DIM_MEMBER_ASSOCIATION                    *
*                                                                       *
*                                                                       *
*                                                                       *
*       Output       : SUPPLIB.MEMBER_ASSOCIATION_LKP                   *
*                                                                       *
*                                                                       *
*                                                                       *
*       Dependencies : DWH updates                                      *
*                                                                       *
*       Description  : Prepares a record level view of all              *
*                      prevailing associations in the DWH area for a    *
*                      any member.                                      *
*       Usage        : As is.                                           *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
************************************************************************/

options mprint mlogic symbolgen obs=max;

proc sort data = dwhlib.dim_member_association out=dim_member_association;
	where is_deleted <=0 and is_disabled <=0;
	by member_id association_id unique_id2 member_association_id;
run;

proc sql noprint;
	select count(association_id) into: num_of_assocs from dim_member_association group by member_id;
quit;

%put max associations per member = &num_of_assocs.;

data supplib.member_association_lkp;

	format assoc_key_1-%cmpres(assoc_key_&num_of_assocs.) $15.;

	array assocs (&num_of_assocs.) assoc_1-%cmpres(assoc_&num_of_assocs.);
	array assoc_keys (&num_of_assocs.) $ assoc_key_1-%cmpres(assoc_key_&num_of_assocs.);
	array mem_assoc_ids (&num_of_assocs.) mem_assoc_id1-%cmpres(mem_assoc_id&num_of_assocs.);

	retain assoc_count;
	retain assoc_1-%cmpres(assoc_&num_of_assocs.);
	retain assoc_key_1-%cmpres(assoc_key_&num_of_assocs.);
	retain mem_assoc_id1-%cmpres(mem_assoc_id&num_of_assocs.);

	set dim_member_association;
		by member_id association_id unique_id2 member_association_id
	;

	if first.member_id then do;
		assoc_count = 1;
		do i = 1 to &num_of_assocs.;
			assocs(i) = .;
			assoc_keys(i) = '';
			mem_assoc_ids(i) = .;
		end;
	end;
	else if assoc_count < &num_of_assocs. then assoc_count = sum(assoc_count, 1);

	assocs(assoc_count) = association_id;
	assoc_keys(assoc_count) = unique_id2;
	mem_assoc_ids(assoc_count) = member_association_id;

	if last.member_id;
	
	keep
		member_id
		assoc_1-%cmpres(assoc_&num_of_assocs.)
		assoc_key_1-%cmpres(assoc_key_&num_of_assocs.)
		mem_assoc_id1-%cmpres(mem_assoc_id&num_of_assocs.)
	;
run;
		
