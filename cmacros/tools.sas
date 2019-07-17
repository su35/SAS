/* ***************************************
* Include frequently used small macro
* ***************************************/
/*macro cleanLib: remove the temporary dataets*/
%macro cleanLib(lib);
	proc datasets %if not(%superq(lib)=) %then lib=&lib; 
					noprint;
		delete empty: _: temp_: tmp_:;
	run;
	quit;
%mend cleanLib;
/* ***************************************************************
*	macro str_tran
*	add or remove the quotation marks surrounding variables
*	list: the name of the macro variable 
* ****************************************************************/
/*delet global macro variables*/
%macro DelMvars() /minoperator;
	proc sql noprint;
		select distinct name
			into :cleanlist separated by ' '
			from sashelp.vmacro
			where scope = 'GLOBAL' and substr(name,1,3) ne 'SYS'  and substr(name,1,3) ne 'SQL'  
					and name not in("MVARCLEAN","PDIR","PNAME","PROOT","POUT");
	quit;
	%str(%symdel &cleanlist);
	%put NOTE: The global macro variables were deleted;
%mend;
/*transfer a list of variables between with quotes and without quotes.
* the "list" is the name of a variable or a macro variable which value is a char list*/
%macro StrTran(list);
	%if %index(&&&list, %str(%")) or %index(&&&list, %str(%')) %then 
		%let &list=%cmpres(%sysfunc(prxchange(s/[^\w_]/%str( )/i, -1, &&&list)));
	%else %do;
		%let &list=%cmpres(&&&list);
		%let &list="&&&list";
		%let &list=%sysfunc(tranwrd(%sysfunc(compbl(&&&list)), %str( ),%str(" ")));
		%end;
%mend;
/*output data from a dataset to excel file*/
%macro ToExcel(dataset, file=, sheet=); 
	%if %superq(file)^= %then %do;
		%let point=%sysfunc(find(&file,/, -100));
		%if &point=0 %then %let point=%sysfunc(find(&file,\, -100));
		%if &point %then %do;
			%let outfile=&file;
			%let dn=%substr(&file, %eval(&point+1) );
		%end;
		%else %do;
			%let outfile=&pout.&file;
			%let dn=&file;
		%end;
		%let point=%sysfunc(find(&dn,'.', -100));
		%if &point %then %do;
			%let dn=%substr(&dn, 1, %eval(&point-1));
			%let outfile=%substr(&dn, 1, %eval(&point-1));
		%end;
	%end;
	%else %do;
		%let point=%index(&dataset, %str(.));
		%if &point %then %let dn=%substr(&dataset, %eval(&point+1) );
		%else %let dn=&dataset;
		%let outfile=&pout.&dn;
	%end;
	%if %superq(sheet)= %then %let sheet=&dn;
	proc export data=&dataset outfile="&outfile" DBMS=xlsx replace;
		sheet="&sheet";
	run;
%mend;
/*  macro VarsCount. return the number of variables in a list. the vlist is the value*/
%macro VarsCount(vlist);
	%let nVars=%eval(%length(%sysfunc(compbl(&vlist)))-%length(%sysfunc(compress(&vlist))) +1);
	&nVars
%mend  VarsCount;
/* Check if a variable exists in the data set. If it exists, return its position, else return 0. */
%macro existsVar(lib=, dn=, var=);
	%local dsid check rc;
	%if %superq(lib)= %then %let lib=&pname;
	%let dsid = %sysfunc(open(&lib..&dn));
	%if &dsid=0 %then %put %sysfunc(sysmsg());                                                                                                             
	%else %let check = %sysfunc(varnum(&dsid, &var));
	%let rc = %sysfunc(close(&dsid));
	&check
%mend existsVar;
%macro c2n(dn, vlist);
	%local i n var rename;
	%let n=%VarsCount(&vlist);
	data &dn;
		set &dn;
		%do i=1 %to &n;
			%let var=%scan(&vlist, &i, %str( ));
			&var.n=input(&var, 3.);
			%let rename=&rename &var.n=&var;
		%end;
		drop &vlist;
		rename &rename;
	run;
%mend;
/* ====== macro call by customize function ====== */

/* macro nobs: check if is the dataset empty */
%macro nobs;
	proc sql noprint;
		select nobs into :record
		from dictionary.tables where libname=upcase(&lib) and memname=upcase(&dn);
	quit;
%mend nobs;
/* macro var_length: get the real max length for given variable */
%macro var_length;
	%let lib = %sysfunc(compress(&lib,"'"));
	%let var = %sysfunc(compress(&var,"'"));
	%let dn = %sysfunc(compress(&dn,"'"));
	proc sql noprint;
		select max(length(&var)) into :len
		from &lib..&dn;
	quit;
%mend var_length;
