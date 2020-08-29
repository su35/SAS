/* Macro ScoreP: Caluclate the ScoreP base on scorechisq
*   dn: the dataset name, default is the ods output bestsubsets of proc logistic
*   nobs: the used obs by proc logistic, default is the ods output nobs
*   varinmod: the list of variable that included in model;
*   nvars: the number of variable that included in model;
*/
%macro ScoreP(dn, nobs, varinmod=variablesinmodel, nvars=numberofvariables,pdn=vars);
	%if %superq(dn)= or %superq(nobs)= %then %do;
		%put ERROR: === The dataset that stored the candidate models ===;
		%put ERROR: === and number of obs that used in proc logistic are required ===;
		%return;
	%end;
	%local obs i;
	options nonotes;
	
	data _null_;
		set &dn nobs=obs;
		if _N_=1 then call symputx('obs', obs);
		call symputx("sp_vlist"||left(_N_), &varinmod);
	run;

	%do i=1 %to &obs;
		%let sp_qvlist&i=&&sp_vlist&i;
		%strtran( sp_qvlist&i)
	%end;
 	options noquotelenmax;
	proc sql;
		alter table &dn add df num;

		update &dn set df=
	         case 
		%do i=1 %to &obs;
			when &varinmod="&&sp_vlist&i" then (select sum(nlevels-1) from 
					vars where variable in (&&sp_qvlist&i))
		%end;
		else 0 end;
	quit;

 	data &dn;
		set &dn;
		df=df+&nvars + 1;
		scorep= -scorechisq + log(&obs) * df;
		drop control_var;
	run;

	proc sort data=&dn;
		by scorep;
	run;

	data &dn;
		set &dn;
		scoreprank=_N_;
	run;
	options quotelenmax notes;
	
	%put NOTE: == The calculated df and scroep are stored in &dn ==;
	%put NOTE: == The Macro ScoreP running completed ==;
%mend ScoreP;
