/* *********************************************************************
* macro BinAssign:  If there are numeric variables can not be discretized by proc split, 
* 	this macro assign binning value to each value of those variables. 
* dn: dataset;
* target: target variable;
* pdn: variable meta data set. The default is vars;
* code_pth: group code output path. The default is outfiles folder under the project folder;
* *********************************************************************/
%macro BinAssign(dn,pdn=vars, varlist=, code_pth=);
	options nonotes;

	%if %superq(dn)= %then %do;
		%put ERROR: The analysis dataset or variable description dataset is missing ;
		%return;
	%end;
	%if %superq(code_pth)=  %then %let code_pth=&pout;
	%if %superq(varlist)^= %then %StrTran(varlist);

	proc sql noprint;
		select name 
		into :bs_var1-:bs_var999
		from &pdn
		%if %superq(varlist)= %then where excluded=1%str(;);
		%else where upcase(name) in (%upcase(&varlist));
		%let bs_nvars=&sqlobs;

		%if %sysfunc(exist(bin_code_n2n)) %then drop table bin_code_n2n; ;
	quit;

	%do i=1 %to &bs_nvars;
		proc sql noprint;
			create table work.tmp_cde
			select distinct &&bs_var&i as value, "&&bs_var&i" as name length=32, 
				"b_"||substr(var, 1, 30) as d_var length=32, 
				count(calculated value) as bin length=3, 
				"if &&bs_var&i="||calculated value||" then "||calculated d_var||"="||bin
			from &dn;
		quit;

/*		data work.tmp_cde;
			length code $200 var d_var $32;
			retain var d_var;
			%do j=1 %to &sqlobs;
				%if &j=1 %then %do;
					bin=-1;
					var="&&bs_var&i";
					d_var="bin_"||substr(var, 1, 28);
					code="if &&bs_var&i=. then "||trim(d_var)||"=-1;";
					output;
				%end;
				bin=&j;
				code="else if &&bs_var&i=&&bs_val&j then "||trim(d_var)||"=&j;";
				output;
			%end;
		run;*/

		proc append base=bin_code_n2n data=work.tmp_cde;
		run;
	%end;

	%if %sysfunc(exist(bin_code_n2n)) %then %do;
	filename code "&code_pth.bin_code_n2n.txt";
	data _null_;
 		set bin_code_n2n;
		rc=fdelete("code");
		file code lrecl=32767;
		put code;
 	run;

	proc sql noprint;
		update &pdn set excluded=1 where name in (
			select distinct name from bin_code_n2n);

		create table work.tmp_vars as
		select distinct d_var as name, "num" as type length=4, "interval" as class,
			1 as derive_var length=3, 1 as woe length=3, name as ori_woe 
		from bin_code_n2n;
	quit;

	proc sort data=work.tmp_vars nodupkey dupout=work.dup;
		by name;
	run;
	proc sort data=&pdn;
		by name;
	run;

	data &pdn;
		update &pdn work.tmp_vars;
		by name;
	run;
	options notes;

	%if %sysfunc(nobs("work", "dup")) %then %do;
		%put ERROR: There are duplicated name;
		proc datasets  lib=work noprint;
			delete dup;
		run;
		quit;
	%end;
	%put NOTE: == Macro BinAssign running completed ==;
%mend BinAssign;
