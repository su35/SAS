%macro create_cdsic(standard, file=sdtm_metadat.xlsx)/minoperator ;
	%if %sysfunc(fileexist(&pdir&standard))=0 %then %do;
		data _null_;
			NewDir=dcreate("&standard","&pdir");
		run; 
	%end;

	%local i;
	%let metadatafile=&path\&file;
	proc import 
		datafile="&metadatafile"
		out=_temp 
		dbms=excelcs
		replace;
		sheet="TOC_METADATA";
	run;
	proc sql noprint;
		select name, count(name)
			into :dmlist separated " ", :dmnum
			from _temp;
	quit;
	%do i = 1 %to &dmnum;
		%let dataset = %scan(&dmlist, &i, ' ' ); 
		libname &dataset xport "&path.\&dataset..xpt";
		proc copy
			in=&pname out=&dataset;
			select &dataset;
		run;
	%end;
*	%let metadata = %scan(&metadatafile, -1, \);
	%make_define(path=&path,metadata=&file);
%mend create_cdsic;

%create_cdsic(SDTM);
