/***********************************************************************************************	
**	macro VarPSI: calculate the variable PSI
**	edn: the base data set (expected).
**	adn: the test data set (actual).
**	psilist: the variable list that would compute the PSI. Usually, they are binning variable
**	tvar: The time variable.
**	mvar: The variable that mark the model stability.
**	outdn: the output data set that store the result. The default is VarPSI.
************************************************************************************************/
%macro VarPSI(edn, adn, psilist, tvar=, mvar=, pdn=vars, outdn=VarPSI)/store;
	%if %superq(edn)= or %superq(adn)= or %superq(psilist)= %then %do;
		%put ERROR:  The expected dataset, actual datset and variable list are required.;
		%return;
	%end;
	%local i j timing time var varnum eobs aobs;
	%let varnum=%sysfunc(countw(&psilist));
	options nonotes;

	proc sql noprint;
		%if %superq(tvar) ^= %then %do;
			select distinct &tvar format= monyy7., &tvar format=8., count(&tvar) 
			into :interval separated by " ", :timing separated by " ", :nobs separated by " "
			from &adn
			group by &tvar;
			%let ntime=&sqlobs;

			select nobs into :eobs
			from dictionary.tables where libname=upcase("&pname") and memname=upcase("&edn");

			%do j=1 %to &ntime;
				%let aobs=%scan(&nobs, &j, %str( ));
		 		%let time=%scan(&timing, &j, %str( ));
				%let inter=%scan(&interval, &j, %str( ));

				create table work.psi_tmp&j
				( %if %superq(mvar) ^= %then  type char(8) label='Stability',;
					variable char(32) label='Variable',
					&inter num  label="&inter"
				);

				%do i=1 %to &varnum;
					%let var=%scan(&psilist, &i, %str( ));
					insert into work.psi_tmp&j
					select %if %superq(mvar) ^= %then %do;
								%if "&var"="&mvar" %then "model" as type,;
								%else "variable" as type,;
							%end;
						"&var" as variable, 
						sum((acount/&aobs-ecount/&eobs)*log((acount/&aobs)/(ecount/&eobs)))
						as &inter
						from (select &var, count(&var) as ecount from &edn group by &var) as a 
						inner join
						(select &var, count(&var) as acount from &adn 
						where &tvar=&time group by &var) as b 
						on a.&var=b.&var;
					%end;
			%end;
		%end;
		%else %do;
			create table &outdn
			( %if %superq(mvar) ^= %then type char(8) label='Stability',;
				variable char(32) label='Variable',
			  	PSI num  label='PSI');

			select nobs into :eobs
			from dictionary.tables where libname=upcase("&pname") and memname=upcase("&edn");
			select nobs into :aobs
			from dictionary.tables where libname=upcase("&pname") and memname=upcase("&adn");

			%do i=1 %to &varnum;
				%let var=%scan(&psilist, &i, %str( ));
				insert into &outdn
				select %if %superq(mvar) ^= %then %do;
								%if "&var"="&mvar" %then "model" as type,;
								%else "variable" as type,;
							%end;
					"&var" as variable, 
					sum((acount/&aobs-ecount/&eobs)*log((acount/&aobs)/(ecount/&eobs))) as PSI
				from (select &var, count(&var) as ecount from &edn group by &var) as a inner join
				(select &var, count(&var) as acount from &adn group by &var) as b on a.&var=b.&var;
			%end;
		%end;
	quit;

	%if %superq(tvar) ^= %then %do;
		%do j=1 %to &ntime;
			proc sort data=work.psi_tmp&j;
				by variable;
			run;
		%end;
		data  &outdn;
			merge %do j=1 %to &ntime;
						work.psi_tmp&j %end;
					;
			by variable;
		run;
	%end;

	proc report data=StabPSI headline headskip;
		title1 "Stable Report";
		title2 "Backgrond: <0.1(Green);  0.1~0.25(Yellow);  >0.25(Red)";
		%if %superq(mvar) ^= %then title3 "The variable having bold font is the model stability indicator"%str(;);
		columns ( %if %superq(mvar) ^= %then type;  variable
		%if %superq(interval) ^= %then &interval %else PSI;  );
		%if %superq(mvar) ^= %then define type /group descending noprint%str(;);
		define variable /display width=35;
		%if %superq(interval) ^= %then %do;
			%do j=1 %to &ntime;
				%let inter=%scan(&interval, &j, %str( ));
				define &inter /display width=15 ;
			%end;
		%end;
		%else define PSI /display width=15 ;
		%if %superq(mvar) ^= %then %do;
		   compute variable;
			if variable = "&mvar" then
				call define('variable', "style", "style=[font_weight=bold]"); 
		    endcomp;
		%end;
		%if %superq(interval) ^= %then %do;
			%do j=1 %to &ntime;
				%let inter=%scan(&interval, &j, %str( ));
				compute &inter;
					if &inter<0.1 then
						call define("&inter", "style", "style=[backgroundcolor=green]"); 
					if 0.1=<&inter=<0.25 then 
						call define("&inter", "style", "style=[backgroundcolor=yellow]");
					if 0.25<&inter then 
						call define("&inter", "style", "style=[backgroundcolor=red]");
				endcomp;
			%end;
		%end;
		%else %do;
			compute PSI;
				if PSI<0.1 then
					call define("PSI", "style", "style=[backgroundcolor=green]"); 
				if 0.1=<PSI=<0.25 then 
					call define("PSI", "style", "style=[backgroundcolor=yellow]");
				if 0.25<PSI then 
					call define("PSI", "style", "style=[backgroundcolor=red]");
			endcomp;
		%end;
	run;

	proc datasets lib=work noprint;
	   delete psi_: ;
	run;
	quit;

	options notes;
	%put NOTE: ==== Macro VarPSI exacute completed, the result store in &outdn ====;
%mend VarPSI;
