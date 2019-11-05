/************************************************************************************
*       Program      : Notifications_email_creds.sas								*
*		Owner        : Analytics, LSRPL                                 			*
*                                                                       			*
*       Author       : LSRL/324                                            			*
*                                                                       			*
*       Input        : No Input														*																					*
*																					*
*																					*
*																					*
*       Output       : Enables you to send mail FROM as notifications@payback.in	*
*                                                                       			*
*                                                                       			*
*       Dependencies : None															*
*                                                                       			*
*       Description  :                 												*
*																					*
*       Usage        : Can be used to send mail from SAS(FROM as notifications@payback.in) *
*                                                                       			*
*       History      :                                                  			*
*       (Analyst)     	(Date)    	(Changes)                               		*
*                                                                       			*
*        LSRL/324		01Oct2012	Created                                         *      
************************************************************************************/

	options emailsys=smtp  emailhost=inblrpoc02.lsrpl.local emailport=25 ;
	options emailID = "notifications@payback.in";
	options EMAILAUTHPROTOCOL=NONE;
	options emailpw= '123456Nn';

