/* ******************************************************
* macro get_dm_statistic: get the statistic value for each variable.
* usage: call by macro dm_summary_set.
* parameters
* setname: the name of the dm dataset; character
* class: grouping variable, usually be armcd/trtpn; numeric
* var: the name of the variable; character
* the following parameters are specified for the numeric variables
* pval: the p_value of normal check; numeric
* anplist:  name list of required statistic data; character
*			if get the format warning, add the format in last block
* anpnum: number of names in anplist; numeric
* ********************************************************/

%macro get_dm_statistic(setname, class, var, pval, anplist, anpnum);
	%local i;
	%let anplist=%sysfunc(compress(&anplist,'"')); 
	%if %superq(pval)= %then %do; /*char variable*/
		proc freq data=&setname noprint;
			where &class ne . and &var ne "";
			table &var*&class /chisq outpct out=_ptemp; /*Itls the option outpct，not the statement output*/
			output out= _pvalue pchi;
		run;
		proc sql noprint;
			select min(count) into : cellmin
				from _ptemp;
		quit;
		%if &cellmin < 5 %then %do;
		/*there are some counts less than 5, get fisher pvalue */
			proc freq data=&name noprint;
				where &class ne . and &var ne "";
				table &var*&class /exact ;
				output out= _pvalue exact;
			run;
			data _null_;
				set _pvalue;
				call symputx("&var"||"pval", xp2_fish);
			run;
			%end;
		%else %do;
			data _null_;
				set _pvalue;
				call symputx("&var"||"pval", P_PCHI);
			run;
			%end;
	
		proc freq data=_&setname noprint;
			where &class ne .;
			table &class*&var / missing outpct out=_&setname.temp; 
		run;

		/* Save the names that would be generated by following proc transpose into the macro variables 
		for variable order controlling.*/
		data _&setname.temp;
			set _&setname.temp;
			by &class;
			where &var ne "";
			length value $ 20; /*those values will store in trtpn0 - trtpnN*/
			value=left(put(count,4.)||' ('||put(pct_row,5.1)||'%)');
		run;
		proc sort data=_&setname.temp; 
			by &var;
		run;
		proc transpose data=_&setname.temp 
							out=_&setname.temp(drop=_name_) prefix=&class;
			var value;
			by &var;
			id &class;
		run;
		data _label;
			length term $ 50 pvalue $ 8;
			term = "&var";
			pvalue =put(&&&var.pval, d5.3-R);
		run;

		data _&setname.temp; 
			length  group 3  term $ 50 &class.0-&class.&trtlevel $ 20; /*define the variable order in the dataset*/
			set _label _&setname.temp;
			label pvalue= "P_value" term="Term";
			group =&group;
			keep term &class.0-&class.&trtlevel pvalue group;
			/*add the indentation for report*/
			if _n_ >1 then term = "&blankno"||&var;
		run;
	%end;
	%else %do; /*numeric variable*/
		%if  %eval(&pval>=0.05) %then %do; /*normal*/
			ods output equality=_ppvalue ttests=_pvalue;
			proc ttest data=&setname;
				class &class;
				var &var;
			run;
			ods output close;
			data _null_;
				set _ppvalue;
				if probf < 0.05 then call symputx("method" , "SATTERTHWAITE");
				else call symputx("method" , "POOLED");
			run;
			data _null_;
				set _pvalue;
				where  upcase(method)=symget("method");
				call symputx("&var"||"pval", probt);
			run;
			%end;
		%else %if  %eval(&pval<0.05) %then %do; /*abnormal*/
			proc npar1way  data = &setname   wilcoxon   noprint;
				class &class;
				var &var;
				output out = _pvalue wilcoxon;
			run;
			data _null_;
				set _pvalue;
				call symputx("&var"||"pval", P2_wil);
			run;		
			%end;	
		proc sort data=_&setname; 
		        by &class;
		  run;

		  proc univariate data=_&setname noprint; 
		        by &class;
		        var &var;
		        output out=_&setname.temp &anplist;
		  run;

		  proc transpose data=_&setname.temp name = term 
							out=_&setname.temp(drop=_LABEL_) prefix=ori; 
		        id &class;
		  run;

		data _label;
			length term $ 50 pvalue $ 8;
			term = "&var";
			pvalue =put (&&&var.pval, d5.3-R);
		run;

		data _&setname.temp;
		      length  group 3 term $ 50 &class.0-&class.&trtlevel $ 20 ;
			set _label  _&setname.temp;
			array ori(*) ori0-ori&trtlevel;
			array tar(*) &class.0-&class.&trtlevel;
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
%mend get_dm_statistic;



