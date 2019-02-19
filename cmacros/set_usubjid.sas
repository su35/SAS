%macro set_usubjid(dataset=, length=, siteid=1);
	%if &siteid =1 %then %let usubjid=%str(catx('.',studyid,siteid,subjid));
	%else %let usubjid=%str(catx('.',studyid,subjid));

	proc sql noprint;
	%if %superq(dataset)=  %then %do;
		select   count(memname)
			into :count
			from dictionary.tables
			where libname='ORI';
		select  trim(memname)
			into : dataset1- :dataset%sysfunc(left(&count))
			from dictionary.tables
			where libname='ORI';
		%do i=1 %to &count;
			alter table ori.&&dataset&i
				add usubjid char &length format=$&length..;
			update ori.&&dataset&i
				set usubjid=&usubjid;
		%end;
	%end;
	%else %do;
		alter table ori.&dataset
			add usubjid char &length format=$&length..;
		update ori.&dataset
				set usubjid=&usubjid;
	%end;
	quit; 
%mend set_usubjid;
