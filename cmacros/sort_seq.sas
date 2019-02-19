*----------------------------------------------------------------*;
* sort_seq.sas sorting the dataset according to the KEYSEQUENCE metadata
* specified sort order for a given dataset.
* if there is a __seq variable in a dataset, then create the __seq value for it
*
* MACRO PARAMETERS:
* metadatafile = the file containing the dataset metadata. 
* the default is the project folder\SDTM folder\SDTM_METADATA.xlsx 
* dataset = the dataset or domain name
* the default is empty which means all dataset
*----------------------------------------------------------------*;
%macro sort_seq(metadatafile=&pdir.SDTM\SDTM_METADATA.xlsx,dataset=)/minoperator ;
	%local i;
	proc import 
		datafile="&metadatafile"
		out=_temp 
		dbms=excelcs
		replace;
		sheet="VARIABLE_METADATA";
	run;
	proc sort data= _temp out=_missvalue(keep= domain variable label);
		where upcase(MANDATORY) in ("YES", "Y");
		by domain;
	run;
	data _missvalue;
		set _missvalue;
		by domain;
		call check_missing(domain, variable); 
/*		length varlist $400.;
		retain varlist;
		if first.domain then varlist = ' ';
		varlist = catx(' ', varlist, variable);
		if last.domain then call symputx(trim(domain)||"vlist", varlist);*/
	run;

/*	%if %superq(dataset)=  %then %do;
		proc sql noprint;
			select distinct domain, count(distinct domain)
				into :dmlist separated " ", :dmnum
				from _temp;
			select trim(domain)
				into : seqdm separated ' '
				from _temp
				where variable like "__SEQ";
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
			by &SORTSTRING;
		run;
		%if &dataset in (&seqdm) %then %do;
			data &dataset;
				set &dataset;
				by usubjid;
				retain seq;
				if first.usubjid then seq = 0 ;
				seq + 1;
				&dataset.seq = seq;
				drop seq;
			run;
		%end;
	%end;*/
%mend sort_seq;
