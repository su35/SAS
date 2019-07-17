/* *********************************************************
*	macro BCorr
*	correlation analysis between a binary target variable 
*	and independent variables.  
*	dn: the dataset that the variables need analysis
*	target: the binary target variable
*	pdn: dataset name of which store the variables description info.
*	p: the α value. the default is 0.05
* **********************************************************/
%macro BCorr(dn, pdn=vars, varlist=, p=0.05);
	%if %superq(dn)= %then %do;
		%put ERROR: The analysis dataset is missing ;
		%return;
	%end;
	proc sql noprint;
		select name into :target from &pdn where target =1; 

		select case when class ne "interval" then name else "" end
				, case when class = "interval" and normal ne 1 then name else "" end 
				, case when normal=1 then name else "" end
		into :freq_list separated by " " 
				, :npar_list separated  by " " 
				, :norm_list separated  by " "
		from &pdn
		%if %superq(varlist)= %then where target ne 1 and excluded ne 1 %str(;) ;
		%else %do;
			%StrTran(varlist);
			where upcase(name) in (%upcase(&varlist));
		%end;

		%if %sysfunc(exist(correlation)) %then drop table correlation; ;
	quit;

	%if %superq(freq_list) ne  %Then %do;
		ods output ChiSq=work.tmp_pvalue_freq (rename=(table=name  prob=pvalue));
		proc freq data=&dn;
			table &target*(&freq_list) /chisq  norow nocol nopercent;
		run;
		data work.tmp_pvalue_freq(keep=name pvalue);
			set work.tmp_pvalue_freq;
			where statistic="Chi-Square";
			name=strip(scan(name, 2, "*"));
		run;
		proc sort data=work.tmp_pvalue_freq;
			by name;
		run;
	%end;
	%if %superq(npar_list) ne  %then %do;
		proc npar1way data=&dn wilcoxon;
			class &target;
			var &npar_list;
			output out=work.tmp_pvalue_npar(keep=_var_ p2_wil rename=(_var_=name p2_wil=pvalue)) wilcoxon;
		run;
		proc sort data=work.tmp_pvalue_npar;
			by name;
		run;
	%end;
	%if %superq(norm_list) ne  %then %do;
		ods output  ttests=work.tmp_pvalue_norm Equality=work.tmp_var_equal;
		proc ttest data=&dn;
			class &target;
			var &norm_list;
		run;
		proc sort data=work.tmp_pvalue_norm;
			by variable;
		run;
		proc sort data=work.tmp_var_equal;
			by variable;
		run;
		data work.tmp_pvalue_norm(keep=variable probt rename=(probt=pvalue variable=name));
			merge work.tmp_pvalue_norm work.tmp_var_equal;
			by variable;
			if round(probf, 0.00001) >0.5 and variances ='Equal' or 
				round(probf, 0.00001)<0.5 and variances='Unequal'	
			then output;
		run;
	%end;
	ods output close;
	proc sql noprint;
		create table correlation as
			%if %superq(freq_list) ne %then %do;
				select * from work.tmp_pvalue_freq
				%if %superq(npar_list) ne  or %superq(norm_list) ne %then %do;
					union corr 
					%if %superq(npar_list) ne %then %do;
						 select * from work.tmp_pvalue_npar  
						%if %superq(norm_list) ne %then union corr 
							select * from work.tmp_pvalue_norm %str(;) ;
						%else %str(;) ; 
					%end;
				%end;
				%else %str(;) ;
			%end;
			%else %if %superq(npar_list) ne %then %do;
				select * from work.tmp_pvalue_npar
				%if %superq(norm_list) ne %then union corr 
					select * from work.tmp_pvalue_norm %str(;) ;
				%else %str(;) ; 
			%end;
			%else select * from work.tmp_pvalue_norm %str(;) ;

		alter table &pdn 
			add correlation num;
	
		Update &pdn 
			Set correlation=1
		where name in ( select name from correlation where pvalue >=&p) ;
	quit;
%mend BCorr;


