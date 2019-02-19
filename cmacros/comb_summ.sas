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
/*	%if %sysfunc(indexw(&para,n)) and %sysfunc(indexw(&para,nmiss)) %then
		%let missperc=1;*/
	%let count=%eval(%length(&para)-%length(%sysfunc(compress(&para))) +1);
	%let para2=%sysfunc(tranwrd(&para, %str( ), %nrstr(", ")));
	%let para2="&para2";
	data _null_;
		set &dn;
		length name $32 ;
		array vars(*) Vname_:;
		array para(&count) $ (&para2);
		call execute("data &outdn;	length name $32; set &dn; keep name &para;");
		do i=1 to dim(vars);
			name =trim(vars[i]);
			call symputx("var"||left(i), name);
			call execute('name ="&var'||strip(i)||'";');
			do j=1 to &count;
				call execute(para[j]||'=&var'||strip(i)||'._'||para[j]||';');
			end;
			call execute('output &outdn;');
		end;
		call execute('run;');
	run;
%exit:
%mend comb_summ;	
