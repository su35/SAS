/*****************************************************************************
* Macro ClustOL:  modified from Credit Risk Scorecards: Development and 
*                                                         Implementation using SAS
* ****************************************************************************/
%macro ClustOL(dn, pdn=vars, VarList=, NClust=, Pmin=5, outdn=clustol);
/* Infering outliers using k-means clustering */
	%if %superq(dn)= or (%superq(varlist)= and  %sysfunc(exist(&pdn))=0)
			%then %do;
		%put ERROR: The analysis dataset or varlist or variable description dataset is missing ;
		%return;
	%end;
	options nonotes;
	%if %superq(varlist)= %then %do;
		proc sql noprint;
			select name 
			into :varlist separated by " "
			from &pdn
			where lowcase(class)="interval";
		quit;
	%end;
	data _null_;
		set train nobs=obs;
		call symputx("nobs",obs);
		stop;
	run;
	%if %superq(nclust)= %then %let nclust=%sysfunc(ceil(&nobs/(&pmin*10)));
	/* Build a cluster model to identify outliers */
	proc fastclus data=&dn maxiter=100 out=work.tmp_clust MaxC=&NClust noprint;
		var &VarList;
	run;

	/* Analyze temp_clust and find the cluster indices with frequency percentage less than Pmin */
	proc freq data=work.tmp_clust noprint;
		tables cluster / out=work.tmp_clusfreqs;
	run;

	data work.tmp_cluslow;
		set work.tmp_clusfreqs;
		if percent <= &Pmin;
		outlier=1;
		keep cluster outlier;
	run;

	/* Match-merge temp_low with the clustering output and drop the cluster index */
	proc sort data=work.tmp_clust;
		by cluster;
	run;
	proc sort data=work.tmp_cluslow;
		by cluster;
	run;

	data &outdn;
		merge work.tmp_clust work.tmp_clusLow;
		by cluster;
		drop cluster distance;
		if outlier=1;
	run;

	/* Cleanup and finish the macro
	proc datasets library=work;
	delete temp_clust temp_freqs temp_low;
	quit; */
	options notes;
%mend;

