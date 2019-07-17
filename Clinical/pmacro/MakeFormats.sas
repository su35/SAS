*---------------------------------------------------------------*;
* MakeFormats.sas creates a permanent SAS format library
* stored to the libref LIBRARY from the codelist metadata file 
* _metadata.xlsx.  The permanent format library that is created
* contains formats that are named as the codelistname in the 
* codelist sheet. 
*---------------------------------------------------------------*;
%macro MakeFormats(standard, lib=&pdir.lib);
	/*must use the name "library", so that SAS can automatically see the SAS formats 
	without having to specify FMTSEARCH explicitly in the OPTIONS statement.*/
	%if %superq(standard)= %then %let standard=SDTM;
	libname library "&lib"; 
	%if %sysfunc(libref(&standard.file)) ne 0 %then  
		libname &standard.file "&pdir.&standard._METADATA.xlsx";;

	options nonotes;
	/* make a proc format control dataset out of the SDTM metadata;*/
	options varlenchk=nowarn;
	data formatdata;
		length fmtname $ 32 start end $ 16 label $ 200 type $ 1;
		set &standard.file."CODELISTS$"n;
		/*where setformat = 1;
		where sourcevalue ne "";*/
		keep fmtname start end label type;
		fmtname = compress(codelistname);
		%if &standard = SDTM %then %do;
			start = trim(scan(sourcevalue, 1,','));
			end = trim(scan(sourcevalue, -1,','));			
		%end;
		%else %if &standard = ADaM %then %do;
			start = trim(scan(CODEDVALUE, 1,','));
			end = trim(scan(CODEDVALUE, -1,','));
		%end;
		label = left(codedvalue);
		if upcase(sourcetype) in ("NUMBER", "NUM", "N","INTEGER","FLOAT") then
		    type = "N";
		else if upcase(sourcetype) in ("CHARACTER", "TEXT", "CHAR", "C") then
		    type = "C";
	run;

	/* create a SAS format library to be used in SDTM conversions;*/
	proc format
	    library=library
	    cntlin=formatdata
	    fmtlib;
	run;
	options varlenchk=warn;
	options notes;
	%put NOTE:  ==The macro MakeFormats executed completed.==;
	%put NOTE:  ==The formats are stored in &lib.==;
%mend MakeFormats;
