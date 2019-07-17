/* ********************************************************************************************
* macro CheckMissing.sas: Ckeck are there missing values in SDTM required varailbles
* metadatafile: the file containing the dataset metadata. 
* 		the default is the project folder\SDTM_METADATA.xlsx 
* dataset:  the dataset or domain name. the default is empty which means all dataset
* random: dataset that include the usubjid which had been assinged treatment only
* status: dataset that include the usubjid which have completed only
* ********************************************************************************************/
%macro CheckMissing(metadatafile=,dataset=, random=, status=);
	%if %superq(metadatafile)= %then %let metadatafile=&pdir.sdtm_metadata.xlsx;
	%if %superq(random)= %then %let random=random;
	%if %superq(status)= %then %let status=status;
	%if %sysfunc(libref(sdtmfile)) ne 0 %then  
		libname sdtmfile "&metadatafile";;
	data work._temp;
		set sdtmfile."VARIABLE_METADATA$"n;
	run;

	%if %superq(dataset)^=  %then %StrTran(dataset);

	proc sort data= work._temp out=work._mandatory(keep= domain variable label);
		where upcase(mandatory) in ("YES", "Y")
			%if %superq(dataset)^= %then and upcase(domain) in (%upcase(&dataset));
			;
		by domain;
	run;
	%local dnum i j;
	proc sort data=work._mandatory;
		by domain;
	run;

	data work._temp_;
		set work._mandatory end=eof;
		by domain;
		length vlist $1000;
		retain vlist n;
		
		if first.domain then do;
			vlist="";
			n+1;
		end;
		vlist=catx(" ", vlist, variable);
		if last.domain then do;
			call symputx("cm_dm"||left(n), domain);
			call symputx("cm_vlist"||left(n), vlist);
		end;
		if eof then call symputx("dnum", n);
	run;
	options nonotes;
	%do i=1 %to &dnum;
		proc sql;
			create table work.tset as
			select a.*, case when b.usubjid then 1 else . end as random, 
					case when c.usubjid then 1 else . end as complete
			from &&cm_dm&i as a left join  (select usubjid from &random) as b 
				on a.usubjid=b.usubjid left join
		 		(select usubjid from &status) as c
			 	on a.usubjid=c.usubjid;
		quit;

		ods html close;
		ods output OneWayFreqs=work._freq1 ;
		proc freq data=work.tset;
			table &&cm_vlist&i /missing;
		run;
		ods output OneWayFreqs=work._freq2 ;
		proc freq data=work.tset;
			table &&cm_vlist&i /missing;
			where random=1;
		run;
		ods output OneWayFreqs=work._freq3 ;
		proc freq data=work.tset;
			table &&cm_vlist&i /missing;
			where complete=1;
		run;
		ods output close;
		ods html;

		proc sql noprint;
			update work._freq1 set table=substr(table, 7);
			update work._freq2 set table=substr(table, 7);
			update work._freq3 set table=substr(table, 7);

			select distinct(table) as var, "(table='"||trim(table)||"' and "||trim(table)||" is missing)" as code
			into :cm_dm separated by " ", :code separated by " or "
			from work._freq1; 

			create table work.missing as
			select "&&cm_dm&i" as domain length=10, a.*, miss_rand, miss_compl
			from (select distinct(table) as variable, frequency as missing
					from work._freq1 where &code) as a left join
					(select distinct(table) as variable length=32, frequency as miss_rand 
					from work._freq2 where &code) as b on a.variable=b.variable  left join
					(select distinct(table) as variable, frequency as miss_stat 
					from work._freq3 where &code) as c on b.variable=c.variable  ;
		quit;

		proc append base=missing data=work.missing;
		run;
	%end;
	options notes;

	proc print data = missing;
	run;
%mend CheckMissing;

