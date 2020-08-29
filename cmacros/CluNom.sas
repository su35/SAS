/* *********************************************************************************************/
* macro CluNom: Discretize the interval variables and collaspsing the levels of 
* the nominal variables by proc cluster ;
/* **********************************************************************************************/
%macro CluNom();
	%local i ncl;
	%if %superq(nominal)^= %then %do;
		%let nvars=%sysfunc(countw(&nominal));
		%do i=1 %to &nvars;
			%let var=%scan(&nominal, &i, %str( ));
			proc fastclus data=&dn(keep=&target &var) maxc=10 nomiss noprint
							out=work.cn_fclus cluster=fcluster;
				var &var;
			run;
			proc means data=work.cn_fclus noprint nway;
				class fcluster;
				var &target;
				output out=work.cn_cluslevels mean=prop;
			run;

			ods exclude  EigenvalueTable  RMSStd  AvDist CccPsfAndPsTSqPlot Dendrogram 
					clusterhistory;
			ods output clusterhistory=work.cn_clusterhis;
			proc cluster data=work.cn_cluslevels  method=ward   outtree=work.cn_tree;
				freq _freq_;
				var prop;
				id fcluster;
			run;
			ods output close;

			proc freq data=work.cn_fclus noprint;
				tables fcluster*&target / chisq;
				output out=work.cn_chi(keep=_pchi_) chisq;
			run;

			data work.cn_cutoff;
				if _n_ = 1 then set work.cn_chi;
				set work.cn_clusterhis;
				chisquare=_pchi_*rsquared;
				degfree=numberofclusters-1;
				if degfree >0 then logpvalue=logsdf('CHISQ',chisquare,degfree);
			run;

			proc sql noprint;
				select NumberOfClusters into :ncl 
				from work.cn_cutoff
				having logpvalue=min(logpvalue); 
			quit;
			proc tree data=work.cn_tree nclusters=&ncl out=work.cn_cluster h=rsq noprint;
				id fcluster;
			run;

			proc sort data=work.cn_cluster(drop=clusname);
				by fcluster;
			run;
			proc sort data=work.cn_fclus(keep=fcluster &var);
				by fcluster;
			run;

			data work.cn_cluster;
				merge work.cn_cluster work.cn_fclus;
				by fcluster;
				drop fcluster;
			run;

			proc sort data=work.cn_cluster(rename=(cluster=bin)) noduplicate;
				by bin &var;
			run;

			data work.cn_cluster;
				length variable d_var $32 class branch $8  cluster $1000;
				set work.cn_cluster end=eof;
				by bin;
				variable="&var";
				class="nominal";
				d_var="c_"||substr(variable, 1, 30);
				border=.;
				retain cluster;
				if first.bin then cluster="";
				cluster=catx(" ", cluster, '"'||trim(left(&var))||'"');
				nlevels=.;
				branch="clu";
				if eof then nlevels=bin;
				drop &var;
				if last.bin;
			run;

			proc sql;
				delete from &outdn
				where variable="&var" and branch="clu";
			quit;

			proc append base=work.bv_tree data=work.cn_cluster force;
			run;
		%end;
	%end;

	%if %superq(interval)^= %then %do;
		%let nvars=%sysfunc(countw(&interval));
		%do i=1 %to &nvars;
			%let var=%scan(&interval, &i, %str( ));
			proc fastclus data=&dn(keep=&target &var) maxc=10 nomiss noprint
						mean=work.cn_mean out=work.cn_fclus cluster=fcluster;
				var &var;
			run;

			ods exclude  EigenvalueTable  RMSStd  AvDist CccPsfAndPsTSqPlot Dendrogram 
					clusterhistory;
			ods output clusterhistory=work.cn_clusterhis;
			proc cluster data=work.cn_mean  method=ward   outtree=work.cn_tree;
				var &var;
				copy fcluster;
			run;
			ods output close;

			proc freq data=work.cn_fclus noprint;
				tables fcluster*&target / nowarn chisq;
				output out=work.cn_chi(keep=_pchi_) chisq;
			run;

			data work.cn_cutoff;
				if _n_ = 1 then set work.cn_chi;
				set work.cn_clusterhis;
				chisquare=_pchi_*rsquared;
				degfree=numberofclusters-1;
				if degfree >0 then logpvalue=logsdf('CHISQ',chisquare,degfree);
			run;

			proc sql noprint;
				select NumberOfClusters into :ncl 
				from work.cn_cutoff
				having logpvalue=min(logpvalue); 
			quit;
			proc tree data=work.cn_tree nclusters=&ncl out=work.cn_cluster h=rsq noprint;
				id fcluster;
			run;

			proc sort data=work.cn_cluster;
				by fcluster;
			run;
			proc sort data=work.cn_fclus;
				by fcluster;
			run;

			data work.cn_cluster;
				merge work.cn_cluster(drop=clusname) work.cn_fclus(keep=fcluster &var);
				by fcluster;
				drop fcluster;
			run;

			proc sort data=work.cn_cluster noduplicate;
				by cluster &var;
			run;

			data work.cn_cluster;
				set work.cn_cluster;
				by cluster;
				if first.cluster;
			run;
			proc sort data=work.cn_cluster(drop=cluster);
				by &var;
			run;

			data work.cn_cluster;
				length variable d_var $32 class branch $8  cluster $1000;
				set work.cn_cluster(rename=(&var=border))  end=eof;
				variable="&var";
				class="interval";
				d_var="b_"||substr(variable, 1, 30);
				cluster=" ";
				bin=.;
				branch="clu";
				if eof then nlevels=_N_;
				if _N_>1;
			run;

			proc sql;
				delete from &outdn
				where variable="&var" and branch="clu";
			quit;

			proc append base=work.bv_tree data=work.cn_cluster force;
			run;
		%end;
	%end;
	%if %superq(ordinal)^= %then %do;
		%let nvars=%sysfunc(countw(&ordinal));
		%do i=1 %to &nvars;
			%let var=%scan(&ordinal, &i, %str( ));
			proc fastclus data=&dn(keep=&target &var) maxc=10 nomiss noprint
						mean=work.cn_mean out=work.cn_fclus cluster=fcluster;
				var &var;
			run;

			ods exclude  EigenvalueTable  RMSStd  AvDist CccPsfAndPsTSqPlot Dendrogram 
					clusterhistory;
			ods output clusterhistory=work.cn_clusterhis;
			proc cluster data=work.cn_mean  method=ward   outtree=work.cn_tree;
				var &var;
				copy fcluster;
			run;
			ods output close;

			proc freq data=work.cn_fclus noprint;
				tables fcluster*&target / nowarn chisq;
				output out=work.cn_chi(keep=_pchi_) chisq;
			run;

			data work.cn_cutoff;
				if _n_ = 1 then set work.cn_chi;
				set work.cn_clusterhis;
				chisquare=_pchi_*rsquared;
				degfree=numberofclusters-1;
				if degfree >0 then logpvalue=logsdf('CHISQ',chisquare,degfree);
			run;

			proc sql noprint;
				select NumberOfClusters into :ncl 
				from work.cn_cutoff
				having logpvalue=min(logpvalue); 
			quit;
			proc tree data=work.cn_tree nclusters=&ncl out=work.cn_cluster h=rsq noprint;
				id fcluster;
			run;

			proc sort data=work.cn_cluster;
				by fcluster;
			run;
			proc sort data=work.cn_fclus;
				by fcluster;
			run;

			data work.cn_cluster;
				merge work.cn_cluster(drop=clusname) work.cn_fclus(keep=fcluster &var);
				by fcluster;
				drop fcluster;
			run;

			proc sort data=work.cn_cluster noduplicate;
				by cluster &var;
			run;

			data work.cn_cluster;
				set work.cn_cluster;
				by cluster;
				if first.cluster;
			run;
			proc sort data=work.cn_cluster(drop=cluster);
				by &var;
			run;

			data work.cn_cluster;
				length variable d_var $32 class branch $8  cluster $1000;
				set work.cn_cluster(rename=(&var=border))  end=eof;
				variable="&var";
				class="ordinal";
				d_var="b_"||substr(variable, 1, 30);
				cluster=" ";
				bin=.;
				branch="clu";
				if eof then nlevels=_N_;
				if _N_>1;
			run;

			proc sql;
				delete from &outdn
				where variable="&var" and branch="clu";
			quit;

			proc append base=work.bv_tree data=work.cn_cluster force;
			run;
		%end;
	%end;
%mend CluNom;
