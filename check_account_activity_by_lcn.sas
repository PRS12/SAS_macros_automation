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
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*                                                                       *
************************************************************************/

%macro check_account_activity_by_lcn(LCN=, start=, end=);

data test;
	format secondary_acc $16.;

	if _n_ = 1 then do;
		dcl hash agghash(DATASET:"supplib.agg_tree_with_points", multidata:"Y");
		agghash.definekey("FINAL_ACC");
		agghash.definedata("secondary_acc");	
		agghash.definedone();
	end;

	
	set whouse.member (keep=member_account_number agg_flag pagg_flag loy_card_number);
	where
		loy_card_number = strip("&lcn.")
	;

	if pagg_flag = 1 then do;
		final_acc = member_account_number;
		rc = agghash.find();
		if rc = 0 then do;
			output; /* outputs the first find */

			/* continues to look for more matches in the hash */
			do while(rc=0);
				rc = agghash.find_next();
				if rc = 0 then do; 
					output;
				end;
				else do; 
					continue; 
				end;
			end;
		end;
	end;
	else do;
		secondary_acc = member_account_number;
		output;
	end;
	drop rc;
run;

proc sql noprint;
	select distinct strip("'" || secondary_acc || "'") into: ACC_LIST SEPARATED BY "," from TEST;
quit;

%put account list = &acc_list.;
%put start=&start.;
%put end=&end.;

data discrepancy_&lcn.;
	set dwhlib.pb_trans_fact_master;
	where
		member_account_number in (&acc_list.)
		and
		"&start."D <= activity_date < ("&end."d + 1)
	;
run;

%mend check_account_activity_by_lcn;


