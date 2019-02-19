/* **************************************************************
* macro cdsic.sas
* Create the xpt datasets and define.xml file for ADaM and SDTM
* Call macro p21_validate to validate the exported xpt datasets
* standard:  ADaM or SDTM
* file: specify the metadata file. the default is the adam_metadata.xlsx
* or sdtm_metadata.xlsx file under the project folder
* **************************************************************/
%macro cdsic(standard, file)/minoperator ;
	%if %sysfunc(fileexist(&pdir&standard))=0 %then %do;
		data _null_;
			NewDir=dcreate("&standard","&pdir");
		run; 
	%end;
	%if %superq(file)=  %then %let file=&standard._METADATA.xlsx;

	%local i;
	%let path=&pdir.&standard;
	%let metadatafile=&pdir.&file;
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

	%make_define(path=&path, metadata=&metadatafile);

	%sysexec copy &proot.pub\define2-0-0.xsl &path.\define2-0-0.xsl;
	
	%if %upcase(&standard) = ADAM %then %do;
		%let ctdatadate=2016-03-25;
		%let config=ADaM 1.0.xml;
	%end;
	%else %if %upcase(&standard) = SDTM  %then %do;
		%let ctdatadate=2016-06-24;
		%let config=SDTM 3.2.xml;
	%end;
	%else %put WARN ING: The standard is &standard. Please run p21_validate with correct parameters manually.;

	%p21_validate(type=&standard, sources=&path , ctdatadate=&ctdatadate, config=&config);

%mend cdsic;

