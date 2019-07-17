/* ***************************************************** 
* macro LegVal: find the illegal valus
* parameters
* setname: the name of the dataset, libref could be included
* vars: the list of variable that would like to evalued
 ********************************************************/
%macro LegVal(setname, vars)/minoperator;
	%let setname=%upcase(&setname); 
	%let lib=%scan(&setname, 1, .);
	%if &setname=&lib %then %let lib=USER;
	%else %let setname=%scan(&setname, 2, .);
	%if %length(%superq(vars)) =  %then %do;
		proc means data=&setname n nmiss min max;
			var _NUMERIC_;
		run;
		proc freq data = &setname;
			tables _CHAR_ / nocum nopercent;
		run;
	%end;
	%else %do;
		%if %index(&vars,%str(%"))=0 or %index(&vars,%str(%'))=0 %then %StrTran(vars);
		proc sql noprint;
			select case when type = "char" then name else " " end, 
				case when type = "num" then name else " " end
				into :charlist separated by ' ', :numlist separated by ' '
				from sashelp.vcolumn
				where libname= "%upcase(&lib)" and memname = "%upcase(&setname)" and 
					upcase(name) in (%upcase(&vars));
		quit;
		%if %superq(charlist) ne %then %do;
			proc freq data = &lib..&setname;
				tables &charlist / nocum nopercent;
			run;
		%end;
		%if %superq(numlist) ne %then %do;
			proc means data=&lib..&setname n nmiss min max;
				var &numlist;
			run;
		%end;
	%end;
%mend LegVal;
