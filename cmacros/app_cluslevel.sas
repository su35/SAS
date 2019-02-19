%macro app_cluslevel(dn, pdn, suff);
	%if %superq(dn)=  %then %do;
			%put ERROR: dataset name is required;
			%goto exit;
		%end;
	%if %superq(suff)= %then %let suff=clus;
	%if %superq(pdn)= %then %let pdn=cluslevel;
	
	proc sql noprint;
		select distinct varname, count(distinct varname) 
			into :varlist separated by " ", :varnum
			from &pdn;
	quit;

	%do i=1 %to &varnum;
		%let var=%scan(&varlist, &i);
		proc sql noprint;
			select max(cluster)-1 
				into :clusnum
				from &pdn
				where varname="&var";

			select 
				%do j=1 %to &clusnum;
					%if &j ne &clusnum %then case when cluster =&j then value else "" end, ;
					%else case when cluster =&j then value else "" end ;
				%end;
				into
				%do j=1 %to &clusnum;
					%if &j ne &clusnum %then :clus&j. separated by " ", ;
					%else :clus&j separated by " " ;
				%end;
				from &pdn
				where varname="&var";
		quit;

		data &dn;
			set &dn;
			%do j=1 %to &clusnum;
				%str_tran(clus&j)
				&var&suff&j=(&var in (&&clus&j));
			%end;
		run;
	%end;
%exit:
%mend app_cluslevel;

