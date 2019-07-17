/* *************************************************************************
* MetaShort
* report the metadata of variables in the given lib including name, type,
* length, format, informat, and label
* *************************************************************************/
%macro MetaShort(lib);
	%if %superq(lib)= %then %let lib=&pname;
	proc format;
		value type 2="Char"
					1 = "Num";
	run;

	proc datasets library=&lib  memtype=data  ;
				contents data=_all_  out=work.temp  ;
	run;
	quit;

	proc sql noprint;
		select path into: libpath
		from Dictionary.members
		where libname =upcase("&lib");          
	quit;

	%let libpath=%sysfunc(strip(&libpath));

	title "Datasets in &lib";
	ods html5 path="&libpath" (url="")
	body="meta.html";
	proc report data=work.temp headline headskip spacing=2 ;
		columns memname name type length format informat label;
		define memname /order order=data "Dataset" ;
		define name /display  "Variable";
		define type /display  format=type. "Type";
		define length /display  "Length";
		define format /display "Format";
		define informat /display  "Informat";
		define label /display  "Label";
		compute after memname;
		line ' ';
		endcomp;
	run;
	ods html5 close;
	ods html;
	title ;
%mend MetaShort;
