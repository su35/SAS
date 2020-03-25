/* *********************************************************
	macro CombMean
	split the summary table from proc means
	dn: the summary table
	outdn: the new output dataset
	para: the parameters that would be included in outdn. Default is all paras
* **********************************************************/
%macro CombMean(dn, outdn, para);
	%if %superq(dn)=  %then %do;
			%put ERROR: == The summary dataset is required. ==;
			%return;
		%end;
	%local i j varn paran;

	%if %superq(outdn)= %then %let outdn=&dn;
	proc sql noprint;
		/*count the number of variables*/
		select count(name)
		into :varn
		from dictionary.columns
		where memname=upcase("&dn") and libname=upcase("&pname") 
				and type="char";
		/*if there is no paralist assinge, include the all paras*/
		%if %superq(para)= %then %do;
			select distinct compress(label)
			into :para separated by " "
			from dictionary.columns
			where memname=upcase("&dn") and libname=upcase("&pname") 
					and type="num";
		%end;
	quit;
	%let paran=%eval(%length(&para)-%length(%sysfunc(compress(&para))) +1);
	%do i=1 %to &paran;
		%let cm_para&i=%scan(&para, &i);
	%end;
	proc sql noprint;
		select 
			%do i=1 %to &paran;
				case when upcase(substr(name, find(name, "_",-50)+1))=upcase("&&cm_para&i") 
					then trim(name) else '' end as &&cm_para&i %if &i<&paran %then ,;
			%end;
			into 
			%do i=1 %to &paran;
				:cm_plist&i separated by " " %if &i<&paran %then,;
			%end;
			from dictionary.columns
			where libname=upcase("&pname") and memname=upcase("&dn") ;
	quit;

	data &outdn;
		set &dn;
		length name $32 &para 8; 
		keep name &para;
		array vars(&varn) $ Vname_:;
		%do i=1 %to &paran;
			array plist&i(&varn) $ &&cm_plist&i;
		%end;
		do i=1 to &varn;
			name =trim(vars[i]);
			%do j=1 %to &paran;
				&&cm_para&j=plist&j[i];
			%end;
			output &outdn;
		end;
	run;
%mend CombMean;	
