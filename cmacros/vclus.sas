/*Reduce redundancy, numeric variables cluste*/
%macro vclus(dn, pdn=vars, target=, vlist=);
	options nonotes;
	%if %superq(dn)= %then %do;
		%put ERROR: The analysis dataset is missing ;
		%return;
	%end;

	%local ncl cluselect;

	proc sql noprint;
		%if %superq(vlist)= %then %do;		
			select trim(variable)
			into : vlist separated by " "
			from &pdn
			where excluded ne 1 and target ne 1 and type="num";
		%end;

		%if %superq(target)= %then
		select variable into :target from &pdn where target =1; ;

		%if %sysfunc(exist(varclusters)) %then drop table varclusters; ;
	quit;

	ods output clusterquality=work.tmp_varclusnum    rsquare=varclusters;
	proc varclus data=&dn maxeigen=.7 short ;
		var &vlist;
	run;
	ods output close;

	data _null_;
		set work.tmp_varclusnum;
		call symputx('ncl',numberofclusters);
	run;

	options notes;

	data varclusters (drop=numberofclusters controlvar) ;
		set varclusters;
		label owncluster="Own Cluster R-squared"
			nextclosest="Next Closest R-squared";
		retain clus_n;
		where numberofclusters=&ncl;
		if not missing(cluster) then 	clus_n=input(substr(cluster,9), 8.);
	run;
/*	proc sort data=varclusters;
		by cluster rsquareratio owncluster nextclosest;
	run;

	options noquotelenmax;
	proc sql ;
		title "Selected variables";
		select variable into :cluselect separated by " "
		from varclusters
		where not missing(cluster);

		%StrTran(cluselect)
		title "Continuous variables, check the linear relation";
		select variable into :recheck separated by " "
		from &pdn
		where variable in (&cluselect) and class="interval";
		title "Clusters";
		select cluster, variable, owncluster, nextclosest, rsquareratio
		from varclusters;
		title;
	quit;
	options quotelenmax;
	options notes;*/
	%put NOTE: === Dataset varclusters was created ===;
%mend;
