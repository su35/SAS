/* *****************************************************************************************
* macro DMSummarySet: create DM report dataset for report.
* parameters
* 	dn: the name of the dm dataset; character
* 	varlist: the dm dataset variables list which planned to report; character
* 			the variables order in the dm report follow the same order in this list. 
* 			the group variable in report dataset could be used to change this order.
* 	class: grouping variable including both character and numerice variables, 
			usually be arm/trtp armcd/trtpn; character
*	 analylist: required statistic data specified for the numeric variables; character
* *****************************************************************************************/
%macro DMSummarySet(dn, varlist=, class=, analylist=) /minoperator;
	%local i group classc varnum stanum staname stalist nobs trtlevel;
	%if %superq(dn)= %then %let dn=addm; 
	/*The variable name will be upcase when the variables are refered in statistic table */
	%let class=%upcase(&class);
	%let varlist=%upcase(&varlist);
	%let classc=%scan(&class, 1, %str( ));
	%let class	= %scan(&class, 2, %str( ));
	%let group = 1;
	ods select none;
	options nonotes;

	/*count the variable number and required statistic number*/
	%let varnum = %VarsCount(&varlist);
	%let stanum = %VarsCount(&analylist);
	%do i=1 %to &stanum;
		%let staname=%scan(&analylist, &i);
		%let stalist=&stalist &staname=&staname;
	%end;

	/*add total value, and delete dmreport dataset*/
	proc sql noprint;
		select  count(usubjid), put(count(distinct &class), 1.)
			into :nobs, :trtlevel
			from &dn;
		%if %sysfunc(exist(dmreport)) %then drop table dmreport; ;
	quit;

	data work._&dn;
		set &dn;
		output;
		&class = &trtlevel;
		&classc="Total";
		output;  
	run;

	/*distribution check for numeric variables*/
	ods output TestsForNormality = work._normality;
	proc univariate data=&dn normal;
	run;
	ods output close;

	%StrTran(varlist)
	data _null_;
		set work._normality;
		where varname in (&varlist) and 
		/*select methord basing the obs number*/
		testlab = 	%if %eval(&nobs < 2000) %then "W"; 
				%else "D";
				;
		call symputx(trim(varname)||"pval", pvalue);
	run;

	%StrTran(varlist)
	/* create the dataset for dm report*/
	%do i=1 %to &varnum;
		%let variable = %scan(&varlist, &i, %str( ));
		%GetDMStatistic()
		proc append base=dmreport data=work._&dn.temp;
		run; 
		%let group=%eval(&group+1);
	%end;
	options notes;
	ods select all;
	%put NOTE:  ==The dataset dmreport was created.==;
	%put NOTE:  ==The macro DMSummarySet executed completed.== ;
%mend DMSummarySet;

%macro GetDMStatistic();
	%local i cellmin;
	%if %symexist(&variable.pval) %then %do; /*numeric variable*/
		%if  %eval(&&&variable.pval>=0.05) %then %do; /*normal*/
			ods output equality=work._ppvalue ttests=work._pvalue;
			proc ttest data=&dn;
				class &class;
				var &variable;
			run;
			ods output close;
			data _null_;
				set work._ppvalue;
				if probf < 0.05 then call symputx("method" , "SATTERTHWAITE");
				else call symputx("method" , "POOLED");
			run;
			data _null_;
				set work._pvalue;
				where  upcase(method)=symget("method");
				call symputx("&variable"||"pval", probt);
			run;
			%end;
		%else %if  %eval(&&&variable.pval<0.05) %then %do; /*abnormal*/
			proc npar1way  data = &dn   wilcoxon   noprint;
				class &class;
				var &variable;
				output out = work._pvalue wilcoxon;
			run;
			data _null_;
				set work._pvalue;
				call symputx("&variable"||"pval", P2_wil);
			run;		
			%end;	
		proc sort data=work._&dn; 
		        by &class;
		  run;

		  proc univariate data=work._&dn noprint; 
		        by &class;
		        var &variable;
		        output out=work._&dn.temp &stalist;
		  run;

		  proc transpose data=work._&dn.temp name = term 
							out=work._&dn.temp(drop=_LABEL_) prefix=ori; 
		        id &class;
		  run;

		data work._label;
			length term $ 50 pvalue $ 8;
			term = "&variable";
			pvalue =put (&&&variable.pval, d5.3-R);
		run;

		data work._&dn.temp;
		      length  group 3 term $ 50 &class.0-&class.&trtlevel $20 ;
			set work._label  work._&dn.temp;
			array ori(*)  ori0-ori&trtlevel;
			array tar(*) $ &class.0-&class.&trtlevel;
			label pvalue= "P_value" term="Term";
			group =&group;
			if _n_ >1 then do;   
				select(term);
					when('n') do;
						term= "&blankno"||'N';
						do i=1 to dim(ori);
							tar[i]=put(ori[i], 8.-L);
						end;
					end;
					when('mean') do;
						term= "&blankno"||'Mean';
						do i=1 to dim(ori);
							if find(ori0, ".") then tar[i]=put(ori[i], 8.1-L);
							else tar[i]=put(ori[i], 8.-L);
						end;
					end;
					when('std') do;
						term= "&blankno"||'Standard Deviation';
						do i=1 to dim(ori);
							tar[i]=put(ori[i], 8.2-L);
						end;
					end;
					when('min') do;
						term= "&blankno"||'Minimum';
						do i=1 to dim(ori);
							if find(ori0, ".") then tar[i]=put(ori[i], 8.1-L);
							else tar[i]=put(ori[i], 8.-L);
						end;
					end;
					when('max') do;
						term= "&blankno"||'Maximum';
						do i=1 to dim(ori);
							if find(ori0, ".") then tar[i]=put(ori[i], 8.1-L);
							else tar[i]=put(ori[i], 8.-L);
						end;
					end;
					when('median') do;
						term= "&blankno"||'Median';
						do i=1 to dim(ori);
							if find(ori0, ".") then tar[i]=put(ori[i], 8.1-L);
							else tar[i]=put(ori[i], 8.-L);
						end;
					end;
					otherwise  put "WARNING: The format for " term " was not difined"; 
				end;
			end;
			keep term group &class.0-&class.&trtlevel pvalue;
		run;

	%end;
	%else %do; /*char variable*/
		proc freq data=&dn noprint;
			where &class ne . and &variable ne "";
			table &variable*&class /chisq outpct out=work._ptemp; /*Itls the option outpct，not the statement output*/
			output out= work._pvalue pchi;
		run;
		proc sql noprint;
			select min(count) into : cellmin
				from work._ptemp;
		quit;
		%if &cellmin < 5 %then %do;
		/*there are some counts less than 5, get fisher pvalue */
			proc freq data=&dn noprint;
				where &class ne . and &variable ne "";
				table &variable*&class /exact ;
				output out= work._pvalue exact;
			run;
			data _null_;
				set work._pvalue;
				call symputx("&variable"||"pval", xp2_fish);
			run;
			%end;
		%else %do;
			data _null_;
				set work._pvalue;
				call symputx("&variable"||"pval", P_PCHI);
			run;
			%end;
	
		proc freq data=work._&dn noprint;
			where &class ne .;
			table &class*&variable / missing outpct out=work._&dn.temp; 
		run;

		/* Save the names that would be generated by following proc transpose into the macro variables 
		for variable order controlling.*/
		data work._&dn.temp;
			set work._&dn.temp;
			by &class;
			where &variable ne "";
			length value $ 20; /*those values will store in trtpn0 - trtpnN*/
			value=left(put(count,4.)||' ('||put(pct_row,5.1)||'%)');
		run;
		proc sort data=work._&dn.temp; 
			by &variable;
		run;
		proc transpose data=work._&dn.temp 
							out=work._&dn.temp(drop=_name_) prefix=&class;
			var value;
			by &variable;
			id &class;
		run;
		data work._label;
			length term $ 50 pvalue $ 8;
			term = "&variable";
			pvalue =put(&&&variable.pval, d5.3-R);
		run;

		data work._&dn.temp; 
			length  group 3  term $ 50 &class.0-&class.&trtlevel $ 20; /*define the variable order in the dataset*/
			set work._label work._&dn.temp;
			label pvalue= "P_value" term="Term";
			group =&group;
			keep term &class.0-&class.&trtlevel pvalue group;
			/*add the indentation for report*/
			if _n_ >1 then term = "&blankno"||&variable;
		run;
	%end;
%mend GetDMStatistic;
