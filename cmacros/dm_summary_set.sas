/* ******************************************************
* macro dm_summary_set: create dm report dataset for report.
* usage: call by customnized call routine dm_summary_set().
* parameters
* setname: the name of the dm dataset; character
* varlist: the dm dataset variables list which planned to report; character
* 			the variables order in the dm report follow the same order in this list. 
* 			the group variable in report dataset could be used to change this order.
* class: grouping variable including both character and numerice variables, 
		usually be arm/trtp armcd/trtpn; character
* analylist: required statistic data specified for the numeric variables; character
* ********************************************************/
%macro dm_summary_set /minoperator;
	%let setname=%upcase(%sysfunc(compress(&setname,"'"))); 
	%let name=&setname;
	%let _varlist = %upcase(%sysfunc(tranwrd(&varlist, %str( ), %str(','))));
	%let varlist=%upcase(%sysfunc(compress(&varlist,"'"))); 
	%let class=%upcase(%sysfunc(compress(&class,"'"))); 
	%let classc=%scan(&class, 1, %str( ));
	%let class	= %scan(&class, 2, %str( ));
	%let group = 1;
	%let analylist = %sysfunc(compress(&analylist,"'"));
	ods select none;

	/*resolve varlist, create new variables*/
	%let varnum = 0;
	%do %until (&var =);
		%let varnum = %eval(&varnum + 1);
		%let var=%scan(&varlist, &varnum);
		%let var&varnum = &var;
	%end;
	%let varnum = %eval(&varnum - 1);

	/*resolve analylist, create new variables*/
	%let anpnum = 0;
	%let anplist = %str( );
	%do %until (&analyp=);
		%let anpnum = %eval(&anpnum + 1);
		%let analyp=%scan(&analylist, &anpnum);
		%if &analyp ne  %then %let anplist = %quote(&anplist &analyp=&analyp);
	%end;
	%let anplist=%unquote(&anplist);
	%let anpnum = %eval(&anpnum - 1);

	/*add total value*/
	proc sql noprint;
		select  count(usubjid), count(distinct trtpn)
			into :nobs, :trtlevel
			from &setname;
	quit;

	%let trtlevel=%left(&trtlevel);
	data _&setname;
		set &setname;
		output;
		&class = &trtlevel;
		&classc="Total";
		output;  
	run;

	/*distribution check for numeric variables*/
	ods output TestsForNormality = _normality;
	proc univariate data=&setname normal;
	run;
	ods output close;

	data _null_;
		set _normality;
		where varname in (&_varlist) and 
		/*select methord basing the obs number*/
		testlab = 	%if %eval(&nobs < 2000) %then "W"; 
				%else "D";
				;
		call symputx(trim(varname)||"pval", pvalue);
	run;

	/* create the dataset for dm report*/
	%do i=1 %to &varnum;
		%let variable = &&var&i;
		%if %symexist(&variable.pval) %then
			/*the anplist incudes "=", so, using quote*/
			%get_dm_statistic(&setname, &class, &variable, &&&variable.pval, "&anplist", &anpnum );
		%else %get_dm_statistic(&setname, &class, &variable);
		%if %sysfunc(exist(dmreport)) %then %do;
			proc append base=dmreport data=_&setname.temp;
			run; 
			%end;
		%else %do;
			proc datasets;
				change _&setname.temp=dmreport;
			run; quit;
			%end;
/*		%if %sysfunc(exist(label)) %then %do;
			proc datasets;
			run; quit;
			%end;*/
		%let group=%eval(&group+1);
	%end;
	ods select all;
%mend dm_summary_set;
