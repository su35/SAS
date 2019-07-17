/* *********************************************************************
* macro VarDescr: 
* Create vars data set to collecte the characteristic of the variables
* dn: The data set used to analyse or modeling
* outdn: The created data set
* target: The target variable for modeling
* exclu: The list of variables which are not included in analysis or modeling
* interval: list of interval variables
* ordinal: list of ordinal variables
* *********************************************************************/
%macro VarDescr(dn, lib=&pname, outdn=vars, target=, exclu=,interval=,ordinal= )/minoperator;
	%if %superq(dn)=  %then %do;
		%put ERROR: ======= The input dataset is missing ======;
		%return;
	%end;
	%local  vd_freqlist i vd_size;
	options nonotes;
	%if %superq(interval)^=  %then %interval_stat();
	%nominal_stat()

	proc sql;
		create table &outdn as
			select a.name, c.type label="Type", "" as class, a.n, a.nlevels, 
			case when missing(b.nmissing) then 0 else b.nmissing end as nmissing, 
			case when missing(b.pctmissing) then 0.00 else b.pctmissing end as pctmissing 
			from (select distinct name, sum(case when missing=0 then frequency else 0 end) as n, nLevels
			from freq group by name) as a left join
			(select	distinct name, frequency  as nmissing, percent as pctmissing
			from freq where missing=1) as b on a.name=b.name left join
			(select distinct name, type from dictionary.columns
			where libname=upcase("&lib") and memname=upcase("&dn")) as c 
			on c.name=a.name;
	quit;
	%if %superq(interval)^=  %then %do;	
		proc sort data=work.tmp_utable;
			by name;
		run;
	%end;
	data  &outdn;
		retain name type class normal n nlevels nmissing pctmissing derive_var excluded target;
		length class $8 derive_var excluded target 3;
		set  &outdn 
		%if %superq(interval)^= %then work.tmp_utable %str(;);
		if nlevels=2 then class="binary";
		%if %superq(ordinal)^= or %superq(interval)^= %then %do;
			%if %superq(ordinal)^= %then %do;
				%StrTran(ordinal)
				else if upcase(name) in (%upcase(&ordinal)) then class="ordinal";
			%end;
			%if %superq(interval)^= %then %do;
				%StrTran(interval)
				else if upcase(name) in (%upcase(&interval)) then class="interval";
			%end;
				else class="nominal";
		%end;
		%else %do;
			else if type="char" then class="nominal";
			 else class="";
		%end;
		if nmissing >0 and missing(nlevels)=0 then nlevels=nlevels-1;

		%if %superq(target) ne %then %do;
			if upcase(name)=upcase("&target") then do; 
				target=1; 
				excluded=1;
			end;
			else do;
				target=.;
				excluded=.;
			end;
		%end;
	/*	if length(name)>28 then put "WARNING: The length of "||trim(name)||" is large than 28.";*/
	run;
	/*comput the percent of outlier*/
	%if %superq(interval)^= %then %do;
		proc sql noprint;
			select name, outlow, outup, n
			into :vd_vname1-:vd_vname999, :vd_low1-:vd_low999, :vd_up1-:vd_up999, :vd_n1-:vd_n999
			from &outdn
			where not missing(outlow) or not missing(outup);
		
			%if &sqlobs>0 %then %do;
				%let vd_size=&sqlobs;
				create table work.tmp_pctout 
					(name char(32), pctoutl num(8), pctoutu num(8));
				%do i=1 %to &vd_size;
					insert into work.tmp_pctout
					select distinct "&&vd_vname&i" as name, 
						case when &&vd_low&i ne . then round(count(&&vd_vname&i)/&&vd_n&i*100,0.01) 
							else . end as pctoutl,
						case when &&vd_up&i ne . then round(count(&&vd_vname&i)/&&vd_n&i*100,0.01) 
							else . end as pctoutu
					from &dn 
					where &&vd_vname&i<&&vd_low&i or &&vd_vname&i>&&vd_up&i;
				%end;
				proc sort data=&outdn;
					by name;
				run;
				proc sort data=work.tmp_pctout;
					by name;
				run;
				data &outdn;
					merge &outdn work.tmp_pctout;
					by name;
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

	options notes;
%mend VarDescr;	
%macro interval_stat();
	%local is_nobs;
	%StrTran(interval)
	proc sql noprint;
            select nobs into :is_nobs
            from dictionary.tables
            where libname=upcase("&lib") and memname=upcase("&dn");

		select name into :vd_freqlist separated by " "
		from dictionary.columns
		where libname=upcase("&lib") and memname=upcase("&dn") and 
			upcase(name) not in (%upcase(&interval));
	quit;

	%if &is_nobs>2000 %then %do;
		proc surveyselect data=&dn out=&dn._nor seed=1234 method=SRS n=1000 noprint;
		run;
	%end;
	%StrTran(interval)
	proc univariate data=&dn 
		%if %superq(exclu) ne or %superq(target) ne  %then %do;
			%if %superq(exclu) ne %then %do;
				(drop=&exclu
				%if %superq(target)  ne  %then %str( ) &target;
				 )
			%end;
			%else (drop=&target);
		%end;
		%if %sysfunc(exist(&dn._nor))=0 %then normal;
			noprint outtable=work.tmp_utable (keep=_var_  _q1_  _q3_  _qrange_ _min_ _mean_ 
							_median_ _max_ _nobs_  _nmiss_ 
			%if %sysfunc(exist(&dn._nor))=0 %then _probn_;
			rename=(_var_=name  _q1_=q1 _q3_=q3 _qrange_=qrange _min_=min _max_=max
							_mean_=mean _median_=median  _nobs_=n  _nmiss_ =nmissing
			%if %sysfunc(exist(&dn._nor))=0 %then _probn_ =pvalue;
			));
		var &interval;
		%if %sysfunc(exist(&dn._nor))=0 %then %do;
			histogram &interval / normal;
		%end;
	run;
	%if %sysfunc(exist(&dn._nor)) %then %do;
		proc univariate data=&dn._nor 
			%if %superq(exclu)  ne or %superq(target)  ne  %then %do;
				%if %superq(exclu)  ne %then %do;
					(drop=&exclu
					%if %superq(target)  ne  %then %str( ) &target );
					%else );
				%end;
				%else (drop=&target);
			%end;
			normal noprint outtable=work.tmp_npvalue (keep=_var_   _probn_
				rename=(_var_=name   _probn_ =pvalue));
			var &interval;
			 histogram &interval / normal
		run;
		proc sort data=work.tmp_utable;
			by name;
		run;
		proc sort data=work.tmp_npvalue;
			by name;
		run;
		data work.tmp_utable;
			merge work.tmp_utable work.tmp_npvalue ;
			by name;
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
			else normal=0;
		end;
		drop pvalue;
	run;
%mend interval_stat;

%macro nominal_stat();
	ods graphics on;
	ods output OneWayFreqs=work.tmp_freq NLevels=work.tmp_level(rename=(tablevar=name));
	proc freq data=&dn %if %superq(exclu)  ne  %then (drop=&exclu); nlevels;
		table %if %superq(vd_freqlist)^= %then &vd_freqlist;
				%else  _all_ ;
			/missing plots=freqplot;
	run;
	ods output close;
	ods graphics off;

	data work.tmp ;
		length name $32;
		set work.tmp_freq;
		name=substr(table, 7);
		array chars(*) $ F_:;
		do i=1 to dim(chars);
			if not missing(chars[i]) and  strip(chars[i]) ne '.' then missing=0;
		end;
		if missing(missing) then missing=1;
		keep name missing frequency percent;
	run;
	proc sort data=work.tmp;
		by name;
	run;
	proc sort data=work.tmp_level;
		by name;
	run;
	data freq outlier;
		merge work.tmp work.tmp_level;
		by name;
		output freq;
		if percent<10/nlevels then output outlier;
	run;
%mend nominal_stat;
