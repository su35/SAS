/* ************************************************************
* macro BinUpdate: read the excel file which has manually bin combination info.  if type=num then
* 	update the border of interval variable, otherwise update the pdn and output 
* 	the code for re-bin .
* dn: dataset name of which will be access
* pdn: dataset name of which store the variables description info.
* type: define the update type
* path: code output path. The default is outfiles folder under the project folder;
* ************************************************************/
%macro BinUpdate(dn, pdn=vars, path=, type=, varlist=);
	%if %superq(dn)= %then %do;
		%put ERROR: ===== The dataset name is missing. ======;
		%return;
	%end;
	%if %superq(path)= %then %let path=&pout;
	%local bu_data;
	%if %sysfunc(fileexist(&path.&dn..xlsx)) %then %let bu_data=&pout.&dn..xlsx;
	%else %if %sysfunc(fileexist(&path.&dn..xls)) %then %let bu_data=&pout.&dn..xls;
	%else %do;
		%put ERROR: ======= The excel file does not exist ===========;
		%return;
	%end;
	%if &type=border %then %BinUpdate_border(&dn, &bu_data);
	%else  %BinUpdate_woe(&bu_data, &pdn);
	options notes;
	%put NOTE: == Macro BinUpdate running completed ==;
%mend BinUpdate;
%macro BinUpdate_border(dn, data);
	%put NOTE: == Update the border in &dn from &data ==;

	proc import datafile= "&data"  out=&dn(keep=variable d_var border nlevels) dbms=excel replace;
		getnames=yes;
	run;
	options varlenchk=nowarn;
	data &dn;
		length variable d_var $32;
		set &dn(rename=(variable=_var));
		variable=_var;
		drop _var;
	run;
	options varlenchk=warn;
%mend BinUpdate_border;

%macro BinUpdate_woe(data, pdn);
	%put NOTE: == Update &pdn from &data, result will be stored in &pout.BinUpdate.txt ==;
	options varlenchk=nowarn;
	options nonotes;
	proc import datafile= "&data"  out=work.tmp_excel(
		%if %superq(varlist)^= %then %do;
			%StrTran(varlist)
			where=(variable in (&varlist))%str( )
		%end;
			keep=variable bin newbin exclu) dbms=excel replace;
		getnames=yes;
	run;
	data work.tmp_excel(rename=(_newbin=newbin _exclu=exclu));
		length variable d_var $32 _newbin _exclu 3.;
		set work.tmp_excel;
		if vtype(newbin)="C" then _newbin=input(newbin, 3.);
		else _newbin=newbin;
		if vtype(exclu)="C" then _exclu=input(exclu, 3.);
		else _exclu=exclu;
		if upcase(scan(variable, 1,"_")) in ("B","C","CL") then d_var=variable;
		else d_var="c_"||substr(variable, 1, 30);
		drop newbin exclu;
	run;

	options varlenchk=warn;
	%local bn_ori bn_nobs;
	proc sql noprint;
		/*select the variables that need to be re-binning and new clustered
		select trim(ori_bin)
			into :bn_ori separated by " "
			from (select distinct variable from work.tmp_excel where not missing(newbin))
			as a left join (select variable, ori_bin from &pdn) as b
			on a.variable=b.variable;*/ 
		
		update &pdn set excluded=1 where variable in 
				(select distinct variable from work.tmp_excel where exclu=1);
	quit;

	proc sort data=work.tmp_excel;
		by variable bin;
		where not missing(newbin);
	run;
	proc sql noprint;
		select nobs into :bn_nobs
		from dictionary.tables where libname="WORK" and memname="TMP_EXCEL";
	quit;

	%if &bn_nobs>0 %then %do;
		data BinUpdate;
			set work.tmp_excel;
			by variable;
			length code $200;
			if first.variable then code="select ("||trim(variable)||"); when ("||trim(left(bin))||") "||trim(d_var)||"="||trim(left(newbin))||";"; 
			else if last.variable=0 then code="when ("||trim(left(bin))||") "||trim(d_var)||"="||trim(left(newbin))||";";
			else code="when ("||trim(left(bin))||") "||trim(d_var)||"="||trim(left(newbin))||";end;";
		run;

		proc sql;
			create table work.tmp_newbin as
			select a.d_var as variable length=32, 	"num" as type length=4, 
			case when nlevels=2 then "binary" else class end as class, nlevels length=3,
			1 as derive_var  length=3,  
			case when not missing(ori_bin) then ori_bin else a.variable end as ori_bin length=32
			from (select variable, d_var, max(newbin) as nlevels 
					from work.tmp_excel group by variable) as a left join
				(select variable, class, ori_bin from &pdn) as b on a.variable=b.variable;

			update &pdn set excluded=1 where variable in 
				(select ori_bin from work.tmp_newbin);
		quit;

		proc sort data=&pdn;
			by variable;
		run;
		proc sort data=work.tmp_newbin;
			by variable;
		run;

		data &pdn;
			update &pdn work.tmp_newbin;
			by variable;
		run;

		%if %sysfunc(exist(BinUpdate)) %then %do;
			filename code "&pout.BinUpdate.txt";
			data _null_;
				set BinUpdate;
				rc=fdelete("code");
				file code lrecl=32767;
				put code;
			run;
		%end;
	%end;
	%else %do;
		options notes;
		%put NOTE: == There is no update ==;
	%end;
%mend BinUpdate_woe;
