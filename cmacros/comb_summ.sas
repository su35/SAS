/* *********************************************************
	macro comb_summ
	split the summary table from proc means
	dn: the summary table
	outdn: the new output dataset
	para: the parameters that would be included in outdn.
* **********************************************************/
%macro comb_summ(dn, outdn, para);
	%if %superq(dn)=  or %superq(outdn)=   or %superq(para)=   %then %do;
			%put ERROR: == params include input dataset, output dataset, para. ==;
			%goto exit;
		%end;
	%local i j;

	%let count=%eval(%length(&para)-%length(%sysfunc(compress(&para))) +1);

	proc sql noprint;
		select 
			case when index(name,"VName") then name else '' end as vname,
			%do i=1 %to &count;
				%let val=%scan(&para,&i);
				case when upcase(substr(name, find(name, "_",-50)+1))=upcase("&val") 
					then trim(name) else '' end as &val,
			%end;
			count(calculated vname)
			into :vname separated by " ", 
			%do i=1 %to &count;
				:plist&i separated by " ",
			%end;
			:dim
			from dictionary.columns
			where libname=upcase("&pname") and memname=upcase("&dn") ;
	quit;

	data &outdn;
		set &dn;
		length name $32 &para 8; 
		keep name &para;
		array vars(&dim) $ Vname_:;
		%do i=1 %to &count;
			array plist&i(&dim) $ &&plist&i;
		%end;
		do i=1 to &dim;
			name =trim(vars[i]);
			%do j=1 %to &count;
				%let pval=%scan(&para,&j);
				&pval=plist&j[i];
			%end;
			output &outdn;
		end;
	run;
%exit:
%mend comb_summ;	
