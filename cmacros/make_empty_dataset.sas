*---------------------------------------------------------------*;
* make_empty_dataset.sas creates a zero record dataset based on a 
* dataset metadata spreadsheet.  The dataset created is called
* EMPTY_** where "**" is the name of the dataset.  This macro also
* creates a global macro variable called **keeplist that holds 
* the dataset variables desired and listed in the order they  
* should appear.  [The variable order is dictated by VARNUM in the 
* metadata spreadsheet.]
*
* MACRO PARAMETERS:
* standard = ADaM or SDTM
* dataset = the dataset or domain name you want to extract
*---------------------------------------------------------------*;
%macro make_empty_dataset(standard, dataset=)/minoperator;
	%local i j;
	%if %sysfunc(libref(&standard.file)) ne 0 %then  
		libname &standard.file "&pdir.&standard._METADATA.xlsx";;

	%if %superq(dataset)=  %then %do;
		proc sql noprint;
			select distinct domain, count(distinct domain)
				into :dmlist separated " ", :dmnum
				from &standard.file."VARIABLE_METADATA$"n;
		quit;
	%end;
	%else %let dmnum=1;
	%do j = 1 %to &dmnum;
		%if &dmnum > 1  %then %let dataset = %scan(&dmlist, &j, ' ' ); 
		** sort the dataset by expected specified variable order;
		proc sort 	data=&standard.file."VARIABLE_METADATA$"n out=_settemp;
			where domain = upcase("&dataset");
			by varnum;	  
		run;
	** create keeplist macro variable and load metadata 
	** information into macro variables;
		%global &dataset.keeplist;
		data _null_;
			set _settemp nobs=nobs end=eof;
			length format $ 20.;
			if _n_=1 then
			call symput("vars", compress(put(nobs,3.)));

			call symputx('var'    || compress(put(_n_, 3.)), variable);
			call symputx('label'  || compress(put(_n_, 3.)), label);
			call symputx('length' || compress(put(_n_, 3.)), put(length, 3.));

			** valid ODM types include TEXT, INTEGER, FLOAT, DATETIME, 
			** DATE, TIME and map to SAS numeric or character;
			if upcase(type) in ("INTEGER", "FLOAT") then
			call symputx('type' || compress(put(_n_, 3.)), "");
			else if upcase(type) in ("TEXT", "DATE", "DATETIME", "TIME", "CHAR") then
			call symputx('type' || compress(put(_n_, 3.)), "$");
			else
			put "ERR" "OR: not using a valid ODM type.  " type=;

/*			if upcase(codelistname) not in ( "", "AEBODSYS","AEDECOD" ) then format = codelistname;
			else format = "";
call symputx('format' || compress(put(_n_, 3.)), trim(format));*/


			** create **keeplist macro variable;
			length keeplist $ 32767;	 
			retain keeplist;		
			keeplist = compress(keeplist) || "|" || left(variable); 
			if eof then
			call symputx(upcase(compress("&dataset" || 'keeplist')), 
			           left(trim(translate(keeplist," ","|"))));
		run;
		** create a 0-observation template data set used for assigning 
		** variable attributes to the actual data sets;
		data EMPTY_&dataset;
			%do i=1 %to &vars;           
				attrib &&var&i label="&&label&i"
				%if "&&length&i" ne "" %then
				length=&&type&i.&&length&i... ;
/*				%if "&&format&i" ne ""  %then
				format = &&type&i.&&format&i...;*/
				;
				%if &&type&i=$ %then
				retain &&var&i '';
				%else
				retain &&var&i .;
				;
			%end;
			if 0;
		run;
	%end;
%mend make_empty_dataset;
