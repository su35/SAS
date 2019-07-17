/* ***************************************************** 
* macro RemoveAttrib: remove the specified attribute
* parameters
* lib: the name of the library
* setlist: the names of the datasets that would be modified
* attrib: format, informat, label. if not sepcify, remove all
 ********************************************************/
%macro RemoveAttrib(lib=, setlist=, attrib=);
	%local i setlist setnum;
	%if %superq(lib)=  %then %do;
		%if %sysfunc(libref(&pname)) = 0 %then %let lib=&pname;
		%else lib=WORK;
	%end;
	options nonotes;
	%if %superq(setlist)= %then %do;
		proc sql noprint;
			select memname, count(distinct memname) 
				into :setlist separated by ' ', :setnum
				from dictionary.tables
				where libname="%upcase(&lib)";
		quit;
	%end;
	
	%let i=1;
	%let setname = %scan(&setlist, &i, %str( ));
	%do %until (&setname= );
		proc datasets lib=&lib memtype=data noprint;
			modify &setname;
			%if &attrib= %then %do;
				attrib _all_ label=' '%str(;)
				attrib _all_ format=%str(;)
				attrib _all_ informat=%str(;)
			%end;
			%else %if &attrib=format %then attrib _all_ format=%str(;);
			%else %if &attrib=informat %then attrib _all_ informat=%str(;);
			%else %if &attrib=label %then attrib _all_  label=""%str(;);
			%else %put ERROR: the attrib error;
		run;
		quit;
		%let i=%eval(&i+1);
		%let setname = %scan(&setlist, &i, %str( ));
	%end;
	options notes;
	%put NOTE: == Macro RemoveAttrib runing completed. ==;
%mend RemoveAttrib;
