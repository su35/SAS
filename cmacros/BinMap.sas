/* ************************************************************
* macro BinMap: apply the computed bin to dataset that will be access
* dn: dataset name of which will be access
* pdn: dataset name of which store the variables description info.
* varlist: The specific variable list that needs to be discretized.
* update: if update the pdn dataset. Insert the bin variabels and set the exclude of the 
			original varialbes to 1.
* code_pth: code output path. The default is outfiles folder under the project folder;
* ************************************************************/
%macro BinMap(dn, varlist=, pdn=vars, update=0,  code_pth=)/minoperator;
	%if %superq(dn)= %then %do;
		%put ERROR: === The bin dataset is required.  ===;
		%return;
	%end;
	%if %superq(code_pth)= %then %let code_pth=&pout;
	options nonotes;
	%if %superq(varlist)^= %then %StrTran(varlist);
	%local i BranchNum BranchList branch;

	proc sort data=&dn out=&dn._code(drop=description) ;
		by variable branch border bin; 
		%if %superq(varlist)^= %then where variable in (&varlist)%str(;);
	run;

	proc sql noprint;
		alter table &dn._code
		add code char(1000);

		select distinct branch into :BranchList separated by " "
		from &dn._code;
	quit;
	%let BranchNum=&sqlobs;

	%do i=1 %to &BranchNum;
		%let branch=%scan(&BranchList, &i, %str( ));
		data work.bm_&dn._code;
			set &dn._code;
			where branch="&branch";
		run;

		data work.bm_&dn._code(drop=tmp tb);
			set work.bm_&dn._code;
			by variable; 
			length code $1000;
			retain tmp;
			if class="nominal" then do;
				code="if "||trim(variable)||" in ("||trim(cluster)||") then "
								||trim(d_var)||"="||left(bin)||"; ";
				if first.variable =0 then code="else "||code;
				output;
			end;
			else do;
				if first.variable then do;
					code="if "||trim(variable)||"=. then "||trim(d_var)||"=-1;";
					bin=-1;
					tb=border;
					border=.;
					output;
					border=tb;
					if border^=. then do;
						code="else if "||trim(variable)||"<="||left(border)||" then "||trim(d_var)||"=1;";
						bin=1;
						output;
						tmp=1;
					end;
					else tmp=0;
				end;
				else do;
					tmp+1;
					bin=tmp;
					code="else if "||trim(variable)||"<="||left(border)||" then "||trim(d_var)||"="||put(bin,3.)||";";
					output;
				end;
				if last.variable then do;
					tmp+1;
					bin=tmp;
					code="else if "||left(border)||"<"||trim(variable)||" then "||trim(d_var)||"="||put(bin,3.)||";";
					border=.;
					output;
				end;
			end;
		run;

		filename code "&code_pth.&dn._&branch._code.txt";
		data _null_;
	 		set work.bm_&dn._code;
			rc=fdelete("code");
			file code lrecl=32767;
			put code;
	 	run;

		proc sql;
			delete from &dn._code
			where branch="&branch" %if %superq(varlist)^= %then and variable in (&varlist);
			;
		quit;

		proc append base=&dn._code data=work.bm_&dn._code force;
		run;
	%end;
	proc sort data=&dn._code;
		by variable branch bin;
	run;

	%if &update=1 %then %do;
		proc sql noprint;
			%if %existsVar(dn=&pdn, var=ori_bin)=0 %then
			alter table &pdn add ori_bin char(32)%str(;);

			create table work.bm_vars as
			select distinct d_var as variable,  "num" as type length=4, 
				ifc(class="nominal", "nominal", "ordinal") as class length=8, 
					max(bin) as nlevels, 1 as derive_var, 1 as bin_var,  variable as ori_bin
			from &dn._code
			group by 1;
		quit;

		proc sort data=work.bm_vars  nodupkey dupout=work.bm_dup;
			by variable;
		run;
		proc sort data=&pdn;
			by variable;
		run;

		data &pdn;
			update &pdn work.bm_vars;
			by variable;
		run;
	%end;
	options notes;
	%put NOTE: == Dataset &dn._code has been created ==;
	%put NOTE: == The code file(s) were stored in &code_pth. ==;
	options nonotes;

	proc datasets lib=work noprint;
	   delete bm_: ;
	run;
	quit;

	options notes;
	%put NOTE: == Macro BinMap running completed ==;
%mend;
