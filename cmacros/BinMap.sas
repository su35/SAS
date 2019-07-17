/* ************************************************************
* macro BinMap: apply the computed bin to dataset that will be access
* dn: dataset name of which will be access
* pdn: dataset name of which store the variables description info.
* varlist: The specific variable list that needs to be discretized.
* type: The type of variables that needs to be discretized.
* update: if update the pdn
* code_pth: code output path. The default is outfiles folder under the project folder;
* ************************************************************/
%macro BinMap(dn, varlist=, type=, pdn=vars, update=1,  code_pth=)/minoperator;
	%if %superq(dn)= or ((%superq(varlist)= or &update=1) 
			and  %sysfunc(exist(&pdn))=0) or %superq(type)= %then %do;
		%put ERROR: === Parameter error.  ===;
		%return;
	%end;
	%if %superq(code_pth)= %then %let code_pth=&pout;
	options nonotes;
	%if %superq(varlist)^= %then %do;
		%StrTran(varlist)
		proc sql noprint;
			select quote(trim(variable)) 
			into :varlist separated by " "
			from &pdn
			where %if &type=nom %then class="nominal";
				%else class ^="nominal";
				 and variable in (&varlist);
		quit;
	%end;
	%if %sysfunc(exist(bin_code_&type)) %then %do;
		proc datasets  library=&pname noprint;
			delete bin_code_&type;  
		run;
	%end;

	%if &type=num %then %map_num();
	%else %if &type=nom %then %map_nom();
	%else %if &type=opt %then %map_opt();
	%else %if &type=clu %then %map_clu();

	filename code "&code_pth.bin_code_&type..txt";
	data _null_;
 		set bin_code_&type;
		rc=fdelete("code");
		file code lrecl=32767;
		put code;
 	run;
	options notes;
	%put NOTE: == Dataset bin_code_&type has been created ==;
	%put NOTE: == The file &code_pth.bin_code_&type..txt. has been created ==;
	options nonotes;

	%if &update=1 %then %do;
		proc sql noprint;
			update &pdn set excluded=1 where variable in (
				select distinct variable from bin_code_&type);

			%if not %existsVar(dn=&pdn, var=ori_bin) %then
			alter table &pdn add ori_bin char(32)%str(;);

			create table work.tmp_vars as
			select distinct d_var as variable,  "num" as type length=4, 
				%if &type=num or &type=opt %then "ordinal";
				%else "nominal"; as class length=8, 
				%if &type=num or &type=opt %then max(nlevels);
				%else nlevels; as nlevels length=8, 1 as derive_var length=3, variable as ori_bin
			from bin_code_&type;
		quit;

		proc sort data=work.tmp_vars  nodupkey dupout=work.dup;
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
		%put NOTE: == The dataset vars has been updated ==;
	%end;
	%put NOTE: == Macro BinMap running completed ==;
%mend;
%macro map_num();
	proc sort data=&dn;
		by variable border ; 
	run;

	data work.tmp_cde (drop=tmp);
		set &dn;
		by variable; 
		%if %superq(varlist)^= %then where variable in (&varlist)%str(;);
		length code $200;
		retain tmp bin;
		if first.variable then do;
			code="if "||trim(variable)||"=. then "||trim(d_var)||"=-1;";
			bin=-1;
			output;
			code="else if "||trim(variable)||"<"||left(border)||" then "||trim(d_var)||"=1;";
			bin=1;
			output;
		end;
		else do;
			bin+1;
			code="else if "||trim(variable)||"<"||left(border)||" then "||trim(d_var)||"="||put(bin,3.)||";";
			tmp=border;
			output;
		end;
		if last.variable then do;
			bin+1;
			code="else if "||left(border)||"<="||trim(variable)||" then "||trim(d_var)||"="||put(bin,3.)||";";
			output;
		end;
	run;
	proc append base=bin_code_&type data=work.tmp_cde;
	run;
%mend;
%macro map_opt();
	proc sort data=&dn;
		by variable border ; 
	run;

	data work.tmp_cde (drop=tmp);
		set &dn;
		by variable; 
		%if %superq(varlist)^= %then where variable in (&varlist)%str(;);
		length code $200;
		if first.variable then do;
			code="if "||trim(variable)||"=. then "||trim(d_var)||"=-1;";
			bin=-1;
			output;
			code="else if "||trim(variable)||"<="||left(border)||" then "||trim(d_var)||"=1;";
			bin=1;
			output;
		end;
		else do;
			code="else if "||trim(variable)||"<="||left(border)||" then "||trim(d_var)||"="||put(bin,3.)||";";
			tmp=border;
			output;
		end;
	run;
	proc append base=bin_code_&type data=work.tmp_cde;
	run;
%mend;
%macro map_nom();
	proc sort data=&dn;
		by variable cluster ; 
	run;
	data work.tmp_cde;
		length variable d_var $32;
		set &dn;
		by variable cluster; 
		%if %superq(varlist)^= %then where variable in (&varlist)%str(;);
		length code $1000;
		retain code;
		tmp_code="if "||trim(variable)||" in ("||trim(value)||") then "
						||trim(d_var)||"="||left(cluster)||"; ";
		if first.variable then code=tmp_code;
		else code=cats(code, "else "||tmp_code);
		keep variable d_var code nlevels; 
		if last.variable;
	run;
	
	proc append base=bin_code_&type data=work.tmp_cde;
	run; 
%mend;
%macro map_clu();
	proc sort data=&dn;
		by variable cluster ; 
	run;
	data work.tmp_cde(keep= variable d_var code nlevels);
		length variable d_var $32 code $1000 ;
		set &dn;
		by variable; 
		retain code;
		tmp_code="if "||trim(variable)||" in ("||trim(value)||") then "
						||trim(d_var)||"="||left(cluster)||"; ";
		if first.variable then code=tmp_code;
		else code=cats(code, "else "||tmp_code);
		rename  cluster=nlevels;
		if last.variable;
	run;

	proc append base=bin_code_&type data=work.tmp_cde;
%mend ;
