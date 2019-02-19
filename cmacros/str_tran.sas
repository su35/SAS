/* *********************************************************
	macro str_tran
	add or remove the quotation marks surrounding variables
* **********************************************************/
%macro str_tran(list);
	%if %index(&&&list, %str(%")) or %index(&&&list, %str(%')) %then 
		%let &list=%cmpres(%sysfunc(prxchange(s/[^\w_]/%str( )/i, -1, &&&list)));
	%else %do;
		%let &list=%sysfunc(tranwrd(%sysfunc(compbl(&&&list)), %str( ),%str(" ")));
		%let &list="&&&list";
		%end;
%mend;
