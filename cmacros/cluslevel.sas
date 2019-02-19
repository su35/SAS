/* *********************************************************
	macro cluslevel
	clustering levels of variables
	dn: the dataset
	y: the target variable
	varlist: the list of the variables of which the level need to cluster.
	suff: the suffix used to create the new variables
	pdn: the output dataset in which the cluster result is stored
* **********************************************************/
%macro cluslevel(dn, y, varlist, suff, pdn);
	%if %superq(dn)=  or %superq(y)=  or %superq(varlist)=  %then %do;
			%put ERROR: parameters dataset name, target variable and indepent variable are required;
			%goto exit;
		%end;
	%if %superq(suff)= %then %let suff=clus;
	%if %superq(pdn)= %then %let pdn=cluslevel;
	%local d;
	%let d = 1;
	%do %while(%scan(&varlist,&d, %str( ))^= );
		%let var=%scan(&varlist,&d,%str( ) );
		proc means data=&dn noprint nway;
			class &var;
			var &y;
			output out=_cluslevels mean=prop;
		run;

		ods output clusterhistory=_cluster;
		proc cluster data=_cluslevels  method=ward   outtree=_fortree;
			freq _freq_;
			var prop;
			id &var;
		run;
		ods output close;

		proc freq data=&dn noprint;
			tables &var*&y / chisq;
			output out=_chi(keep=_pchi_) chisq;
		run;

		data _cutoff;
			if _n_ = 1 then set _chi;
			set _cluster;
			chisquare=_pchi_*rsquared;
			degfree=numberofclusters-1;
			logpvalue=logsdf('CHISQ',chisquare,degfree);
		run;

	/*	proc plot data=cutoff;
		plot logpvalue*numberofclusters/vpos=30;
		run;

		proc means data=_cutoff noprint;
			var logpvalue;
			output out=_small minid(logpvalue(numberofclusters))=ncl;
		run;

		data _small;
			set _small;
			call symputx('ncl',ncl);
		run;*/
		proc sql;
				select NumberOfClusters into :ncl 
				from _cutoff
				having logpvalue=min(logpvalue); 
			quit;
		proc tree data=_fortree nclusters=&ncl out=_clus h=rsq;
			id &var;
		run;

		proc sort data=_clus;
			by cluster;
		run;

		data _null_;
			call execute('proc sql; select');
			do i=1 to &ncl-1;
				if i<&ncl-1 then call execute('case when cluster='||left(i)||' then quote(trim('||"&var"||')) else "" end,');
				else call execute('case when cluster='||left(i)||' then quote(trim('||"&var"||')) else "" end into ');
			end;
			do i=1 to &ncl-1;
				if i<&ncl-1 then call execute(':clus'||left(i)||' separated by " ", ');
				else call execute(':clus'||left(i)||' separated by " " from _clus; quit;');
			end;

			call execute('data &dn; 	set &dn;');
			do i=1 to &ncl-1;
			call execute("&var.&suff"||left(i)||'=('||"&var"||' in (%nrstr(&clus)'||left(i)||'));');
			end;
			call execute('run;');
		run;

		proc print data=_clus;
			by cluster;
			id cluster;
		run;

		data _clus;
			varname ="&var";
			suff="&suff";
			set _clus;
			rename &var=value;
			drop clusname;
		run;

		%if %sysfunc(exist(&pdn))  %then %do;
			proc append base=&pdn data=_clus; 
			run;
			%end;
		%else %do;
			proc datasets noprint;
				change _clus=&pdn;
			run; quit;
		%end;	


	/*	data _null_;
			call execute('data &dn._1; 	set &dn;');
			do i=1 to %eval(&ncl-1);
			call execute("&var"||left(i)||'=('||"&var"||' in (&clus'||left(i)||'));');
			end;
			call execute('run;');
		run;*/
		%let d=%eval(&d+1);
	%end;
%exit:
%mend cluslevel;
