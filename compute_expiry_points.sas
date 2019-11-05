/***********************************************************************\
*       Program      : PRG_ADHOC_COMPUTE_EXPIRY_POINTS.SAS              *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : Anantha Raman (LSRL-273)                         *
*                                                                       *
*       Input        : DWHLIB.DET_ACTIVITY                              *
*                                                                       *
*       Output       : WHOUSE.EXPIRY_POINTS_&DATE_CUTOFF.               *
*                                                                       *
*       Dependencies : NONE                                             *
*                                                                       *
*       Description  : Adhoc utility program to compute expiry points   *
*                      for based on a supplied cutoff date in (DATE9.   *
*                      format, e.g. 30APR2012).                         *
*                                                                       *
*       Usage        : %compute_expiry_points(EXPIRY_CUTOFF=31DEC2012); *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*                                                                       *
*       LSRL-273	22-FEB-2012	Created.                        		*
*       LSRL-273	29-MAR-2012	Code Fix. Removed reversals and    		*
*                               invalid transactions (C0001)            *
*                                                                       *
\***********************************************************************/

%macro compute_expiry_points(DATE=);

data _null_;
	
	CALL SYMPUT("date_cutoff", put(intnx("YEAR", "&DATE."d, -3, "S"), ddmmyyn8.));
run;

PROC DATASETS LIBRARY = DWHLIB NOLIST;
	DELETE
		member_expiry_points
	;
QUIT;


proc sql noprint;
	CONNECT TO ORACLE AS DWH (USER=dwh PASSWORD=manager PATH='DWHFO' preserve_comments buffsize=10000);

    EXECUTE (
   	create table member_expiry_points as
	select DISTINCT SUM(NVL(EARN_BURN_RESIDUE,ALLOCATED_POINTS)) AS POINTS_TO_EXPIRE ,to_char(member_account_number) as member_account_number
	
	from DET_ACTIVITY
	WHERE ACTIVITY_DATE <= %cmpres(to_date(%NRBQUOTE('&date_cutoff.'), 'ddmmyyyy'))
	and activity_action_id in (1,5)
	/* Backing out invalid and reversals (C0001) */
	and record_processed = 1 
	and activity_id not in 
	(
		select distinct referenced_activity_id from det_activity_link
	)
	group by member_account_number
   	) by dwh;
quit;

data %cmpres(WHOUSE.expiry_points_&SYSDATE.);
	SET dwhlib.MEMBER_EXPIRY_POINTS;
	EXPIRY_CUT_OFF_DT = "&date_cutoff.";
run;

proc sql noprint;
   connect to oracle as dwh (USER=dwh PASSWORD=manager PATH='DWHFO' preserve_comments buffsize=10000); 
   EXECUTE( 
   	DROP TABLE MEMBER_EXPIRY_POINTS
	) BY DWH;
quit; 


%mend compute_expiry_points;


/*%mend compute_expiry_points;*/

