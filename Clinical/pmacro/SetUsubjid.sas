%macro SetUsubjid(lib=ori, dataset=, length=, siteid=1);
	%if &siteid =1 %then %let usubjid=%str(catx('.',studyid,siteid,subjid));
	%else %let usubjid=%str(catx('.',studyid,subjid));
	options nonotes;
	proc sql noprint;
	%if %superq(dataset)=  %then %do;
		select   count(memname)
			into :count
			from dictionary.tables
			where libname="%upcase(&lib)";
		select  trim(memname)
			into : dataset1- :dataset%sysfunc(left(&count))
			from dictionary.tables
			where libname="%upcase(&lib)";
		%do i=1 %to &count;
			alter table &lib..&&dataset&i
				add usubjid char &length format=$&length..;
			update &lib..&&dataset&i
				set usubjid=&usubjid;
		%end;
	%end;
	%else %do;
		alter table &lib..&dataset
			add usubjid char &length format=$&length..;
		update &lib..&dataset
				set usubjid=&usubjid;
	%end;
	quit; 
	options notes;
	%put NOTE: == The usubjid has been set. ==;
	%put NOTE: == Macro SetUsubjid runing completed. ==;
%mend SetUsubjid;
