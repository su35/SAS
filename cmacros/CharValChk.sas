/*Macro CharValChk: check the value of long length char variable is free text
*  dn: the name of the dataset
*  vars: the variable list which would be check
*  nobs: define how may obs would be check 
*  speed: if=1, then just quickly print the limited value.
*  			if=2, then check the all distict value*/
%macro CharValChk(dn, vars, outobs=50, speed=0);
	%local i varn val nobs;
	
	%let varn=%sysfunc(countw(&vars));
	%if &speed=1 %then %do;
		%do i=1 %to &varn;
			%let val=%scan(&vars, &i);
			proc print data=&dn (obs=&outobs);
				var &val;
				where &val is not missing;
			run;
		%end;
	%end;
	%else %do;
		data _null_;
			set &dn nobs=obs;
			call symputx("is_nobs", nobs);
			stop;
		run;
		%if &nobs>10000 %then %do;
			proc surveyselect data=&dn out=work.cvc_dn sampsize=10000 noprint;
			run;
			%let dn=work.cvc_dn;	
		%end;
		proc sql outobs=&outobs;
			%do i=1 %to &varn;
				%let var=%scan(&vars, &i);
				title "The first 20th distinct &var values";
				select distinct (&var)
				from &dn;
			%end;
		quit;
		title;
	%end;
	proc datasets lib=work noprint;
	   delete cvc_: ;
	run;
	quit;
%mend CharValChk;
