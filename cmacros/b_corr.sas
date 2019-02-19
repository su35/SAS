/* *********************************************************
	macro b_corr
	correlation analysis between a binary target variable 
	and independent variables.  
	dn: the dataset that the variables need analysis
	y: the binary target variable
	dpara: meta-dataset of the dn. the default is vars
	para: the name of the variable which recording the result in dpara.
		the default is vars
	p: the α value. the default is 0.05
* **********************************************************/
%macro b_corr(dn, y, dpara, para, p);
	%if %superq(dn)=  or %superq(y)=  %then %do;
			%put ERROR: ==== the dataset or target variable is missing========== ;
			%goto exit;
		%end;
	%if %superq(dpara)=  %then %let dpara=vars;
	%if %superq(para)=  %then %let para=exclude;
	%if %superq(p)=  %then %let para=0.05;

	proc sql noprint;
		select case when class ne "cont" then name else "" end,
				case when normal=0 then name else "" end, 
				case when normal=1 then name else "" end
		into :freq_list separated by " ", 
				:npar_list separated  by " ", 
				:norm_list separated  by " "
		from &dpara
		where name ne "&y" and &para ne 1;
	quit;

	%if %superq(freq_list) ne  %Then %do;
		ods output ChiSq=_pvalue_freq (rename=(table=name  prob=pvalue));
		proc freq data=&dn;
			table &y*(&freq_list) /chisq  norow nocol nopercent;
		run;
		data _pvalue_freq(keep=name pvalue);
			set _pvalue_freq;
			where statistic="Chi-Square";
			name=strip(scan(name, 2, "*"));
		run;
		proc sort data=_pvalue_freq;
			by name;
		run;
	%end;
	%if %superq(npar_list) ne  %then %do;
		proc npar1way data=&dn wilcoxon;
			class &y;
			var &npar_list;
			output out=_pvalue_npar(keep=_var_ p2_wil rename=(_var_=name p2_wil=pvalue)) wilcoxon;
		run;
		proc sort data=_pvalue_npar;
			by name;
		run;
	%end;
	%if %superq(norm_list) ne  %then %do;
		ods output  ttests=_pvalue_norm Equality=_var_equal;
		proc ttest data=&dn;
			class &y;
			var &norm_list;
		run;
		proc sort data=_pvalue_norm;
			by variable;
		run;
		proc sort data=_var_equal;
			by variable;
		run;
		data _pvalue_norm(keep=variable probt rename=(probt=pvalue variable=name));
			merge _pvalue_norm _var_equal;
			by variable;
			if round(probf, 0.00001) >0.5 and variances ='Equal' or 
				round(probf, 0.00001)<0.5 and variances='Unequal'	
			then output;
		run;
	%end;
	ods output close;
	proc sql noprint;
		Update &dpara 
			Set &para=1
		where name in ( 
			%if %superq(freq_list) ne %then select name from _pvalue_freq where pvalue >=&p ;
			%if %superq(npar_list) ne  or %superq(norm_list) ne %then 
				%do;
					union corr 
					%if %superq(npar_list) ne %then 
						%do;
							 select name from _pvalue_npar where pvalue >=&p  
							%if %superq(norm_list) ne %then union corr 
								select name from _pvalue_norm  where pvalue >=&p ; 
						%end;
					%else select name from  _pvalue_norm  where pvalue >=&p ; 
				%end;
			);
	quit;
%exit:
%mend b_corr;


