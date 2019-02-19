/* ******************************************************
* macro ae_summary_set call routine
* usage: call by customnized call routine ae_summary_set()
* parameters
* setname: the name of the ae dataset; character
* var: the variable name based on which the ae would be counted
* ********************************************************/
%macro ae_summary_set /*  /store  source */;
	%local i j k;
	%let setname=%sysfunc(compress(&setname,"'")); 
	%let var=%sysfunc(compress(&var,"'")); 
	%if not(%symexist(group)) %then %do;
		%global group;
		%let group =1;
	%end;

	proc sql noprint;
		select strip(put(count(usubjid),4.)), strip(put(count(distinct trta), 4.))
			into : tatolsub,  :trtlevel
			from &setname;

		select distinct aesev into  :sevlevel1- :sevlevel3
			from &setname
			order by aesev;

		select 
			%do i=0 %to %eval(&trtlevel-1);
				strip(put(sum (case when trtan= &i then 1 else 0 end),4.))
				%if &i ne %eval(&trtlevel-1) %then %str(,);
			%end;
			into %do i=0 %to %eval(&trtlevel-1);
				:sub&i %if &i ne %eval(&trtlevel-1) %then %str(,);
			%end;
			from &setname; 

		create table _aesev as
		select count(usubjid) as tatol, 
		%do i = 0 %to &trtlevel;
			%if &i=&trtlevel %then %do;
				sum(case when aesev= "MILD" then 1 else 0 end) as Mild&i,
				sum(case when aesev= "MODERATE" then 1 else 0 end) as Moderate&i,
				sum(case when aesev= "SEVERE" then 1 else 0 end) as Severe&i /*this is the last line, without ','*/
			%end;
			%else %do;
				sum(case when aesev= "MILD" and trtan = &i then 1 else 0 end) as Mild&i,
				sum(case when aesev= "MODERATE" and trtan = &i then 1 else 0 end) as Moderate&i,
				sum(case when aesev= "SEVERE" and trtan = &i then 1 else 0 end) as Severe&i,
			%end;
		%end;
		from  
			(select usubjid, aesev, trtan from &setname where aesoc = "&var" group by aesev having max(aesev));
	quit;

	data _term;
		length group 3 term $ 85 trtan0-trtan&trtlevel $ 20;
		keep group term trtan0-trtan&trtlevel;
		set _aesev;
		array sub(%eval(&trtlevel+1))  _temporary_ (
					 %do i=0 %to %eval(&trtlevel-1);
						&&sub&i%str(,)
			%end; &tatolsub);
		group=&group;

		%do k=0 %to 3; /*total plus Mild, Moderate and Severe*/
			%if &k=0 %then %do;
				term = "&var";
				%do i= 0 %to &trtlevel; /*including total, number of  iteration equal to the trtlevel +1*/
					%let j = %eval(&i+1);
					trtan&i = %sysfunc(left(strip(put(sum(mild&i, Moderate&i,Severe&i),4.))))||
								' ('||%sysfunc(left(strip(put((sum(mild&i, Moderate&i,Severe&i)/sub[&j])*100,5.2))))||'%)';
				%end;
				output;
			%end;
			%else %do;
				term = "&blankno"||"&&sevlevel&k";
				%do i=0 %to 2;  
					%let j = %eval(&i+1);
					trtan&i = %sysfunc(left(strip(put(&&sevlevel&k&&i,4.))))||' ('||%sysfunc(left(strip(put((&&sevlevel&k&&i/sub[&j])*100, 5.2))))||'%)';
				%end;
				output;
			%end;
		%end; 
	run;
	%if %sysfunc(exist(aereport))  %then %do;
		proc append base=aereport data=_term; 
		run;
		%end;
	%else %do;
		proc datasets noprint;
			change _term=aereport;
		run; quit;
	%end;	
	%let group=%eval(&group+1);
%mend ae_summary_set;
