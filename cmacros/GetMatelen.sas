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
	%local i mem;
	options nonotes;
	proc sql noprint;
		create table work.gm_tmp as
		select memname, name, type, length, format   
		from dictionary.columns 
		where libname="%upcase(&lib)" 
			%if %superq(dataset) ne %then and memname in (%upcase(&dataset));
		order by memname;

		select distinct memname into :memlist separated by " ";
		from work.gm_tmp;
	quit;
	%let mnum=&sqlobs;

	%do i=1 %to &mnum;
		%let mem=%scan(&memlist, &i, %str( ))
		data work.gm_tmpm;
			set work.gm_tmp;
			where memname="&mem";
		run;
		proc export data=work.gm_tmpm outfile="&file" DBMS=xlsx replace;
			sheet="&mem";
		run;
	%end;
	proc datasets lib=work noprint;
	   delete gm_: ;
	run;
	quit;

	options notes;
	%put NOTE: == The &file created. ==;
	%put NOTE: == Macro GetMatelen runing completed. ==;
%mend GetMatelen;
