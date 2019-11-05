/************************************************************************
*       Program      :                                                  *
*  /sasdata/core_etl/prod/sas/sasautos/create_pb_std_formats_analyt.sas *
*                                                                       *
*       Owner        : Analytics, LSRPL                                 *
*                                                                       *
*       Author       : LSRL/540. Bhagat Singh                           *
*                                                                       *
*       Input        :                                                  *
*                                                                       *
*                                                                       *
*                                                                       *
*       Output       : FORMATS.FORMATS catalog at                       *
*     /sasconf/serverconfig/Lev1/SASAnalytics/SASEnvironment/SASFormats *
*                                                                       *
*                                                                       *
*       Dependencies : NONE                                             *
*                                                                       *
*       Description  : This module is meant for creating standardized   *
*          formats for PB REPORTING & ANALYTICS streams. This macro     *
*          can be called directly or through the autoexec module:       *
*   /sasdata/core_etl/prod/sas/includes/init_env_analyt.sas and will be *
*          available through the SAS session. While ETL_ADM user is the *
*          only user who could create/edit/delete these formats, the    *
*          other users can avail the formats in READ-ONLY mode.         *
*                                                                       *
*       Usage        :                                                  *
*		%create_pb_std_formats_analyt;                                         *
*                                                                       *
*       History      :                                                  *
*       (Analyst)     (Date)    (Changes)                               *
*       LSRL/273  01SEP2013     Created.                                *
*       LSRL/273  10OCT2013     Added a deletion step on the top of this*
*                               macro to eliminate data/catalog         *
*                               corruption issues. (C00001)             *
*       LSRL/273  10OCT2013     Modified the CARD_TYPE format to depict *
*                               permanent & virtual card types (physical*
*                               card type id is 1 & 5 instead of 1 & 4. *
*                               (C00002)                                *
*       LSRL/273  10OCT2013     Added three new formats                 *
*                               ptsvd, rfmtpts & enrcmpgn (C00003)      *
*       LSRL/273  30OCT2013     Added an include step for creation of   *
*                               top fg cities based on enrolment &      *
*                               performance criteria. (C00004)          *
*       LSRL/273  15NOV2013     Adding INDUSLEAGUE to FGPARTCD format   *
*                               (C00005)                                *         
*       LSRL/273  02DEC2013     Adding INDUSLEAGUE related updates to   * 
*                               all formats (C00006)                    *  
*       LSRL/334  06JUL2014     Adding Formats for accessing the Character
*							variables(RFV, Evolution Segments,Reachability)
*										in ALL_MEMBERS_SEGMENTS_FILE   * 
*                              			  (C00007)                    *  
************************************************************************/

%macro create_pb_std_formats_analyt;

%include "/sasdata/core_etl/prod/sas/sasautos/get_observation_count.sas";
%include "/sasdata/core_etl/prod/sas/sasautos/cmpres.sas";
/* %include "/sasdata/core_etl/prod/sas/sasautos/Campaign_analysis_macro.sas"; */
/* %include "/sasdata/core_etl/prod/sas/sasautos/Table_column_details.sas"; */

/* C00001: Addition of a deletion step for FORMATS catalog to avoid data corruption */

proc sort data=dwhlib.partner_list out=partner_list nodupkey;
by partner_id;
run;

proc sort data = whouse.partner_hierarchy_1_dedup OUT=partner_hierarchy_1_dedup nodupkey;
 by BRANCH_ID;
run;

PROC DATASETS LIB=FORMATS MT=CATALOG nolist;
	DELETE
		FORMATS
	;
quit;

/* Formats by direct value enlisting - HIGH MAINTENANCE */
proc format library = FORMATS;
	value ACTION_TYPE 
		3 = "Earn Reversal"
		4 = "Burn Reversal"
		1,5 = "Earn"
		2,6 = "Burn"
	;
quit;

proc format library = FORMATS;
	value ACTION_SUB_TYPE 
		3 = "Earn Reversal"
		4 = "Burn Reversal"
		1 = "Earn"
		5 = "Preallocated Earn"
		2 = "Burn"
		6 = "Preallocated Burn"
	;
quit;

proc format library=FORMATS;
	VALUE fgprcd
	183 = "BRF"
	179 = "BBZ"
	181 = "FBZ"
	182 = "CTL"
	185 = "EZN"
	184 = "HTN"
	180 = "PTL"
	188 = "FUTBCOM"
	190 = "PTL3STR"
	191 = "PTL5STR"
	192 = "PTL7STR"
	193 = "EZOL"
	194 = "FH"
	197 = "PFO"
	200 = "FRT"
	205 = "FBB"
	223 = "IL" /* C00006 */
	OTHER = "PB N/W"
	;
quit;

proc format library=FORMATS;
	VALUE fgpartcd
	179 = "BIG BAZAAR"
	180 = "PANTALOON"
	181 = "FOOD BAZAAR"
	182 = "CENTRAL"
	183 = "BRAND FACTORY"
	184 = "HOME TOWN"
	185 = "E ZONE"
	188 = "FUTURE BAZAAR"
	190 = "PANTALOON 3STAR"
	191 = "PANTALOON 5STAR"
	192 = "PANTALOON 7STAR"
	193 = "E ZONE ONLINE"
	194 = "FOOD HALL"
	197 = "PANTALOONS FACTORY OUTLET"
	200 = "FOOD RIGHT"
	205 = "FBB"
	223 = "INDUSLEAGUE"
   
	OTHER = "PB N/W"
	;
run;

proc format library=FORMATS;
	VALUE fgpid2lmid
	179 = 90012965
	180 = 90012972
	181 = 90012969
	182 = 90012967
	183 = 90012966
	184 = 90012971
	185 = 90012968
	188 = 90012970
	190 = 90012972
	191 = 90012972
	192 = 90012972
	193 = 90012968
	194 = 90013041
	197 = 90013564
	200 = 90013625
	205 = 90013505
	223 = 90014145
	;
quit;

proc format library=FORMATS;
	VALUE $ fgpart2lmid
	"BIG BAZAAR" = 90012965
	"PANTALOONS" = 90012972
	"FOOD BAZAAR" = 90012969
	"CENTRAL" = 90012967
	"BRAND FACTORY" = 90012966
	"HOME TOWN" = 90012971
	"E ZONE" = 90012968
	"PANTALOON 3STAR" = 90012972
	"FUTURE BAZAAR" = 90012970
	"PANTALOON 5STAR" = 90012972
	"PANTALOON 7STAR" = 90012972
	"PANTALOON" = 90012972
	"E ZONE ONLINE" = 90012968
	"FOOD HALL" = 90013041
	"FBB" = 90013505
	"PANTALOONS FACTORY OUTLET" = 90013564
	"FOOD RIGHT" = 90013625
	"INDUSLEAGUE" = 90014145
	;
quit;

PROC FORMAT library=formats;
	value $ citygrp
	'MUMBAI'='MUMBAI'
	'DELHI'='DELHI'
	'HYDERABAD' = 'HYDERABAD'
	'KOLKATA' = 'KOLKATA'
	'AHMEDABAD' = 'AHMEDABAD'
	'PUNE' = 'PUNE'
	'BANGALORE' = 'BANGALORE'
	'CHENNAI' = 'CHENNAI'
	OTHER = 'OTHERS'	
	;
QUIT;

PROC FORMAT library = formats;
	VALUE AGEGRP
	low-17 = '< 18'
	18-25 = '18-25'
	26-30 = '26-30'
	31-40 = '31-40'
	41-45 = '41-45'
	46-50 = '46-50'
	51-60 = '51-60'
	61-70 = '61-70'
	other = 'N/A'
	;
quit;

proc format;
	value $ KPINAME
		"UNIQ_MEMCNT" = "# of Unique Members transacted"
		"uniq_memcnt" = "# of Unique Members transacted"
		"TOTAL_BRCH_SALES" = "Total value of Earn tranx"
		"num_earns" = "# of Earn Transactions"
		"NUM_EARNS" = "# of Earn Transactions"
		"num_burns" = "# of Redemptions"
		"NUM_BURNS" = "# of Redemptions"
		"POINTS_EARNS" = "Total points issued"
		"points_earns" = "Total points issued"
		"POINTS_BURNS" = "Total points redeemed"
		"points_burns" = "Total points redeemed"
		"num_earn_revs" = "# of Earn Rev. activities"
		"NUM_EARN_REVS" = "# of Earn Rev. activities"
		"POINTS_EARN_REVS" = "Total earn points reversed"
		"points_earn_revs" = "Total earn points reversed"
		"TOTAL_PB_BILLS" = "Total PB Bills"
		"total_pb_bills" = "Total PB Bills"
	;
quit;

proc format library = formats;
	value $ fgcmbine (DEFAULT=20)
	"BIG BAZAAR-NWG" = "BIGBAZAAR"
	"BIG BAZAAR-SE" = "BIGBAZAAR"
	"FOOD BAZAAR-NWG" = "FOODBAZAAR"
	"FOOD BAZAAR-SE" = "FOODBAZAAR"
	;
run;

/* 
	Based on:
		1	PERMANENT
		2	TEMPORARY
		3	NOT CARDED
		4	RETAIL CARDS
		5	VIRTUAL CARDS
*/

proc format library = FORMATS;
	value card_sub_type
		1 = "PERMANENT"
		2 =	"TEMPORARY"
		3 =	"NOT CARDED"
		4 =	"RETAIL CARDS"
		5 =	"VIRTUAL CARDS"
	;
quit;

/* C00002 */
proc format LIBRARY = FORMATS;
	value CARD_TYPE
		1,5="CARDED"
		2,3,4="NON-CARDED"
	;
quit;


PROC FORMAT library = formats;
	value card_type_prec
		1 = 1 
		2 = 3
		3 = 4
		4 = 2
		5 = 5
	;
quit;


Proc format library = formats;
       Value SEG_AFFLUENT_PB 
          1 = "Royal Redeemer"
          2 =  "Affluent"
          3 =  "Big Ticket Spenders"
          4 =  "Enthusiast FG"
          5 =  "Low Enthusiast FG"
      ;
quit;

proc format library=formats;
       value pts2slab
              low-0 = "0"
              1-200 = ">0 to 200"
              201-1000 = ">200 to 1000"
              1001-2000 = ">1000 to 2000"
              2001-4000 = ">2000 to 4000"
              4001-5000 = ">4000 to 5000"
              5001-8000 = ">5000 to 8000"
              8001-10000 = ">8000 to 10000"
              10001-12000 = ">10000 to 12000"
              12001-50000 = ">12000 to 50000"
              50001-100000= ">50000 to 100000"
              100001-high= ">100000"
       ;
quit;

/* C00003 */
Proc format library=formats;
     value ptsvd
           low-0 = "0"
           1-49 = ">1 to 49"
           50-199 = ">50 to 199"
           200-499 = ">200 to 499"
           500-999 = ">500 to 999"
           1000-high = ">1000"
     ;
quit;

/* C00003 */
proc format library=formats;
     value RFMTPTS
           0 = '0'
           1-49 = '1-49'
           50-199 = '50-199'
           200-499 = '200-499'
           500-999 = '500-999'
           1000-high = '1000+'
     ;
quit;

proc format library=formats;
	value pts4slab
		low-0 = "0"
		1-200 = ">0 to 200"
		201-1000 = ">200 to 1000"
		1001-2000 = ">1000 to 2000"
		2001-4000 = ">2000 to 4000"
		4001-high = ">4000"
	;
quit;

proc format LIBRARY = FORMATS;
	value age
	15-21	=	"15-21" 
	22-29	=  	"22-29" 
	30-39	=	"30-39" 
	40-55	=	"40-55" 
	56-high	=	"56 +" 
	other 	= 	"N/A"
;
run;
quit;


/* Based on PID_ENROLMENT, which is a result of formatted promo_code_id by PID2PART format */
PROC FORMAT LIBRARY = FORMATS;
	VALUE $ ENRGRP
	"BIGBAZAAR" = "BIGBAZAAR"
	"FOODBAZAAR" = "FOODBAZAAR"
	"CENTRAL" = "CENTRAL"
	"BRANDFACTORY" = "BRANDFACTORY"
	"HOMETOWN" = "HOMETOWN"
	"EZONE" = "EZONE"
	"FUTUREBAZAAR" = "FUTUREBAZAAR"
	"PANTALOONS" = "PANTALOONS"
	"FOODHALL" = "FOODHALL"
	"FBB" = "FBB"
	"INDUSLEAGUE" = "INDUSLEAGUE" /* Adding INDUSLEAGUE to list of enrolments (C00006) */
	"FOODRIGHT" = "FOODRIGHT"
	"ICICIBANKDEBIT" = "ICICIDEBIT"
	"ICICIBANKCREDIT" = "ICICICREDIT"
	"ICICIOTHERS" = "ICICIOTHERS"
	"HPCL" = "HPCL"
	"MEGAMART" = "MEGAMART"
	"MMT" = "MMT"
	"MKRETAIL" = "MKRETAIL"
	"UNIVERCELL" = "UNIVERCELL"
	"B2E FIDELITY" = "B2E"
	"B2E MINDTREE" = "B2E"
	"B2E HCL" = "B2E"
	"B2E METLIFE" = "B2E"
	"B2E UBG" = "B2E"
	"B2E COGNIZANT" = "B2E"
	"B2E NESS" = "B2E"
        "VF_POSTPAID"= "VODAFONE"
         "VF_PREPAID"= "VODAFONE"
	OTHER = "PB N/W"
    
	;
quit;

/* Based on P_COMMERCIAL_NAME, which is a result of formatted partner_id by PART2NM format */
PROC FORMAT LIBRARY = FORMATS;
	VALUE $ PARTGRP
	"BIGBAZAAR" = "BIGBAZAAR"
	"FOODBAZAAR" = "FOODBAZAAR"
	"CENTRAL" = "CENTRAL"
	"BRANDFACTORY" = "BRANDFACTORY"
	"HOMETOWN" = "HOMETOWN"
	"EZONE" = "EZONE"
	"EZONEONLINE" = "EZONEONLINE"
	"FUTUREBAZAAR" = "FUTUREBAZAAR"
	"PANTALOONS" = "PANTALOONS"
	"FOODHALL" = "FOODHALL"
	"FOODRIGHT" = "FOODRIGHT"
	"FBB" = "FBB"
	"INDUSLEAGUE" = "INDUSLEAGUE" /* C00006 */
	"HPCL" = "HPCL"
	"MEGAMART" = "MEGAMART"
	"MMT" = "MMT"
	"MMT_BUS" = "MMT"
	"MMT_DOM_AIR_TCKT" = "MMT"
	"MMT_AIRTKT" = "MMT"
	"MMT_HOTELS" = "MMT"
	"MMT_DOM_PKG" = "MMT"
	"MMT_INTL_PKG" = "MMT"
	"MMT_INTL_AIR_TCKT" = "MMT"
	"MAKEMYTRIP(INDIA)PVT.LTD." = "MMT"
	"MKRETAIL" = "MKRETAIL"
	"UNIVERCELL" = "UNIVERCELL"
	"ICICIBANKCREDIT" = "ICICICREDIT"
	"ICICIBANKDEBIT" = "ICICIDEBIT"
	"ICICIOTHERS" = "ICICIOTHERS"
	"BOOKMYSHOW" = "BOOKMYSHOW"
	"PLANETSPORTS"  =  "PLANETSPORTS"   /* added below 7 partners on 26-10-2012 */
	"BABYOYE"  =  "BABYOYE"
	"EDABBA"  =  "EDABBA"
	"FIRSTCRY"  =  "FIRSTCRY"
	"KOOVS"  =  "KOOVS"
	"PERFUME2ORDER"  =  "PERFUME2ORDER"
	"SURATDIAMOND"  =  "SURATDIAMOND"
	"VALYOO"  =  "VALYOO"
        "VF_POSTPAID"= "VODAFONE"
         "VF_PREPAID"="VODAFONE"
	OTHER = "PB N/W"
	;
quit;

/* ----------- Added on 31-10-2012 -- Partner wise Shortcuts ----------- */

PROC FORMAT;
VALUE $PARTNER2SCT
		"BIGBAZAAR"		=		"FG_BBZ"
		"FOODBAZAAR"	=		"FG_FOB"
		"CENTRAL"		=		"FG_CTL"
		"BRANDFACTORY"	=		"FG_BF"
		"HOMETOWN"		=		"FG_HTN"
		"EZONE"			=		"FG_EZ"
		"FUTUREBAZAAR"	=		"FG_FUB"
		"PANTALOONS"	=		"FG_PL"
		"FOODHALL"		=		"FG_FHL"
		"FOODRIGHT"		=		"FG_FRT"
		"FBB"			=		"FG_FBB"
		"INDUSLEAGUE"                 =         "FG_IL" /* C00006 */
		"HPCL"			=		"HPCL"
		"MEGAMART"		=		"MM"
		"MMT"			=		"MMT"
		"MKRETAIL"		=		"MKR"
		"UNIVERCELL"	=		"UNI"
		"ICICICREDIT"	=		"ICICR"
		"ICICIDEBIT"	=		"ICIDE"
		"ICICIOTHERS"	=		"PBN"  
		"BOOKMYSHOW"	=		"BMS"
		"PB N/W"		=		"PBN"
		"PLANETSPORTS"  =   	"PLASP"
		"BABYOYE"   	=   	"BABOY"
		"EDABBA"   		=   	"EDB"
		"FIRSTCRY"   	=   	"FICR"
		"KOOVS"   		=   	"KOO"
		"PERFUME2ORDER" = 		"PER"  
		"SURATDIAMOND"  =   	"SUR"
		"VALYOO"   		=   	"VALY"
;
quit;

proc format;
	value $ metro 
	"KOLKATA" = "METRO"
	"DELHI" = "METRO"
	"NEW DELHI" = "METRO"
	"MUMBAI" = "METRO"
	"CHENNAI" = "METRO"
	"PUNE" = "METRO"
	"HYDERABAD" = "METRO"
	"BANGALORE" = "METRO"
	"BENGALURU" = "METRO"
	"BANGLORE" = "METRO"
	OTHER = "NON-METRO"
	;
quit;


proc format library=formats;
	value KYCFLG
		1 = "ACCEPTED COMPLETE"
		2 = "ACCEPTED INCOMPLETE (EML/ADDR)"
		3 = "ACCEPTED INCOMPLETE (BOTH)"
		4 = "NOT UPDATED"
	;
quit;

PROC FORMAT;
	VALUE TRANTYPE
		8,295="SWIPE EARN"
		OTHER="NON-SWIPE EARN"
	;
QUIT;

/* For Adhoc Request for FG reporting */
proc format library=formats;
	value pts4fg
		low-0 = "0"
		1-200 = ">0 to 200"
		201-1000 = ">200 to 1000"
		1001-2000 = ">1000 to 2000"
		2001-4000 = ">2000 to 4000"
		4001-5000 = ">4000 to 5000"
		5000-10000 = ">5000 to 10000"
		10000-high = ">10000"
	;
run;

/*MMT FormatS*/

proc format library = FORMATS;
	value memtype
	167 = "ROYALE"
		166 = "ELITE"
		2,168 = "CLASSIC"

	;
quit;


proc format library = FORMATS;
	value MOMtype
	201111 = "NOV11"
	201112 = "DEC11"
	201201 = "JAN12"
	201202= "FEB12"
	201203= "MAR12"
	201204 = "APR12"
	201205= "MAY12"
	201206= "JUN12"
	201207= "JUL12"
	201208= "AUG12"
	201209= "SEP12"
	;
quit;

PROC FORMAT ;
		VALUE EC_TYPE
				1 =	"Offline Offer"
				2 =	"Online Offer";
		
quit;

/* For accessing the Character variables(RFV, Evolution Segments,Reachability)
	in ALL_MEMBERS_SEGMENTS_FILE */
/*C00007*/
proc format library = FORMATS;
		value SEG_RFV_FRL 
	1 ="REGULAR_BIG_TROLLEY"
	2 ="REGULAR_MEDIUM_TROLLEY"
	3 ="REGULAR_LOW_TROLLEY"
	4 ="ONE_TIME_HIGH_VALUE"
	5 ="ONE_TIME_LOW_VALUE"
	6 ="CASUAL_HIGH_VALUE"
	7 ="CASUAL_LOW_VALUE"
	8 ="BIGBAZAAR NEW CUSTOMER"
	9 ="BIGBAZAAR INACTIVE"
	10 ="BIGBAZAAR LAPSER"
	;
		VALUE SEG_RFV_CEN 
	1 ="Central Platinum"
	2 ="Central Gold"
	3 ="Central Silver"
	4 ="Central Active"
	5 ="Central Never active"
	;
		VALUE SEG_RFV_BF 
	1 ="HIGH SPENDERS"
	2 ="REGULAR SHOPPERS"
	3 ="NASCENT SHOPPER"
	4 ="BF NEW CUSTOMER"
	5 ="HIBERNATORS"
	;
	
		VALUE SEG_EVOLUTION_VI 
	1 ="ADVO"
	2 ="ENTH"
	3 ="KN_ICI_MP"
	4 ="KN_ICI_SP"
	5 ="KNOWER_MP"
	6 ="KNOWER_SP"
	7 ="BY_ICI_SP"
	8 ="BY_ICICI_MP"
	9 ="BY_MP"
	10 ="BY_SP"
	11 ="INACTIVE"
	;
		

		VALUE SEG_LIFESTAGE
	1="A.PENSION(>=60)"
	2="B.Single_MEN(<=30)"
	3="C.Single_WOMEN(<=30)"
	4="D.YOUNG_COUPLES(<=30)"
	5="F.COUPLES(30-45)"
	6="G.COUPLE_KID(30-45)"
	7="H.Single_MEN(30-45)"
	8="I.Single_WOMEN(30-45)"
	9="K.Mature_COUPLE_KID(45-60)"
	10="L.Single_MEN(45-60)"
	11="M.Single_WOMEN(45-60)"
       12="E.YOUNG_COUPLE_KID(<=30)"
	;
		VALUE SEG_EVOLUTION_VII 
	7="Cursory_shoppers"
	6="Single_LOB_enthusiasts"
	5="Single_LOB_Loyalists"
	4="Two_Dipping_cross_User"
	3="Two_Format_Enthusiasts"
	2="Enthusiasts"
	1="Advocates"
	;

		VALUE SEG_WOMEN 
	1="1. BigBazaar Loyalists"
	2="2. Ready to eat Shoppers"
	3="3. Groceries & Staples Shoppers"
	4="4. Non Essentials Shoppers"
	5="5. Random Shoppers"
	;

      
value seg_wallet
1="HIGHEST" 
2="HIGH" 
3="AVERAGE" 
4="LOW"
5="LOWEST" 
;
value CEN_TIER_MGMNT
1="1 LEVEL UP" 
2="2 LEVEL UP" 
3="3 LEVEL UP" 
4="HOLD"
5="1 LEVEL DOWN" 
6="2 LEVEL DOWN" 
7="3 LEVEL DOWN"
; 

run;


/* Format based on datasets - FORMAT LOOKUP (recommended method for format creation) */


data MEMBER_CARD_LOGO_MAP;
	format label $10.;
	retain fmtname "CDLOGOMP" type "N";
	set DWHLIB.MST_MEMBER_CARD_TYPE;
	start = MEMBER_CARD_TYPE_ID;
	label = MEMBER_CARD_TYPE_DESC;
run;

proc format cntlin = MEMBER_CARD_LOGO_MAP library = FORMATS;
quit;


/* FG Week definition */
data _null_;
	call symput("curr_year", YEAR("&SYSDATE"D));
run;

%put &curr_year.;

%INCLUDE "/sasdata/core_etl/prod/FG/sasautos/generate_fg_calendar.sas" /source2;
%generate_fg_calendar(base_year=2011, outdsn=whouse.fg_week_calendar_%cmpres(&curr_year.));

data fg_temp;
	format label $10.;
	retain fmtname "FGWEEK" type "N";
	set whouse.fg_week_calendar_%cmpres(&curr_year.);
	start = activity_date;
	label = "Week # " || put(week,3.);
run;

proc format cntlin = fg_temp library = FORMATS;
run;

/* FG fiscal month for the fiscal year 2011-12 */
proc format library = formats;
	value fg_wk_mth_map
		1-4 = "JUL2011"
		5-8 = "AUG2011"
		9-13 = "SEP2011"

		14-17 = "OCT2011"
		18-21 = "NOV2011"
		22-26 = "DEC2011"

		27-30 = "JAN2012"
		31-34 = "FEB2012"
		35-39 = "MAR2012"

		40-43 = "APR2012"
		44-47 = "MAY2012"
		48-52 = "JUN2012"
	;
run;		

data fg_temp2;
	format label 8.;
	retain fmtname "FGWEEKN" type "N";
	set whouse.fg_week_calendar_%cmpres(&curr_year.);
	start = activity_date;
	label = week;
run;

proc format cntlin = fg_temp2 library = WORK;
run;

data active_status_temp;
	retain fmtname "fmtactstat" type "N";
	set dwhlib.mst_active_status;
	START = active_status_id;
	label = active_status_desc;
run;

proc format lib=formats cntlin=active_status_temp;
run;

/* Formats out of datasets */

proc sort data = dwhlib.mst_association out=SUPPLIB.AID_LIST NODUPKEY;
	by ASSOCIATION_ID;
run;

data TEMP_AID;
	RETAIN FMTNAME "AID2CODE" type "N";
	set supplib.aid_list;
	WHERE ASSOCIATION_ID ~= .;
	start = association_id;
	label = ASSOCIATION_CODE;
run;

proc format cntlin = temp_AID library = formats;
run;
	
proc sort data = dwhlib.mst_sourced_association out=SUPPLIB.SID_LIST NODUPKEY;
	by SOURCED_ASSOCIATION_ID;
run;

data TEMP_SID;
	RETAIN FMTNAME "SID2DESC" type "N";
	set supplib.sid_list;
	start = sourced_association_id;
	label = SOURCED_ASSOCIATION_DESC;
run;

proc format cntlin = temp_SID library = formats;
run;


proc sort data = dwhlib.mst_sourced_association out=SUPPLIB.SID_LIST_2 NODUPKEY;
	by SOURCED_ASSOCIATION_ID;
run;

data TEMP_SID_2;
	RETAIN FMTNAME "SID2CODE" type "N";
	set supplib.sid_list_2;
	start = sourced_association_id;
	label = SOURCED_ASSOCIATION_CODE;
run;

proc format cntlin = temp_SID_2 library = formats;
run;


proc sort data = dwhlib.mst_promo_codes out=SUPPLIB.PID_LIST NODUPKEY;
	by PROMO_CODE_ID;
run;

data TEMP_PID;
	RETAIN FMTNAME "PID2DESC" type "N";
	set SUPPLIB.PID_LIST;
	start = PROMO_CODE_ID;
	label = PROMO_CODE_DESC;
run;


proc format cntlin = temp_PID library = formats;
run;

proc sort data = dwhlib.mst_promo_codes out=SUPPLIB.PID_LIST_2 NODUPKEY;
	by PROMO_CODE_ID;
run;

data TEMP_PID_2;
	RETAIN FMTNAME "PID2CODE" type "N";
	set SUPPLIB.PID_LIST_2;
	start = PROMO_CODE_ID;
	label = PROMO_CODE;
run;

proc format cntlin = temp_PID_2 library = formats;
run;

proc sort data = dwhlib.mst_member_card_type out=SUPPLIB.MEM_CARD_TYPE_LIST NODUPKEY;
	by  MEMBER_CARD_TYPE_ID;
run;

data TEMP_MCTID;
	RETAIN FMTNAME "MCT2DESC" type "N";
	set SUPPLIB.MEM_CARD_TYPE_LIST;
	start = MEMBER_CARD_TYPE_ID;
	label = MEMBER_CARD_TYPE_DESC;
run;

proc format cntlin = temp_MCTID library = formats;
run;


proc sort data = partner_hierarchy_1_dedup OUT=partner_hierarchy_1_dedup_1 nodupkey;
 by star_BRANCH_ID;
run;


data branch;
	RETAIN FMTNAME "BRCHNM" TYPE "N";
	set partner_hierarchy_1_dedup_1 (keep=LEGAL_NAME STAR_BRANCH_ID);
	START=STAR_BRANCH_ID;
	LABEL = LEGAL_NAME;
run;

/*
data branch;
	RETAIN FMTNAME "BRCHNM" TYPE "N";
	set partner_hierarchy_1_dedup (keep=LEGAL_NAME STAR_BRANCH_ID);
	START=STAR_BRANCH_ID;
	LABEL = LEGAL_NAME;
run;
*/
proc format cntlin = BRANCH LIBRARY = FORMATS;
run;

/*ECOUPONE FORMAT FOR COMM_CHANNEL*/
/*
DATA ECOUPON.MST_ECOUPON_COMM_CHANNEL;
SET ECOUPON.EC_CHANNEL (keep=Channel_Code Channel_Name rename=(Channel_Code = Start CHANNEL_NAME = label)) end=last;
RETAIN fmtname  "ECOUPON_COMM_CHANNEL" TYPE 'N';
OUTPUT;
   if last then do;
      hlo='O';
      label='Other Channel';
      output;
   end;
run;
proc format lib=FORMATS cntlin=ECOUPON.MST_ECOUPON_COMM_CHANNEL;
RUN;
*/




/* LMID to PARTNER_ID lookup */
data lookup1;
	retain fmtname "LMID2PID" TYPE "C";
	set dwhlib.dim_partner (keep=partner_id loyalty_partner_id where=(loyalty_partner_id ~= ""));
	start = LOYALTY_PARTNER_ID;
	label = PARTNER_ID;
run;

proc format CNTLIN=WORK.LOOKUP1 library = FORMATS;
run;

/* PARTNER_ID TO LMID lookup */
data lookup2;
	retain fmtname "PID2LMID" TYPE "N";
	set dwhlib.dim_partner (keep=partner_id loyalty_partner_id);
	start = PARTNER_ID;
	label = LOYALTY_PARTNER_ID;
run;


proc format CNTLIN=WORK.LOOKUP2 library = FORMATS;
run;

/* PARTNER_ID TO PARTNER_TYPE FORMAT LOOKUP */

data partner_temp;
	retain fmtname "part2typ" type "N";
	set partner_list;
	start=partner_id;
	label=partner_type;
run;

proc format cntlin=partner_temp library=formats;
run;

/* PARTNER_ID TO PARTNER NAME (P_COMMERCIAL_NAME) FORMAT LOOKUP */

data partner_temp2;
	retain fmtname "part2nm" type "N";
	set partner_list end=EOF;
	
	start=partner_id;
	label=p_commercial_name;
	output;
	if EOF then do;
		hlo="O";
		label="OTHERRETAIL";
		output;
	end;
run;

proc format cntlin=partner_temp2 library=formats;
run;

/* Promo code id to partner (consolidated) */
data pid_temp;
	retain fmtname "pid2part" type "N"; 
	set supplib.pid2partner end=EOF;;
	start=promo_code_id;
	label=promo_partner;
	output;
	if EOF then do;
		hlo="O";
		label="OTHERRETAIL";
		output;
	end;
run;
	
proc format cntlin=pid_temp library=formats;
run;

/* Sourced Association id to partner (consolidated) */
data sid_temp;
	retain fmtname "sid2part" type "N"; 
	set supplib.sid2partner end=EOF;
	start=sourced_association_id;
	label=sourced_partner;
	output;
	if EOF then do;
		hlo="O";
		label="OTHERRETAIL";
		output;
	end;
run;
	
proc format cntlin=sid_temp library=formats;
run;


/* Board KPI partner list preparation */

proc sort data = supplib.board_kpi_partner_list out = board_kpi_plist nodupkey;
	by board_kpi_partner p_commercial_name;
run;

data board_kpi_hash;
	retain fmtname "part2brd" type "C"; 
	set board_kpi_plist end=EOF;

	IF p_commercial_name = "FIRSTCRY" and board_kpi_partner in ("OTHERS") THEN DELETE;
	IF p_commercial_name ="OTHERRETAIL" and board_kpi_partner in ("ONLINE") then delete;

	start=p_commercial_name;
	label=board_kpi_partner;
	output;
	if EOF then do;
		hlo="O";
		label="OTHERS";
		output;
	end;
run;
	
proc format cntlin = board_kpi_hash library = formats;
quit; 

/* Old to New MC code mappings */

DATA mc_temp;
	set supplib.Mc_level_mba_bigbazaar_mar_13;
	DEP_NAME = STRIP(UPCASE(DEP_NAME));
RUN;

proc sort data = MC_TEMP nodupkey;
	by DEP_NAME;
run;

data mc_temp;
	retain fmtname "old2nwmc" type "C"; 
	set MC_TEMP end=EOF;
		BY DEP_NAME;
	start=strip(upcase(DEP_NAME));
	label=strip(upcase(name));
	output;
	if EOF then do;
		hlo="O";
		label="OTHER";
		output;
	end;
run;
	
proc format cntlin=mc_temp library=formats;
run;

/* Basket item to description mapping */

proc sort data = supplib.fg_mc_code_to_desc out = basket_temp nodupkey;
	by mc_code mcnew;
run;

proc sort data = basket_temp nodupkey;
	by mc_code;
run;

data basket_desc;
	RETAIN FMTNAME "MC_CODE2DESC" TYPE "C";
	set basket_temp(keep=mc_code mcnew);
	START = MC_CODE;
	LABEL=strip(upcase(MCNEW));
run;

proc format library = formats cntlin=basket_desc;
quit;


/* Branch ID to Store Name lookup */

proc sort data = partner_hierarchy_1_dedup(keep=LEGAL_NAME BRANCH_ID) OUT=BRCH2STR_INPUT nodup;
	by BRANCH_ID;
run;

data BRCH2STR;
	RETAIN FMTNAME "brch2str" type "C";
	SET BRCH2STR_INPUT end=eof;
	WHERE
		not (strip(branch_id) = "6535" and strip(upcase(legal_name)) LIKE '%HYDERABAD%');

	legal_name = strip(upcase(legal_name));

	

	if strip(upcase(branch_id)) ~= "ONLINE" then do;
		start = branch_id;
		label = legal_name;
		output;
	end;
	
	if eof and strip(branch_id) ~= "" then do;	
		hlo="O";
		label="OTHER";
		output;	
	end;
run;

proc sort data = brch2str nodup;
	by BRANCH_ID;
run;

proc format cntlin = BRCH2STR library = formats;
quit;


/* Basket level - MC CODE TO DESC Lookup */
 
data basket_lkp;
	retain fmtname 'bsktmc2desc' type 'C'; 
	set supplib.basket_mc_code_2_desc end=eof;
	START = dep_code;
	LABEL = dep_name;
	output;
	if eof then do;
		HLO="O";
		label = "OTHERS";
		output;
	end;
run;

proc sort data = basket_lkp nodupkey;
	by dep_code;
run;

proc format cntlin=basket_lkp library = formats;
run;


/* Store code to City */
data store_temp;
	RETAIN fmtname 'fgstr2cy' TYPE 'C';
	set partner_hierarchy_1_dedup;
	where
/*		STRIP(UPCASE(branch_id)) not in ("ONLINE") */
/*		and */
		length(strip(branch_id)) <= 4
	;
	if length(strip(branch_id)) = 4 then do;
		start = strip(put(input(branch_id, 4.), 4.));
		label = strip(upcase(branch_city));
		output;
	end;
	if length(strip(branch_id)) = 3 then do;
		start = strip(put(input(branch_id, 4.), z4.));
		label = strip(upcase(branch_city));
		output;
		start = strip(put(input(branch_id, 4.), 4.));
		label = strip(upcase(branch_city));
		output;
	end;
run;

proc sort data = STORE_TEMP NODUPKEY;
	BY start;
RUN;

proc format library = formats cntlin = store_temp;
run;

/* Store code to Zone */
data store_temp_z;
	RETAIN fmtname 'fgstr2zn' TYPE 'C';
	set partner_hierarchy_1_dedup;
	where
/*		STRIP(UPCASE(branch_id)) not in ("ONLINE") */
/*		and */
		length(strip(branch_id)) <= 4
	;
	if length(strip(branch_id)) = 4 then do;
		start = strip(put(input(branch_id, 4.), 4.));
		label = strip(upcase(zone));
		output;
	end;
	if length(strip(branch_id)) = 3 then do;
		start = strip(put(input(branch_id, 4.), z4.));
		label = strip(upcase(zone));
		output;
		start = strip(put(input(branch_id, 4.), 4.));
		label = strip(upcase(zone));
		output;
	end;
run;

proc sort data = STORE_TEMP_z NODUPKEY;
	BY start;
RUN;

proc format library = formats cntlin = store_temp_z;
run;


/* Store code to Legal Name */
data store_temp1;
	RETAIN fmtname 'fgstr2nm' TYPE 'C';
	set partner_hierarchy_1_dedup;
	where
		STRIP(UPCASE(branch_id)) not in ("ONLINE") and length(strip(branch_id)) ~= 6;
	start = branch_id;
	label = strip(upcase(legal_name));
run;

proc sort data = STORE_TEMP1 NODUPKEY;
	BY BRANCH_ID;
RUN;

proc format library = formats cntlin = store_temp1;
QUIT;


/* transaction type  -- not activity_action_id */

proc sort data = DWHLIB.MST_activity_TRANS_TYPE out=WORK.TRANSACTION_TYPE NODUPKEY;
	by ACTIVITY_transaction_type_id descending update_date descending add_date;
run;

DATA WORK.TRANSACTION_TYPE;
	RETAIN fmtname 'TRNTYP2DESC' type 'N';
	SET WORK.TRANSACTION_TYPE;
	start = activity_transaction_type_id;
	LABEL = activity_transaction_desc;
run;

proc format cntlin=WORK.TRANSACTION_TYPE Library=FORMATS;
run;

/* Redeem_channel_id to redeem_channel_name */

proc sort data = DWHLIB.MST_REDEMPTION_CHANNEL out=WORK.REDEMPTION_CHANNEL NODUPKEY;
	by redeem_channel_id descending update_date descending add_date;
run;

DATA WORK.REDEMPTION_CHANNEL;
	RETAIN fmtname 'RDMID2NM' type 'N';
	SET WORK.REDEMPTION_CHANNEL;
	start = redeem_channel_id;
	LABEL = redeem_channel_name;
run;

proc format cntlin=WORK.redemption_channel Library=FORMATS;
run;


/* Creating Format for CITY and ZIP based on Terminal ID */
/* Added on 22 Nov 2012 */

proc sql;
create table terminal_dtls as
select 
		distinct Terminal_id as start,
		upcase(city)  as label1,
		zip as label2,
		'TID2city' as FMTNAME1,
		'TID2zip' as FMTNAME2

from dwhlib.det_partner_terminal_address
;
quit;

PROC SORT DATA = terminal_dtls;
	by start descending label2;
run;

PROC SORT DATA = terminal_dtls NODUPKEY;
	by start;
run;

proc format lib=formats cntlin=terminal_dtls(keep=start label1 fmtname1 rename=(label1=label fmtname1=fmtname));
run;

proc format lib=formats cntlin=terminal_dtls(keep=start label2 fmtname2 rename=(label2=label fmtname2=fmtname));
run;

%include "/sasdata/core_etl/prod/FG/includes/prep_fg_calendar_201213.sas" / source2;

/* Picture formats */
proc format;
	picture custcomma (round)
		low - 999 = '000'
		1000 - 9999 = '0,000'
		10000 - 99999 = '00,000'
		100000 - 999999 = '000,000'
		1000000 - 9999999 = '0,000,000'
		10000000 - 99999999 = '00,000,000'
		100000000 - 999999999 = '000,000,000'
		1000000000 - 9999999999 = '0,000,000,000'
	;
	picture datefmt (default=45)
	    low-high = 'Trans datD: %B %d, %Y %A' (datatype=date);
run;

/* Creation of a picture format converting datetime column into date or any of the higher periods */

PROC FORMAT library=formats;
	/* Datetime to Year-month */
	PICTURE dt2yrmon (default=10) other='%b%Y' (DATATYPE=DATETIME);
quit;

PROC FORMAT library=formats;
	/* Datetime to Year-month */
	PICTURE dt2yymmn (default=10) other='%Y%0m' (DATATYPE=DATETIME);
quit;

PROC FORMAT library=formats;
	/* Datetime to Year-month */
	PICTURE dt2date (default=9) other='%Y%0m%0d' (DATATYPE=DATETIME);
quit;

/* C00003 */
/* Definition of partner based on SID & PID combination as defined in the from the production MST_CAMPAIGN_SID_PID_LK master reference table */

	proc sort data = DWHLIB.MST_CAMPAIGN_SID_PID_LK OUT=MST_CAMPAIGN_SID_PID_LK;
		by
			sourced_association_id promo_code_id /* DESCENDING add_date */
		;
	run;

	proc sort data = MST_CAMPAIGN_SID_PID_LK nodupkey;
		by sourced_association_id promo_code_id;
	run;

	DATA fmt_CAMPAIGN_SID_PID_LK;
	
		RETAIN fmtname 'ENRCMPGN' type 'N';
		SET MST_CAMPAIGN_SID_PID_LK;
		start = SUM(sourced_association_id*1000, promo_code_id);
		LABEL = strip(upcase(MARKETING_DESC));
	run;

	proc format library=FORMATS CNTLIN=fmt_CAMPAIGN_SID_PID_LK;
	quit;
	run;

/* End of section - Picture formats */

/************************ End of section - Formats out of datasets **********************/

/* Additional date macro variables for computing KPIs by recency (C0003) */
%include "/sasdata/core_etl/prod/sas/includes/create_std_date_vars_inc.sas" / source2;

%include "/sasdata/core_etl/prod/FG/includes/prep_fg_top_cities_fmt.sas" / source2;

%mend create_pb_std_formats_analyt;

%create_pb_std_formats_analyt;

