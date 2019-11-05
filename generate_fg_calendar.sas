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


%macro generate_fg_calendar(base_year=, outdsn=work.FG_CALENDAR_&base_year.);

data &outdsn.;
	format activity_date date9.;
	DO i = "01JUL&base_year."D TO "08JUL&base_year."D;
		IF weekday(i) = 2 then start = I;
		CONTINUE;
	END;
	end = intnx("WEEK.2", INTNX("YEAR", start, 3, "S"), -1, "E");

	count = 0;
	week = 0;
	do activity_date = start to end;
		count = count + 1;
		if mod(count, 7) = 1 then week = week + 1;
		output;
	end;
	keep activity_date week;
run;

%mend generate_fg_calendar;
