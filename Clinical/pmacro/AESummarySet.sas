/* **************************************************************
* macro AESummarySet: create AE report dataset for report.
* parameters
* 	dn: the name of the ae dataset; character
* ***************************************************************/
%macro AESummarySet(dn);
	%local i j k group tatolsub trtlevel sevlevel1 sevlevel2 sevlevel3 socnum;
	%let group =1;
	options nonotes;
	proc sql noprint;
		select strip(put(count(usubjid),4.)), strip(put(count(distinct trta), 4.))
			into : tatolsub,  :trtlevel
			from &dn;

		select distinct aesev into  :sevlevel1- :sevlevel3
			from &dn
			order by aesev;

		select distinct aesoc	into  :ass_soc1-:ass_soc999
			from &dn;
		%let socnum=&sqlobs;

		select 
			%do i=0 %to %eval(&trtlevel-1);
				strip(put(sum (case when trtan= &i then 1 else 0 end),4.))
				%if &i ne %eval(&trtlevel-1) %then %str(,);
			%end;
			into %do i=0 %to %eval(&trtlevel-1);
				:sub&i %if &i ne %eval(&trtlevel-1) %then %str(,);
			%end;
			from &dn; 

		%if %sysfunc(exist(aereport)) %then drop table aereport; ;
	quit;

	%do i=1 %to &socnum;
		proc sql;
			create table work.aesev as
			select count(usubjid) as tatol, 
			%do j = 0 %to &trtlevel;
				%if &j=&trtlevel %then %do;
					sum(case when aesev= "MILD" then 1 else 0 end) as Mild&j,
					sum(case when aesev= "MODERATE" then 1 else 0 end) as Moderate&j,
					sum(case when aesev= "SEVERE" then 1 else 0 end) as Severe&j /*this is the last line, without ','*/
				%end;
				%else %do;
					sum(case when aesev= "MILD" and trtan = &j then 1 else 0 end) as Mild&j,
					sum(case when aesev= "MODERATE" and trtan = &j then 1 else 0 end) as Moderate&j,
					sum(case when aesev= "SEVERE" and trtan = &j then 1 else 0 end) as Severe&j,
				%end;
			%end;
			from  
				(select usubjid, aesev, trtan from &dn where aesoc = "&&ass_soc&i" group by aesev having max(aesev));
		quit;

		data work.term;
			length group 3 term $ 85 trtan0-trtan&trtlevel $ 20;
			keep group term trtan0-trtan&trtlevel;
			set work.aesev;
			array sub(%eval(&trtlevel+1))  _temporary_ (
				%do j=0 %to %eval(&trtlevel-1);
							&&sub&j%str(,)
				%end; &tatolsub);
			group=&group;

			%do k=0 %to 3; /*total plus Mild, Moderate and Severe*/
				%if &k=0 %then %do;
					term = "&&ass_soc&i";
					%do j= 0 %to &trtlevel; /*including total, number of  iteration equal to the trtlevel +1*/
						%let n = %eval(&j+1);
						trtan&j = %sysfunc(left(strip(put(sum(mild&j, Moderate&j,Severe&j),4.))))||
									' ('||%sysfunc(left(strip(put((sum(mild&j, Moderate&j,Severe&j)/sub[&n])*100,5.2))))||'%)';
					%end;
					output;
				%end;
				%else %do;
					term = "&blankno"||"&&sevlevel&k";
					%do j=0 %to 2;  
						%let n = %eval(&j+1);
						trtan&j = %sysfunc(left(strip(put(&&sevlevel&k&&j,4.))))||' ('||%sysfunc(left(strip(put((&&sevlevel&k&&j/sub[&n])*100, 5.2))))||'%)';
					%end;
					output;
				%end;
			%end; 
		run;
		proc append base=aereport data=work.term; 
		run;
		%let group=%eval(&group+1);
	%end;
	options notes;
	%put NOTE:  ==The dataset aereport was created.==;
	%put NOTE:  ==The macro AESummarySet executed completed.== ;
%mend AESummarySet;