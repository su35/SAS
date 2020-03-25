/* check the number of the month between the start point 
*  and the time point that the nonmissing happen
*  paras: 
*  dn: the name of the dataset
*  vars: the variable list that would be checked
*  timevar: the varible that hold the start point and time point and its format would
*  			datetime or date class.*/
%macro MissTimeWid(dn, vars, timevar);
	%if %superq(dn)= or %superq(vars)= %then %do;
		%put ERROR: == The dataset name or the variable list is missing ==;
		%return;
	%end;
	
	%local varn i var start fm;
	%let varn=%eval(%length(%sysfunc(compbl(&vars)))-%length(%sysfunc(compress(&vars))) +1);
	options nonotes;
	proc sql noprint;
		select min(&timevar)  into :start
		from &dn;

		create table misswid as
		%do i=1 %to &varn;
			%let var=%scan(&vars, &i);
			select "&var" as variable, min(&timevar) as timepoint 
				from &dn 
				where &var is not missing %if &i^=&varn %then union;
									%else %str(;);
		%end;

		select format into :fm
		from dictionary.columns
		where libname=upcase("&pname") and memname=upcase("&dn")
				and name="&timevar";
	quit;

	data misswid;
		set misswid;
		start=&start;
		%if &fm=DATETIME. %then %do;
			start=datepart(start);
			timepoint=datepart(timepoint);
		%end;
		format timepoint start date9.;
		label timepoint="First Nomissing";
		monthinterval= intck ('MONTH', start, timepoint);
	run;

	proc sort data=misswid;
		by monthinterval variable;
	run;
	options notes;
	%put NOTE: == The macro MissTimeWid executed completed. ==;
	%put NOTE: == The result was stored in misswid. ==;
%mend MissTimeWid;
