/* ***************************************************** 
* macro validation: find the illegal valus
* parameters
* setname: the name of the dataset, libref could be included
* vars: the list of variable that would like to evalued
 ********************************************************/

%macro validation(setname, vars)/minoperator;
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
		data _null_;
			length temp $500;
			 temp=upcase(cat('"',tranwrd("&vars" ," " ,'", "'),'"'));
			 call symput('varlist',temp);
		run;
		proc sql noprint;
			select name 
				into: charlist separated by ' '
				from sashelp.vcolumn
				where libname= "&lib" and upcase(memname) = %str("&setname") and type = "char" and upcase(name) in (&varlist);
			select name 
				into: numlist separated by ' '
				from sashelp.vcolumn
				where libname= "&lib" and upcase(memname) = %str("&setname") and type = "num" and upcase(name) in (&varlist);
		quit;
		%if %symexist(charlist)  %then %do;
			proc freq data = &lib..&setname;
				tables &charlist / nocum nopercent;
			run;
		%end;
		%if %symexist(numlist)   %then %do;
			proc means data=&lib..&setname n nmiss min max;
				var &numlist;
			run;
		%end;
	%end;
%mend validation;
