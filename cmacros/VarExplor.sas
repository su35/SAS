/* *********************************************************************
* macro VarExplor: 
* Create vars data set to collecte the characteristic of the variables
* dn: The data set used to analyse or modeling. It is required.
* outdn: The created data set
* vardefine: dataset that recording the variables define.
* if the vardefine is not available, the following params may need.
* 	target: The target variable for modeling. If the vardefine is unavailable, the target is required
* 	exclu: The list of variables which are not included in analysis or modeling
* 	interval: list of interval variables
* 	ordinal: list of ordinal variables
*	id: the id variable
* *********************************************************************/
%macro VarExplor(dn, lib=&pname, outdn=vars, vardefine=, id=, target=, exclu=,interval=,ordinal= )/minoperator;
	%if %superq(dn)=  %then %do;
		%put ERROR: ======= The input dataset is missing ======;
		%return;
	%end;
	%local  vd_freqlist i vd_size vd_excp_class;
	/*to void a huge out put, close the notes, html, and listing */
	options nonotes;
	ods select none;
	/*if the variable define dataset is available, get the required params that were not assinged*/
	%if %superq(vardefine)^= %then %do;
		proc sql noprint;
			%if %superq(target)= %then %do;
				select distinct variable into :target
				from &vardefine where target=1;
			%end;
			%if %superq(id)= %then %do;
				select distinct variable into :id
				from &vardefine where id=1;
			%end;
			%if %superq(exclu)= %then %do;
				select distinct variable into :exclu separated by " "
				from &vardefine where exclude=1 or id=1 or target=1;
			%end;
			%if %superq(interval)= %then %do;
				select distinct variable into :interval separated by " "
				from &vardefine 
				where class="interval" and target^=1 and exclude^=1;
			%end;
			%if %superq(ordinal)= %then %do;
				select distinct variable into :ordinal separated by " "
				from &vardefine 
				where class="ordinal" and target^=1 and exclude^=1;
			%end;
			%if %sysfunc(exist(&outdn)) %then drop table &outdn; ;
		quit;
		proc sort data=&vardefine out=work.&vardefine;
			by vid;
		run;
		data work.&vardefine;
			set work.&vardefine;
			by vid;
			if first.vid then output;
		run;
	%end;
	%else %if %superq(interval)= %then %do;
		 %if %superq(ordinal)^= %then %StrTran(ordinal);
		proc sql noprint;
			select name into :interval separated by " "
			from dictionary.columns
			where libname="%upcase(&lib)" and memname="%upcase(&dn)" and type="num" 
			%if %superq(ordinal)^= %then and upcase(name) not in %upcase(&ordinal);
			%if %superq(exclu)^= %then and upcase(name) not in %upcase(&exclu);
			;
		quit;
		 %if %superq(ordinal)^= %then %StrTran(ordinal);
		 /*exclu should include target and id*/
		%if %superq(exclu)^= or %superq(target)^= or %superq(id)^= %then %do;
			%if %index(&exclu, &target)=0 %then %let exclu=&exclu &target;
			%if %index(&exclu, &id)=0 %then %let exclu=&exclu &id;
		%end;
	%end;

	%if %superq(interval)^=  %then %interval_stat();
	/*the target will be included in nominal statistic, remove target from &exclu*/
	%if %index(&exclu, &target)>0 %then %do;
		%if %VarsCount(&exclu) >1 %then
			%let exclu=%sysfunc(trim(%sysfunc(compbl(%sysfunc(tranwrd(&exclu, &target, %str()))))));
		%else %let exclu=;
	%end;
	%nominal_stat()
	proc sql;
		create table &outdn as
			select a.variable, c.type label="Type", 
			%if %superq(vardefine)^= %then  d.class, d.description, ;
			%else "" as class, ;
			a.n, a.nlevels, 
			case when missing(b.nmissing) then 0 else b.nmissing end as nmissing, 
			case when missing(b.pctmissing) then 0.00 else b.pctmissing end as pctmissing 
			from (select distinct variable, sum(case when missing=0 then frequency else 0 end) as n, nLevels
				from freq group by variable) as a left join
				(select	distinct variable, frequency  as nmissing, percent as pctmissing
				from freq where missing=1) as b on a.variable=b.variable left join
				(select distinct name, type from dictionary.columns
				where libname=upcase("&lib") and memname=upcase("&dn")) as c 
				on c.name=a.variable
				%if %superq(vardefine)^= %then left join (select distinct variable, class, description
				from work.&vardefine) as d on d.variable=a.variable ;
			;
	quit;
	%if %superq(interval)^=  %then %do;	
		proc sort data=&outdn ;
			by variable;
		run;
		proc sort data=work.tmp_utable;
			by variable;
		run;
	%end;

	options noquotelenmax;
	data  &outdn;
		retain variable type class normal n nlevels nmissing pctmissing derive_var excluded target id description;
		length class $8 derive_var excluded target id 3;
		%if %superq(interval)^= %then %do;
			merge &outdn work.tmp_utable;
			by variable;
		%end;
		%else set  &outdn  %str(;); 
		/*if the vardefine is not available, add class value*/
		%if %superq(vardefine)= %then %do;
			if nlevels=2 then class="binary";
			%if %superq(ordinal)^= or %superq(interval)^= %then %do;
				%if %superq(ordinal)^= %then %do;
					%StrTran(ordinal)
					else if upcase(variable) in (%upcase(&ordinal)) then class="ordinal";
				%end;
				%if %superq(interval)^= %then %do;
					%StrTran(interval)
					else if upcase(variable) in (%upcase(&interval)) then class="interval";
				%end;
					else class="nominal";
			%end;
			%else %do;
				else if type="char" then class="nominal";
				 else class="";
			%end;
		%end;
		if nmissing >0 and missing(nlevels)=0 then nlevels=nlevels-1;

		%if %superq(target) ne %then %do;
			if upcase(variable)=upcase("&target") then do; 
				target=1; 
				excluded=1;
			end;
			else do;
				target=.;
				excluded=.;
			end;
		%end;
	run;
	/*add the excluded variables, &exclu include id, but exclude target*/
	%if %superq(exclu)^= %then %do;
		%let exnum=%VarsCount(&exclu);
		proc sql noprint;
			%do i=1 %to &exnum;
				insert into &outdn set variable="%scan(&exclu, &i, %str( ))", excluded=1;
			%end;
		quit;
	%end;

	options quotelenmax;
	/*comput the percent of outlier*/
	%if %superq(interval)^= %then %do;
		proc sql noprint;
			select variable, outlow, outup, n
			into :vd_vname1-:vd_vname999, :vd_low1-:vd_low999, :vd_up1-:vd_up999, :vd_n1-:vd_n999
			from &outdn
			where not missing(outlow) or not missing(outup);
		
			%if &sqlobs>0 %then %do;
				%let vd_size=&sqlobs;
				create table work.tmp_pctout 
					(variable char(32), pctoutl num(8), pctoutu num(8));
				%do i=1 %to &vd_size;
					insert into work.tmp_pctout
					select distinct "&&vd_vname&i" as variable, 
						case when &&vd_low&i ne . then round(count(&&vd_vname&i)/&&vd_n&i*100,0.01) 
							else . end as pctoutl,
						case when &&vd_up&i ne . then round(count(&&vd_vname&i)/&&vd_n&i*100,0.01) 
							else . end as pctoutu
					from &dn 
					where &&vd_vname&i<&&vd_low&i or &&vd_vname&i>&&vd_up&i;
				%end;
				proc sort data=&outdn;
					by variable;
				run;
				proc sort data=work.tmp_pctout;
					by variable;
				run;
				data &outdn &outdn._o;
					merge &outdn work.tmp_pctout;
					by variable;
				run;
			%end;
		quit;
	%end;

	data work.tmp_outlier;
		set &outdn;
		where not missing(outlow) or not missing(outup);
		drop type class normal target excluded;
	run;
	data outlier;
		set %if %sysfunc(exist(outlier)) %then outlier;
			work.tmp_outlier;
	run;
	ods select ALL;
	proc sql ;
		title1 "The value level of the following continual variables is less then 10.";
		select quote(trim(variable)) into :vd_excp_class separated by " "
		from &outdn
		where class="interval" and nlevels<=10;

		%if %superq(vd_excp_class)^= %then %do;
		title1 "The 'CLASS' of the following variables may need to set ORDINAL.";
		title2 "The names of those variable were storaged in Macro variable excp_class";
			%global excp_class;
			%let excp_class=&vd_excp_class;
			select * from freq where variable in (&vd_excp_class);
		%end;
		title1;
		title2;
	quit;
	options notes;
	%put  NOTE:  ==The dataset vars, Freq and outlier were created.==;
	%put  NOTE:  ==The macro VarExplor executed completed. ==;
%mend VarExplor;	

%macro interval_stat();
	%local is_nobs;
	data _null_;
		set &dn nobs=obs;
		call symputx("is_nobs", obs);
		stop;
	run;

	/* for large dataset, create a subset to test the normal*/
	%if &is_nobs>2000 %then %do;
		proc surveyselect data=&dn out=work.&dn._nor seed=1234 method=SRS n=1000 noprint;
		run;
	%end;
	
	proc univariate data=&dn 
		%if %superq(exclu) ne %then (drop=&exclu);
		%if %sysfunc(exist(work.&dn._nor))=0 %then normal;
			noprint outtable=work.tmp_utable (keep=_var_  _q1_  _q3_  _qrange_ _min_ _mean_ 
							_median_ _max_ _nobs_  _nmiss_ 
			%if %sysfunc(exist(work.&dn._nor))=0 %then _probn_;
			rename=(_var_=variable  _q1_=q1 _q3_=q3 _qrange_=qrange _min_=min _max_=max
							_mean_=mean _median_=median  _nobs_=n  _nmiss_ =nmissing
			%if %sysfunc(exist(work.&dn._nor))=0 %then _probn_ =pvalue;
			));
		var &interval;
		%if %sysfunc(exist(work.&dn._nor))=0 %then %do;
			histogram &interval / normal;
		%end;
	run;
	%if %sysfunc(exist(work.&dn._nor)) %then %do;
		proc univariate data=work.&dn._nor 
			%if  %superq(exclu) ne %then (drop=&exclu);
			normal noprint outtable=work.tmp_npvalue (keep=_var_   _probn_
				rename=(_var_=variable   _probn_ =pvalue));
			var &interval;
			 histogram &interval / normal;
		run;
		proc sort data=work.tmp_utable;
			by variable;
		run;
		proc sort data=work.tmp_npvalue;
			by variable;
		run;
		data work.tmp_utable;
			merge work.tmp_utable work.tmp_npvalue ;
			by variable;
		run;
	%end;

	data work.tmp_utable;
		set work.tmp_utable;
		type="num";
		pctmissing=round((nmissing/&is_nobs)*100, 0.01);
		if q1-1.5*qrange > min then outlow=q1-1.5*qrange;
		if q3+1.5*qrange <max then outup=q3+1.5*qrange;
		if not missing(pvalue) then do;
			if round(pvalue, .00001)>0.05 then normal=1;
			else normal="0";
		end;
		drop pvalue;
	run;
%mend interval_stat;

%macro nominal_stat();
*	ods graphics on;
	ods output OneWayFreqs=work.tmp_freq NLevels=work.tmp_level(rename=(tablevar=variable));
	proc freq data=&dn %if %superq(exclu)  ne  %then (drop=&exclu); nlevels;
		table _all_  /missing nocum /*plots=freqplot*/;
	run;
	ods output close;
*	ods graphics off;
	%CombFreq(work.tmp_freq, work.tmp)
	proc sort data=work.tmp;
		by variable;
	run;
	proc sort data=work.tmp_level;
		by variable;
	run;
	data freq outlier;
		merge work.tmp work.tmp_level;
		by variable;
		output freq;
		if percent<10/nlevels then output outlier;
	run;
%mend nominal_stat;
