/*	******************************************************************************************
* 	Macro BinVars: discretize the interval variables and collaspsing the levels of 
* 	the ordinal and nominal variables.
* 	dn: dataset name of which will be access
* 	pdn: dataset name of which store the variables description info.
* 	target: target variable;
* 	varlist: The list of variables which will be discretized 
* 	outdn: the name of output dataset. The default is bin
* 	branch: define which sub macro would be call, could be hps, spl, opt, clu, and all;
* 	pos: the positive value of the target varialbe. The default is 1;
* 	Leafsize: leaf node minimum size for hps and spl. It should be more than 5% of obs. 
* 	The following 3 parameter is for opt sub macro:
* 	nbins: Maximum number of bins
* 	Acc: the accuracy level definition of the bin. The value is between 0 and 1.The smaller the 
		Acc value, the longer it takes, but the higher the accuracy of the result.
* 	method:  1=Gini  2=Entory  3=Pearson's Chi2  4=Information Value 
* 	*****************************************************************************************/
%macro BinVars(dn, pdn=vars, target=, varlist=, leafsize=, outdn=, branch=, 
	method=, nbins=, acc=, pos=1)/minoperator;
	%if %superq(dn)= or (%superq(target)= and  %sysfunc(exist(&pdn))=0 ) %then %do;
		%put ERROR: ==== Parameter error. ====;
		%put ERROR: The analysis dataset, and the info. of analysis dataset or target variable are required ;
		%return;
	%end;
	%local interval ordinal nominal nom t_type t_class desc_len var nvars;
	options nonotes noquotelenmax ;
	%if %superq(varlist)^= %then %StrTran(varlist);
	%if %superq(branch)= or %upcase(&branch)=SPL or %upcase(&branch)=HPS %then %do;
		%if %superq(leafsize)= %then %do;
			data _null_;
				set &dn nobs=obs;
				leafsize=ceil(obs*0.05);
				call symputx("leafsize", leafsize);
				stop;
			run;
		%end;
		%else %do;
			data _null_;
				set &dn nobs=obs;
				if &leafsize <obs*0.05 then put "WARNING: The leafsize is less than 5% of total obs";
				stop;
			run;
		%end;
	%end;

	%if %superq(outdn)= %then %let outdn=bin;

	proc sql noprint;
 		
		select type, class%if %superq(target)= %then, variable;
		into :t_type, :t_class%if %superq(target)= %then, :target;
		from &pdn where target not is missing%str(;) ;

		select ifc(class="interval", variable, "") , ifc(class="ordinal", variable, "") , 
				ifc(class="nominal", variable, "")  
		into :interval separated by " ", :ordinal separated by " ", :nominal separated by " "
		from &pdn
		where target is missing and derive_var is missing and exclude is missing
			and nlevels>2 
		%if  %superq(varlist) ^= %then and upcase(variable) in (%upcase(&varlist));
		;

		%if %existsVar(dn=&pdn, var=description)>0 %then
		select length into :desc_len
		from dictionary.columns
		where libname="%upcase(&pname)" and memname="%upcase(&pdn)" 
			and upcase(name)="DESCRIPTION"%str(;) ;

		%if %sysfunc(exist(&outdn))=0 %then %do;
			create table &outdn (
				variable char(32) label='Original Variable',
				class char,
				d_var char(32) label='Derived Variable',
				border num label='Bin Border',
				cluster char(1000) label='Char Value Group',
				bin num,
				nlevels num,
				ori_nlevels num,
				branch char(8) 
				%if %superq(desc_len)^= %then , description char(&desc_len);
				);
		%end;
		create table work.bv_tree (
			variable char(32),
			class char(8),
			d_var char(32),
			border num,
			cluster char(1000),
			bin num,
			nlevels num,
			branch char(8)
			);
	quit;

	%if %superq(branch)= %then %do;
		%binsplit()
		%binhpsplit()
		%binopt()
		%clunom()
	%end;
	%else %if %upcase(&branch)=HPS %then %binhpsplit();
	%else %if %upcase(&branch)=OPT %then %binopt();
	%else %if %upcase(&branch)=SPL %then %binsplit();
	%else %if %upcase(&branch)=CLU %then %clunom();

	proc sql;
		create table work.bv_tree2 as 
		select a.*,  ori_nlevels %if %superq(desc_len)^= %then, b.description;
		from (select * from work.bv_tree) as a left join 
			(select variable, nlevels as ori_nlevels, description from &pdn) as b on a.variable=b.variable
		order by variable;
	quit;

	data work.bv_tree2;
		set work.bv_tree2;
		by variable;
		if missing(nlevels) then do;
			ori_nlevels=.;
			%if %superq(desc_len)^= %then description=" "%str(;);
		end;
	run;

	%if %sysfunc(nobs(work, bv_tree))  %then %do;
		proc append base=&outdn data=work.bv_tree2;
		run;
	
		proc sort data=&outdn;
			by variable branch border bin;
		run;
	
		proc sql;
			delete from work.bv_tree;

			title "Result of variables discretization and collaspsing";
			select distinct variable, max(nlevels) as nlevels, 
				max(ori_nlevels) as ori_nlevels, branch
			from &outdn 
			group by variable;
			title;
		quit;
	%end;
	%else %do;
		options notes;
		%put NOTE: ==  No variable has been binned ==;
		options nonotes;
	%end;

	proc datasets lib=work noprint;
	   delete bv_: hp_: bo_: bs_: cn_:;
	run;
	quit;

	options notes quotelenmax;

	%if %superq(branch)= %then
	%put NOTE:  ==== Result stored in dataset bin_hps, bin_spl, bin_opt, and bin_clu====;
	%else %put NOTE:  ==== Result stored in &outdn dataset ====;
	%put NOTE:  ==== Macro BinVars excuting complete ====;

%mend BinVars;
