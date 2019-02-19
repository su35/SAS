/* ************************************************
* macro get_vars_length.sas: get the real max length for given variable
* usage: call by custome call routine get_vars_length
* **************************************************/

%macro get_vars_length;
	%let lib = %sysfunc(compress(&lib,"'"));
	%let dataset = %sysfunc(compress(&dataset,"'"));
	%let query = %sysfunc(compress(&query,"'"));

	proc sql noprint;
		select &query into :len
			from &lib..&dataset;
	quit;
%mend get_vars_length;
