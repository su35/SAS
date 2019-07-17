%macro Plot(dn, id, x, y, varlist);
	options nonotes;
	proc sql noprint;
		select distinct &id into :pw_vlist1-:pw_vlist999
		from &dn
		%if %superq(varlist) ^= %then %do;
			where &id in (&varlist)
		%end;
		;
	quit;
	%let nvar=&sqlobs;
	%do i=1 %to &nvar;
		proc sgplot data=&dn(where=(&id="&&pw_vlist&i")) noautolegend;
			title "&&pw_vlist&i";
			series y=&y x=&x;
		run;
	%end;
	title; 
	options notes;
%mend;
