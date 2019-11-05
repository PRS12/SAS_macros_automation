/************************************************************************
*       Program      : SET_RPT_ENV							            *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : ANANTHA RAMAN                          			*
*                                                                       *
*       Input        :  NONE                         					*
*                                                                       *
*       Output       : PERFECT SAS ENVIRONMENT							*
*                                                                       *
*       Dependencies : NONE                                             *
*                                                                       *
*       Description  : This macro can be used to SET THE BASIC SAS ENV  *
*                      at eachh invocation of SAS Session  				*
*																		*
* 		Path		 :/sasdata/core_etl/prod/sas/sasautos/set_rpt_env.sas*  
*																		*
*                                                                       *
*       Usage        : 													*
*                                                                       *
*       History      :                                                  *
*   LSRL-273	13-Jul-2011	Created.                       				*
*   LSRL-273    04-dec-2012 Added step to create dwhnpg library     	*
*                           (C0001)                                     *
*   LSRL-273    26-JAN-2013 Moving physical_card_Type_id = 4 from   	*
*                           CARDED to NON-CARDED bucket in the format 	*
*							definition FORMATS.CARD_TYPE (C0002)		*
*   LSRL-273    24-feb-2013 Added step to create date cut-off macro 	*
*                   		variables (C0003)                           *
*	LSRL-324    28-mar-2013 Default compress of datasets has added		*
*							(C0004)										*
*	LSRL-324    03-apr-2013 included table or column info macro (C0005) *
*	LSRL-273    01-may-2013	Added a new format PID2LMID to capture 		*
*							loyalty_partner_id given the partner_id 	*
*							(C0006)										*
*   LSRL-273  16-sep-2013 Migrated to the UNIX environment. (C0007)     * 
*   LSRL-273  17-sep-2013 Decoupled FORMAT creation code and restricted *
*                         it only for etl_adm user                      * 
*   LSRL-273  19-sep-2013 Added SUMMLIB to list of preloaded libraries (C0008)*
*   LSRL-273  01-oct-2013 Moved the SAS formats pre-loaded library from *
*             core_etl to sasconf area to facilitate availability of the*
*		formats to all client tools and BI servers. (C0009)       		*
*	LSRL-324  26-Oct-2013 Creates the formats on conditional basis		*
*				1) if login user is ETL_ADM and if it is first run only *
*				2) System will wait for 2 mins if signal file created 	*
*					with in 2 minutes of signal file creation (C0010)	*
*   LSRL-273  05-dec-2013 Added library reference for AMX_STG(C0011)    *
*   LSRL-334  15APR2014 created formats in a common location 			*
*             for both servers 10.32.161.207 and 10.32.161.208 to check *
*			  the difference between the performance of servers (C0012)*
*   LSRL-273  Restoring the formats location so that BI process can access *
*             user defined formats (C0013)                              *
************************************************************************/                            

options MAUTOSOURCE SASAUTOS=(
					"/sasdata/core_etl/prod/FG/sasautos/reporting steps"
					"/sasdata/core_etl/prod/FG/sasautos"
					"/sasdata/core_etl/prod/sas/sasautos"
                                         /*C0001 */
				);


%macro set_rpt_env;

options compress=Char Reuse=yes; /* C0004 */
options mprint mlogic symbolgen fmtsearch=(formats);

/* Date related macro variables to be available throughout the session */
data _null_;
	call symput("rundate", put(today(), date9.));
run;

%put &rundate.;

/* Earliest date to pick up data from */
%LET epoch=01JUL2010;

/* Last months last working day */
%LET START_DATE_LAST_MON = INTNX("MONTH", "&SYSDATE"D, -1, "B");
%LET END_DATE_LAST_MON = INTNX("MONTH", "&SYSDATE"D, -1, "E");
%LET START_DATE_CURR_MON = INTNX("MONTH", "&SYSDATE"D, -0, "B");
%LET END_DATE_CURR_MON = INTNX("MONTH", "&SYSDATE"D, -0, "E");

/* SAS Native libraries */
libname CUBELIB "/sasdata/core_etl/prod/libraries/CUBELIB";
libname AUDITLIB "/sasdata/core_etl/prod/libraries/AUDITLIB/";
libname SASMART "/sasdata/core_etl/prod/libraries/SASMART";
libname SUPPLIB "/sasdata/core_etl/prod/libraries/SUPPLIB";
libname WHOUSE "/sasdata/core_etl/prod/libraries/WHOUSE";
libname TEMPLIB "/sasdata/core_etl/prod/libraries/TEMPLIB";
libname OPSLIB "/sasdata/core_etl/prod/libraries/OPSLIB";
libname ECOUPON "/sasdata/core_etl/prod/libraries/ECOUPON";
libname REPORT "/sasdata/bi/REPORT";
/* C0008 */
libname SUMMLIB "/sasdata/core_etl/prod/libraries/SUMMLIB";
libname CIMLIB "/sasdata/ci/CIMPLIB";
libname CAMPLIB "/sasdata/campaign/CAMPLIB";
libname DIDLIB "/sasdata1/did/DIDLIB";
libname DID_STG "/sasdata1/did/DID_STG";

libname BI_STG "/sasdata1/bi/BI_STG";
libname BI_AUDIT "/sasdata1/bi/BI_AUDIT";

/* C0011 */
LIBNAME AMX_STG "/sasdata1/amex/AMX_STG";



/* 
	20130917: Currently, core_etl admin (etl_adm user does not have write access to the following folder.
	Moving formats creation to a localized folder within core_etl area. 

*/


/* C0009 */
/*(C0012)*/
/*LIBNAME FORMATS "/sasdata/core_etl/prod/libraries/FORMATS_TMP"; */
LIBNAME FORMATS "/sasconf/serverconfig/Lev1/SASApp/SASEnvironment/SASFormats/";
/*LIBNAME FORMATS "/sasconf/serverconfig/Lev1/SASAnalytics/SASEnvironment/SASFormats/";*/


/* ORACLE libraries */
%include "/sasdata/core_etl/prod/sas/includes/set_conn_biu_dwh_rw.sas" / source2;



/*C0010*/
/* Construction of standardized PB formats. Runs only if core_etl administrator invokes the SAS-session and file existence of formats_signal_DDMONYYYY.txt file*/

%mend set_rpt_env;


