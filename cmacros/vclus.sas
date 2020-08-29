/*Reduce redundancy, numeric variables cluste*/
%macro vclus(dn, pdn=vars, target=, vlist=, g=1);
	options nonotes;
	%if %superq(dn)= %then %do;
		%put ERROR: The analysis dataset is missing ;
		%return;
	%end;

	%local i ncl cluselect;

	proc sql noprint;
		%if %superq(vlist)= %then %do;		
			select trim(variable)
			into : vlist separated by " "
			from &pdn
			where exclude is missing and target is missing and type="num";
		%end;

		%if %sysfunc(exist(varclusters)) %then drop table varclusters; ;
	quit;

	ods exclude all;
	ods output clusterquality=work.vc_varclusnum    rsquare=varclusters;
	proc varclus data=&dn maxeigen=.7 short ;
		var &vlist;
	run;
	ods output close;
	ods select all;

	data _null_;
		set work.vc_varclusnum;
		call symputx('ncl',numberofclusters);
	run;
	ods output close;

	data varclusters (drop=numberofclusters controlvar) ;
		set varclusters;
		label owncluster="Own Cluster R-squared"
			nextclosest="Next Closest R-squared";
		retain clus_n;
		where numberofclusters=&ncl;
		if not missing(cluster) then 	clus_n=input(substr(cluster,9), 8.);
	run;

	%if &g=1 %then %do;
		%do i=1 %to &ncl;
			proc sql noprint;
				select quote(trim(ori_woe))
				into :vlist separated by " "
				from &pdn
				where variable in (select variable from varclusters where clus_n=&i);
			quit;

			proc sgpanel data = woe;
				panelby variable;
				where variable in (&vlist);
				title "Empirical Logit against cluster&i"; 
				scatter y=elogit x=woe/datalabel=bin;
				series y=elogit x=woe;
			run;quit;
		%end;
		title;
	%end;
	proc datasets lib=work noprint;
	   delete vc_: ;
	run;
	quit;

	options notes;
	%put NOTE: === Dataset varclusters was created ===;
%mend;
