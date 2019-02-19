/* **********************************************************
* macro check_missing.sas: Ckeck are there missing values
* in SDTM required varailbles
* usage: call by custome call routine
* **********************************************************/
%macro check_missing;
	%let dataset = %sysfunc(compress(&dataset,"'"));
	%let variable = %sysfunc(compress(&variable,"'"));

	proc freq data=&dataset noprint;
		table &variable / out=_missing;
	run;
	data _missing(drop=percent &variable);
		attrib dataset length = $32;
		attrib variable length = $32;
		attrib nmissing length = 8;
	 	set _missing (obs=1 rename=(count=nmissing));
		variable = "&variable";
		dataset = "&dataset"; 
		if missing(&variable);
	run;

	data misvalue;
		set 
		%if %sysfunc(exist(misvalue)) %then misvalue;
		 _missing;
	run;
%mend check_missing;

