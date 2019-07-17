/* *******************************************************************************************
* SortOrder.sas sorting the dataset according to the KEYSEQUENCE metadata
* specified sort order for a given dataset.
* if there is a __seq variable in a dataset, then create the __seq value for it
*
* MACRO PARAMETERS:
* 	metadatafile = the file containing the dataset metadata. 
* 		the default is the project folder\SDTM_METADATA.xlsx 
* 	dataset = the dataset or domain name, the default is empty which means all dataset
* ********************************************************************************************/
%macro SortOrder(metadatafile=&pdir.SDTM_METADATA.xlsx,dataset=)/minoperator ;
	%local i;
	%if %sysfunc(libref(sdtmfile)) ne 0 %then  
		libname sdtmfile "&metadatafile";;
	options nonotes;
	data work._temp;
		set sdtmfile."VARIABLE_METADATA$"n;
	run;

	%if %superq(dataset)^=  %then %StrTran(dataset);
	proc sql noprint;
		select distinct domain, count(distinct domain)
			into :dmlist separated " ", :dmnum
			from work._temp
			%if %superq(dataset)^= %then where upcase(domain) in (%upcase(&dataset));
			;
		select trim(domain)
			into : seqdm separated ' '
			from work._temp
			where variable like "__SEQ"
			%if %superq(dataset)^= %then and upcase(domain) in (%upcase(&dataset));
			;
	quit;
	
	%do i = 1 %to &dmnum;
		%let dataset = %scan(&dmlist, &i, ' ' ); 
		proc sort
			data=work._temp out=work._settemp;
			where keysequence ne . and domain=upcase("&dataset");
			by keysequence;
		run;

		/** sorting dataset;*/
		data _null_;
			set work._settemp end=eof;
			length domainkeys $ 200;
			retain domainkeys '';

			domainkeys = trim(domainkeys) || ' ' || trim(put(variable,8.)); 

			if eof then
			call symputx("SORTSTRING", domainkeys);
		run;
		proc sort data=&dataset;
			by &SORTSTRING;
		run;

		/*add seq value */
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
	%end;
	options notes;
	%put NOTE:  ==The SortOrder executed completed.== ;
%mend SortOrder;
