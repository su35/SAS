/* ************************************************************
* macro WoeMap: apply the computed woe to dataset that will be access
* dn: dataset name of which will be access
* pdn: dataset name of which store the variables description info.
* wdn: dataset name that hold the woe value.
* code_pth: code output path. The default is outfiles folder under the project folder;
* ************************************************************/
%macro WoeMap(dn, wdn=woe_iv, pdn=vars, code_pth=, varlist=);
	%if %superq(dn)= %then %do;
		%put ERROR: ===== The dataset name is missing. ======;
		%return;
	%end;
	%if %superq(code_pth)= %then %let code_pth=&pout;
	options nonotes;
	%if %superq(varlist)^= %then %StrTran(varlist);

	proc sort data=&wdn %if %superq(varlist)^= %then (where=(variable in (&varlist)));
		out=work.tmp_woe (keep= variable bin woe);
		by variable;
	run;
	data woe_code;
		set work.tmp_woe;
		by variable;
		length code $200 d_var $32;
		d_var="w_"||substr(variable, 1, 30);
		if first.variable then code="select ("||trim(variable)||");when ("||trim(left(bin))||") "||strip(d_var)||"="||left(woe)||";"; 
		else if last.variable=0 then code="when ("||trim(left(bin))||") "||strip(d_var)||"="||left(woe)||";";
		else code="when ("||trim(left(bin))||") "||strip(d_var)||"="||left(woe)||";end;";
	run;

	filename code "&code_pth.woe_code.txt";
	data _null_;
		set woe_code;
		rc=fdelete("code");
		file code lrecl=32767;
		put code;
	run;

	proc sql noprint;
		update &pdn set excluded=1 where variable in (
			select distinct variable from woe_code);

		alter table &pdn
			add woe num length=3
			add ori_woe char(32);

		create table work.tmp_vars as
		select distinct d_var as variable, "num" as type length=4, "interval" as class,
			1 as derive_var length=3, 1 as woe length=3, variable as ori_woe label=""
		from woe_code;
	quit;

	proc sort data=work.tmp_vars nodupkey dupout=work.dup;
		by variable;
	run;
	proc sort data=&pdn;
		by variable;
	run;

	data &pdn;
		update &pdn work.tmp_vars;
		by variable;
	run;
	options notes;

	%if %sysfunc(nobs("work", "dup")) %then %do;
		%put ERROR: There are duplicated variable name;
		proc datasets  lib=work noprint;
			delete dup;
		run;
		quit;
	%end;
	%put NOTE: == The dataset woe_code is created, and &pdn have been updated ==;
	%put NOTE: == The file &code_pth.woe_code.txt has been created ==;
%mend WoeMap;
