*----------------------------------------------------------------*;
* make_sort_order.sas creates a global macro variable called  
* **SORTSTRING where ** is the name of the dataset that contains  
* the KEYSEQUENCE metadata specified sort order for a given dataset.
*
* MACRO PARAMETERS:
* metadatafile = the file containing the dataset metadata
* dataset = the dataset or domain name
*----------------------------------------------------------------*;
%macro make_sort_order(metadatafile=&pdir.SDTM\SDTM_METADATA.xlsx,dataset=);
	%local i;
	proc import 
		datafile="&metadatafile"
		out=_temp 
		dbms=excelcs
		replace;
		sheet="VARIABLE_METADATA";
	run;
	%if %superq(dataset)=  %then %do;
		proc sql noprint;
			select distinct domain, count(distinct domain)
				into :dmlist separated " ", :dmnum
				from _temp;
		quit;
	%end;
	%else %let dmnum=1;
	%do i = 1 %to &dmnum;
		%if &dmnum > 1  %then %let dataset = %scan(&dmlist, &i, ' ' ); 
		proc sort
			data=_temp out=_settemp;
			where keysequence ne . and domain=upcase("&dataset");
			by keysequence;
		run;

		** create **SORTSTRING macro variable;
		data _null_;
			set _settemp end=eof;
			length domainkeys $ 200;
			retain domainkeys '';

			domainkeys = trim(domainkeys) || ' ' || trim(put(variable,8.)); 

			if eof then
			call symputx("SORTSTRING", domainkeys);
		run;
		proc sort data=&dataset;
			by &SORTSTRING
		run;
	%end;
%mend make_sort_order;
