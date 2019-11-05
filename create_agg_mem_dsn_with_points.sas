%macro create_agg_mem_dsn_with_points;

%set_rpt_env;

proc sql noprint;
   connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
   EXECUTE(
			CREATE TABLE TREE_CN1 AS 
    		SELECT DISTINCT TO_CHAR(MEMBER_ACCOUNT_NEW) AS SECONDARY_ACC, TO_CHAR(MEMBER_ACCOUNT_NEW) AS FINAL_ACC, 1 AS LEVELNO
			FROM 
				MAP_ACC_AGGREGATION 
			WHERE 
				MEMBER_ACCOUNT_NEW NOT IN (SELECT MEMBER_ACCOUNT_OLD FROM MAP_ACC_AGGREGATION)
	) BY DWH; 


	EXECUTE (
		CREATE TABLE TREE_CN2 AS 
	 	SELECT CONNECT_BY_ROOT TO_CHAR(AG.MEMBER_ACCOUNT_OLD) AS SECONDARY_ACC
	             , TO_CHAR(AG.MEMBER_ACCOUNT_NEW) AS FINAL_ACC
				 , LEVEL AS LEVELNO 
	     FROM MAP_ACC_AGGREGATION AG
		CONNECT BY NOCYCLE PRIOR AG.MEMBER_ACCOUNT_NEW = AG.MEMBER_ACCOUNT_OLD
		AND LEVEL <= 15
		ORDER BY AG.AGGREGATION_ID
	) BY DWH;
	DISCONNECT FROM DWH;
QUIT;

DATA AGG_MEM_TREE;
	set DWHLIB.TREE_CN1 DWHLIB.TREE_CN2;
RUN;

proc sql noprint;
   connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
   EXECUTE(
   DROP TABLE TREE_CN1
	) BY DWH; 
	EXECUTE (
	DROP TABLE TREE_CN2	
	) BY DWH;
	DISCONNECT FROM DWH;
   %IF %sysfunc(exist(DWHLIB.AGG_MEM_TREE))  %THEN %DO;
   EXECUTE (
		drop table agg_mem_tree
	) by dwh;
   %END;
QUIT;

data DWHLIB.AGG_MEM_TREE;
	SET agg_mem_tree;
run;

proc sql noprint;
   connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
   %IF %sysfunc(exist(DWHLIB.AGG_TREE_WITH_POINTS))  %THEN %DO;
   EXECUTE (
		drop table agg_tree_with_points
	) by dwh;
   %END;

   EXECUTE (
   create table agg_tree_with_points as
   select a.*
			, b.EARN_ACTION_POINTS
			, b.BURN_REV_ACTION_POINTS
			, b.PREALL_EARN_ACTION_POINTS
			, b.BURN_ACTION_POINTS
			, b.EARN_REV_ACTION_POINTS
			, b.PREALL_BURN_ACTION_POINTS
			, b.POINTS_UNDER_PROCESS
	FROM 
		agg_mem_tree A
		, DIM_MEMBER B
	WHERE
		A.SECONDARY_ACC=TO_CHAR(B.MEMBER_ACCOUNT_NUMBER)
	) BY DWH;
   disconnect from dwh;
quit;

DATA SUPPLIB.AGG_TREE_WITH_POINTS (rename=(member_account_number=secondary_acc));
	
	format points_to_expire best12.;

	IF _N_ = 1 THEN DO;
		declare hash myhash(hashexp: 16, dataset:"WHOUSE.Expiry_points");
		myhash.definekey("MEMBER_ACCOUNT_NUMBER");
		myhash.definedata("POINTS_TO_EXPIRE");
		myhash.definedone();
	END;
	SET dwhlib.agg_tree_with_points (rename=(secondary_acc=MEMBER_ACCOUNT_NUMBER));

	rc = myhash.find();

	drop RC;
run;

proc sql noprint;
   connect to oracle as dwh ( user = dwh password = manager path = 'DWHFO' preserve_comments buffsize=10000); 
   EXECUTE (
		drop table agg_tree_with_points
	) by dwh;
   EXECUTE (
		drop table agg_mem_tree
	) by dwh;
	disconnect from dwh;
quit;

proc sort data = SUPPLIB.AGG_TREE_WITH_POINTS OUT = TEMP(keep=levelno FINAL_ACC secondary_acc);
	by secondary_acc descending levelno;
run;

PROC SORT DATA = temp nodupkey;
	by secondary_acc;
run;

proc sort data = temp nodupkey;
	by final_acc;
run;

proc summary data = supplib.agg_tree_with_points nway;
	class
		FINAL_ACC
	;
	var
		EARN_ACTION_POINTS
		BURN_REV_ACTION_POINTS
		PREALL_EARN_ACTION_POINTS
		BURN_ACTION_POINTS
		EARN_REV_ACTION_POINTS
		PREALL_BURN_ACTION_POINTS
		POINTS_UNDER_PROCESS
		POINTS_TO_EXPIRE
	;

	output out = AGGREGATED_MEMBERS_PRIMARY (RENAME=(_freq_=NO_OF_ACCTS) DROP = _TYPE_)
		SUM(EARN_ACTION_POINTS) = EARN_ACTION_POINTS
		SUM(BURN_REV_ACTION_POINTS) = BURN_REV_ACTION_POINTS
		SUM(PREALL_EARN_ACTION_POINTS) = PREALL_EARN_ACTION_POINTS
		SUM(BURN_ACTION_POINTS) = BURN_ACTION_POINTS
		SUM(EARN_REV_ACTION_POINTS) = EARN_REV_ACTION_POINTS
		SUM(PREALL_BURN_ACTION_POINTS) = PREALL_BURN_ACTION_POINTS
		SUM(POINTS_UNDER_PROCESS) = POINTS_UNDER_PROCESS
		SUM(POINTS_TO_EXPIRE) = POINTS_TO_EXPIRE
	;
RUN;
QUIT;

proc sort data = AGGREGATED_MEMBERS_PRIMARY;
	BY FINAL_ACC;
RUN;

proc sort data = temp;
	BY FINAL_ACC;
RUN;

data WHOUSE.AGGREGATED_MEMBERS_PRIMARY(rename=(FINAL_ACC=MEMBER_ACCOUNT_NUMBER));
	MERGE AGGREGATED_MEMBERS_PRIMARY (IN=IN1) TEMP(IN=IN2);
		BY FINAL_ACC;
	IF IN1 AND IN2;
run;
 
%mend create_agg_mem_dsn_with_points;
