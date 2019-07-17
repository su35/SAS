/* *******************************************************************************************
* macro BinVars: Discretize the numeric variables by proc split
* dn: dataset name of which will be access
* pdn: dataset name of which store the variables description info.
* target: target variable;
* varlist: The list of variables which will be discretized 
* Leafsize: leaf node minimum size. It should be more than 5% of obs. The default is 100;
* code_pth: group code output path. The default is outfiles folder under the project folder;
* ******************************************************************/
%macro BinVars(dn, pdn=vars, target=, varlist=, leafsize=100, type=num, outdn=);
	%local bv_nvars i j t_class desc_len;
	%if %superq(dn)= or ((%superq(varlist)= or %superq(target)=) 
			and  %sysfunc(exist(&pdn))=0) %then %do;
		%put ERROR: Parameter error. The info. of analysis dataset, target variable and interval variabels are required ;
		%return;
	%end;
	options nonotes;
	%if %superq(varlist)^= %then %StrTran(varlist);
	%if &type=num or &type=nom %then %do;
		data _null_;
			set &dn nobs=obs;
			if &leafsize <obs*0.05 then put "WARNING: The leafsize is less than 5% of total obs";
			stop;
		run;
	%end;
	proc sql noprint;
		select variable %if &type=num %then , class; 
				%else %if &type=nom %then, type;
		into :bv_var1-:bv_var999 %if &type=num %then, :bv_cla1-:bv_cla999;
				%else %if &type=nom %then , :bv_type1-:bv_type999;
		from &pdn
		%if  %superq(varlist)= %then %do;
			where %if &type=num %then (lowcase(class)="interval" or lowcase(class)="ordinal");
				%else lowcase(class)="nominal";
				and target ne 1 and derive_var ne 1;
		%end;
		%else where upcase(variable) in (%upcase(&varlist))%str(;);
		%let bv_nvars=&sqlobs;

 		%if %superq(target)= %then
		select variable,class 
		into :target, :t_class 
		from &pdn where target =1; ;

		%if %existsVar(dn=vars, var=description)>0 %then
		select length into :desc_len
		from dictionary.columns
		where libname="%upcase(&pname)" and memname="VARS" 
			and upcase(name)="DESCRIPTION"%str(;) ;
	quit;
	%if &type=num %then %bin_num();
	%if &type=nom %then %bin_nom();
	%if &type=clu %then %clu_nom();
	options notes;
	%put NOTE: == Macro BinVars running completed ==;
%mend BinVars;
%macro bin_num();
	%if %superq(outdn) = %then %let outdn=bin_interval;
	%do i=1 %to &bv_nvars;
		proc split data=&dn(keep=&target &&bv_var&i) outtree=work.tmp_tree 
					leafsize=&leafsize criterion=chisq excludemiss;
			input &&bv_var&i/level=&&bv_cla&i;
			target &target/level=&t_class;
		run;
		%if %superq(desc_len)^= %then %do;
			data _null_;
				set vars;
				where variable="&&bv_var&i";
				call symputx("descri", description);
			run;
		%end;

		data work.tmp_tree(rename=(y=border));
			length variable d_var $32 %if %superq(desc_len)^= %then description $&desc_len;
			;
			set work.tmp_tree end=eof;
			where label='<';
			variable="&&bv_var&i";
			d_var="b_"||substr(variable, 1, 30);
			if eof then do;
				nlevels=_N_+1;
				%if %superq(descri)^= %then description="&descri"%str(;);
			end;
			keep variable y nlevels d_var %if %superq(desc_len)^= %then description;
			;
		run;
		proc sort data=work.tmp_tree;
			by border;
		run;

		%if %sysfunc(exist(&outdn)) %then %do;
			proc sql;
				delete from &outdn
				where variable="&&bv_var&i";
			quit;
		%end;
		proc append base=&outdn data=work.tmp_tree force;
		run;
	%end;
	%if %sysfunc(exist(&outdn)) %then %do;
		proc sql;
			select a.variable, bin, ori_levels
			from (select variable, max(nlevels) as bin from &outdn group by variable) as a left join
				(select variable, nlevels as ori_levels from &pdn) as b on a.variable=b.variable;
		quit;
	%end;
	%else %do;
		options notes;
		%put NOTE: ==  No numeric variables has been discretized ==;
		options nonotes;
	%end;
%mend bin_num;
%macro bin_nom();
	%if %superq(outdn) = %then %let outdn=bin_nominal;
	%Local total total_pos total_neg;
	proc sql noprint;
		select sum(case when &target=1 then 1 else 0 end),
				sum(case when &target=0 then 1 else 0 end),
				count(&target)
		into :total_pos, :total_neg, :total
		from &dn (keep=&target);
	quit;
	ods  select none;
	%do i=1 %to &bv_nvars;
		proc sort data=&dn(keep=&target &&bv_var&i) out=work.tmp_&dn;
			by &&bv_var&i;
		run;
		ods output OneWayFreqs=work._freq;
		proc freq data=work.tmp_&dn;
			by &&bv_var&i;
			table &target;
		run;
		ods output close;

		proc sql;
			create table work._freq1 as
			select a.*, b.pos, &total_pos as total_pos, &total_neg as total_neg, &total as total
			from (select distinct &&bv_var&i, sum(Frequency) as Freq 
				from work._freq group by &&bv_var&i) as a left join
				 (select &&bv_var&i,frequency as pos from work._freq where &target=1) as b 
				on a.&&bv_var&i=b.&&bv_var&i;
		quit;
			
		data work._freq1;
			set work._freq1;
			label pos_rate = "Positive Rate(%)";

			if pos=0 then pct_pos=0.5/total_pos;
			else pct_pos=pos/total_pos;
			if pos = freq then pct_neg=0.5/total_neg;
			else pct_neg=(freq-pos)/total_neg;

			pos_rate = pos / freq;
			odds=pct_neg/pct_pos;
			woe = log(odds);
			iv= (pct_neg-pct_pos)*woe;
			format pos_rate 10.4;
		run;

		data work.tmp_woe(drop=&&bv_var&i);
			length variable var_bin %if &&bv_type&i=char %then var_lst;  $40 
				%if &&bv_type&i=num %then var_lst 8; 
				;
			set work._freq1;
			variable="&&bv_var&i";
			var_lst=&&bv_var&i;
			var_bin="&&bv_var&i"||left(&&bv_var&i);
		run;

		proc sql;
			create table work.tmp_&dn as
			select a.&&bv_var&i, a.&target, b.woe
			from &dn as a inner join 
					work.tmp_woe as b 
					on %if &&bv_type&i=char %then upcase(a.&&bv_var&i)=upcase(b.var_lst)%str(;);
					%else a.&&bv_var&i=b.var_lst%str(;);
		quit;

		proc split data=work.tmp_&dn criterion=chisq leafsize=&leafsize outtree=work.tmp_tree excludemiss;
			input woe/level=interval;
			target &target/level=&t_class;
		run;

		data work.tmp_tree(rename=(y=border));
			length variable $32;
			set work.tmp_tree nobs=obs end=eof;
			call symputx("bv_nobs", obs);
			where label='<';
			variable="&&bv_var&i";
			if eof then nlevels=_N_+1;
			keep variable y nlevels;
		run;

		%if %superq(bv_nobs)^= %then %do;
			proc sort data=work.tmp_tree;
				by border;
			run;
			data _null_;
				set work.tmp_tree end=eof;
				retain bin;
				bin=max(bin,nlevels);
				if _N_ =1 then call execute("proc sql; create table work.tmp_bin as
					select  a.*, b.ori_nlevels from (select distinct &&bv_var&i as val, '"||trim(variable)||"' as variable, case");
				call execute(" when "||lag(border)||"<=woe<"||border||" then "||_N_||" ");
				if eof=1 then  call execute("when woe>="||border||" then "||_N_||"+1 
					end as cluster, "||bin||" as nlevels from work.tmp_&dn) as a join
					(select variable, nlevels as ori_nlevels from &pdn where variable='"||trim(variable)||"') as b
					on  a.variable=b.variable; quit;");
			run; 
			proc sort data=work.tmp_bin;
				by cluster;
				where nlevels<ori_nlevels;
			run;

			%if %sysfunc(nobs(work, tmp_bin))^=0 %then %do;
				data work.tmp_bin;
					length variable d_var $32 value $100;
					set work.tmp_bin;
					by cluster;
					d_var="c_"||substr(variable, 1, 30);
					retain value;
					if first.cluster then value="";
					value=catx(" ", value, '"'||trim(left(val))||'"');
					drop val;
					if last.cluster;
				run;

				%if %sysfunc(exist(&outdn)) %then %do;
					proc sql;
						delete from &outdn
						where upcase(variable)=upcase("&&bv_var&i");
					quit;
				%end;
				proc append base=&outdn data=work.tmp_bin;
				run;
			%end;
		%end;
		%let bv_nobs=;
	%end;
	ods select ALL;
	%if %sysfunc(exist(&outdn)) %then %do;
		proc sql;
			select a.variable, bin, ori_levels
			from (select distinct variable, nlevels as bin from &outdn ) as a left join
				(select variable, nlevels as ori_levels from &pdn) as b on a.variable=b.variable;
		quit;
	%end;
	%else %do;
		options notes;
		%put NOTE: ==  No nominal variable has been binned ==;
		options nonotes;
	%end;
%mend bin_nom;

%macro clu_nom();
	%if %superq(outdn) = %then %let outdn=clu_nominal;
	%if %sysfunc(exist(&outdn))= %then %do;
		proc datasets  library=&pname;
			delete &outdn; 
		run; quit;
	%end;

	%do i=1 %to &bv_nvars;
		proc means data=&dn noprint nway;
			class &&bv_var&i;
			var &target;
			output out=work.tmp_cluslevels mean=prop;
		run;
		ods output clusterhistory=work.tmp_cluster;
		proc cluster data=work.tmp_cluslevels  method=ward   outtree=work.tmp_fortree;
			freq _freq_;
			var prop;
			id &&bv_var&i;
		run;
		ods output close;

		proc freq data=&dn noprint;
			tables &&bv_var&i*&target / chisq;
			output out=work.tmp_chi(keep=_pchi_) chisq;
		run;

		data work.tmp_cutoff;
			if _n_ = 1 then set work.tmp_chi;
			set work.tmp_cluster;
			chisquare=_pchi_*rsquared;
			degfree=numberofclusters-1;
			logpvalue=logsdf('CHISQ',chisquare,degfree);
		run;

		proc sql noprint;
			select NumberOfClusters into :ncl 
			from work.tmp_cutoff
			having logpvalue=min(logpvalue); 
		quit;
		proc tree data=work.tmp_fortree nclusters=&ncl out=work.tmp_clus h=rsq noprint;
			id &&bv_var&i;
		run;

		proc sort data=work.tmp_clus;
			by cluster;
		run;

		data work.tmp_clus;
			set work.tmp_clus;
			by cluster;
			variable="&&bv_var&i";
			d_var="cl_"||substr(variable, 1, 29);
			length value $100;
			retain value;
			if first.cluster then value="";
			value=catx(" ", value, '"'||trim(left(&&bv_var&i))||'"');
			drop &&bv_var&i clusname ;
			if last.cluster;
		run;

		%if %sysfunc(exist(&outdn)) %then %do;
			proc sql;
				delete from &outdn
				where upcase(variable)=upcase("&&bv_var&i");
			quit;
		%end;
		proc append base=&outdn data=work.tmp_clus;
		run;
	%end;
	%if %sysfunc(exist(&outdn)) %then %do;
		proc sql;
			select distinct variable, max(cluster) as levels
			from &outdn
			group by variable;
		quit;
	%end;
	%else %do;
		options notes;
		%put NOTE: ==  No nominal variable has been binned ==;
		options nonotes;
	%end;
%mend clu_nom;
