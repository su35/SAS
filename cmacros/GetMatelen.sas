/* ******************************************************************************************
* macro GetMatelen.sas: get the length of the variables and store the data in a xml file
* parameters
* 		lib: specify the libaray
* 		dataset: the name of the original dataset
* 		file: the name of the xml file
* ******************************************************************************************/
%macro GetMatelen(lib=,dataset=, file=);
	%if %superq(lib) = %then %do;
		%if %sysfunc(libref(&pname)) = 0 %then %let lib=&pname;
		%else %let lib=WORK;
	%end;
	%if %superq(dataset) ne %then  %StrTran(dataset);
	%if %superq(file)= %then %let file =&pout.&lib._matelen.xlsx;
	options nonotes;
	proc sql;
		create table work._tmp as
		select memname, name, type, length, format   
		from dictionary.columns 
		where libname="%upcase(&lib)" 
			%if %superq(dataset) ne %then and memname in (%upcase(&dataset));
		order by memname;
		select distinct memname into :mem1-:mem999
		from work._tmp;
	quit;
	%let mnum=&sqlobs;

	%do i=1 %to &mnum;
		data work._tmpm;
			set work._tmp;
			where memname="&&mem&i";
		run;
		proc export data=work._tmpm outfile="&file" DBMS=xlsx replace;
			sheet="&&mem&i";
		run;
	%end;
	options notes;
	%put NOTE: == The &file created. ==;
	%put NOTE: == Macro GetMatelen runing completed. ==;
%mend GetMatelen;
