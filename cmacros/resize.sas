*----------------------------------------------------------------*;
* macro resize,sas
* detect the max length required for a char variable, 
* and then reduce the variable length as the real requirement
*
* MACRO PARAMETERS:
* standard = SDTM or ADaM. 
*----------------------------------------------------------------*;
%macro resize(standard)/minoperator ;
	%local i;
	%if %sysfunc(libref(&standard.file)) ne 0 %then  
		libname &standard.file "&pdir.&standard._METADATA.xlsx";;

	proc sort data = sdtmfile."VARIABLE_METADATA$"n 
				out= _resize(keep= domain variable label LENGTH);
		where upcase(type) in ("TEXT", "DATE", "DATETIME", "TIME", "CHAR");
		by domain;
	run;

	proc sql noprint; 
		select count(distinct domain)  into :number
			from  _resize; 
		select distinct domain
			into :table1- :table%sysfunc(left(&number))
			from  _resize; 
	quit;

	data  _resize (keep=domain variable length);
		set  _resize;
		by domain;
		length modifylist $ 32767 qlist $ 50;
		retain modifylist;
		qlist = 'max(length('||trim(variable)||'))';
		mod_len = get_vars_length("&pname", domain, qlist) + 2;
		if first.domain then modifylist="";
		if mod_len +5 < length then do; 
			mdf=trim(variable)||" char("||trim(left(mod_len))||") format=$"||trim(left(mod_len))||
					". informat=$"||trim(left(mod_len))||".";
			modifylist = catx(",", modifylist, mdf) ;
			length = mod_len; put modifylist=;
		end;
		if last.domain then call symputx(trim(domain)||"modifylist", modifylist);
		if mdf ne "";
	run;

	%do i=1 %to &number;
		%let setname=&&table&i;
		%let modifylist = &&&setname.modifylist;
		%if not(%superq(modifylist)= )  %then %do;
			proc sql;
				alter table &&table&i
					modify &modifylist;
			quit;
		%end;
	%end;
	proc print data= _resize;
		title 'Modify variable length as below in &standard metadata file'; 
	run;
	title 'The SAS System';
%mend resize;
