/* ********************************************************
* macro get_matelen.sas: get the length of the variables
*	and store the data in a xml file
* parameters
* lib: specify the libaray
* dataset: the name of the original dataset
* file: the name of the xml file
* *********************************************************/
%macro get_matelen(lib=,dataset=, file=);
	%if %superq(lib) = %then %do;
		%if %sysfunc(libref(USER)) = 0 %then %let lib=USER;
		%else %let lib=WORK;
	%end;
	%if %superq(dataset) ne %then %do;
		%let dataset=%sysfunc(tranwrd(%sysfunc(strip(&dataset)), %str( ), %str(",")));
	%end;
	%if %superq(file)= %then %let file =&pdir.&lib._matelen.xml;
	proc sql;
		create table _temp as
			select libname, memname 
			from dictionary.tables
			where libname="%upcase(&lib)" 
				%if %superq(dataset) ne %then and memname in ("%upcase(&dataset)");
				;
	quit;
	ods html close;
	ods tagsets.excelxp file="&file" style=normal;
	data _null_;
		set _temp;
		call insert_excel(libname, memname);
	run;
	ods tagsets.excelxp close;
	ods html;
%mend get_matelen;
