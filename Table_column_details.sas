/************************************************************************************
*       Program      : Table_Column_Details.sas										*
*		Owner        : Analytics, LSRPL                                 			*
*                                                                       			*
*       Author       : LSRL/324                                            			*
*                                                                       			*
*       Input        : Var= Table name(s) or Variable Name(s) 						*
*																					*
*		Eg:																			*
*																					*
-1)%Table_Column_Details(var=member_vw);											*

-2)%Table_Column_Details(var=member_vw account_aggregation_master);   				*

-3)%Table_Column_Details(var=member_vw earn_burn_residue);   						*

-4)%Table_Column_Details(var=Final_acc agg_flag);									*
*																					*
*       Output       : Gives the details of Tables or Columns if it exists 			*
*                                                                       			*
*                                                                       			*
*                                                                       			*
*       Description  : Gives details about column names and tables names   			*
*																					*
*       Usage        :                                                  			*
*                                                                       			*
*                                                                       			*
*       History      :                                                  			*
*       (Analyst)     	(Date)    	(Changes)                               		*
*                                                                       			*
*        LSRL/324		22Feb2013	Created                                         
************************************************************************************/

%macro Table_Column_Details(var);

%let cnt = %eval(%sysfunc(countc("&var.",' '))+1);

%do i = 1 %to &cnt.;

	%let value&i. = %scan(&var, &i.," ");

	proc sql noprint;
		select 
				count(*) into : cnt_tbl
		from sashelp.vtable where upcase(memname) = upcase("&&value&i..") ;
	quit;

	%if &cnt_tbl = 0 %then
			%put &&value&i.. --- Table Doesnot Exist ;

	Proc sql noprint;
		select 
				count(*) into : cnt_col
		from sashelp.vcolumn where upcase(name) = upcase("&&value&i..");
	quit;

	%if &cnt_col = 0 %then
			%put &&value&i.. --- Column not avilable;

	%if &cnt_tbl ge 1 %then
		%do;
				proc sql ;
				select 	 libname
						,memname
						,Typemem
						,nvar
						,nobs
						,sortname
						,sorttype
						,sortchar
				
				from sashelp.vtable where upcase(memname) = upcase("&&value&i..") ;
				quit;

		%end;

	%if &cnt_col ge 1 %then
		%do;
			Proc sql;
				select 
						 upcase(name) label="Column Name" 	as col_name
						,upcase(type) label="Data Type"		as col_type
						,libname
						,memname
						,memtype


				from sashelp.vcolumn where upcase(name) = upcase("&&value&i..");
			quit;
		%end;
%end;
%mend;

