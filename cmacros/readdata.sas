/* ****************************************************************************
 * macro ReadData.sas: read the data stored in local external files
 * option minoperator: make the in() operator is available in macro, 
 * parameters 
 * path: the folder where the data is stored. default is the data folder.
 * lib: the library where the dataset would be stored.default is ori.
 * ext: specify the file type(extention name) in which the data would be input.
 * 	default is empty which means all types.
 * oriname: specify the file name in which the data would be input.
*  	default is empty which means all file.
* struc: specify the data structure if it is available, for input statement.
 * *****************************************************************************************************/
%macro ReadData(path=&pdir.data, lib=ori, ext=, oriname=, delm=, struc= ) /minoperator;
	options nosource;
	%local filrf rc pid  position fullname type name i j suff;
	%if %superq(oriname)= %then
		%do;
			%let rc=%sysfunc(filename(filrf,&path));
			%let pid=%sysfunc(dopen(&filrf));
			%if &pid eq 0 %then
				%do;
					%put Directory &path cannot be open or does not exist;
					%return;
				%end;

			%let ext=%upcase(&ext);
			%do i = 1 %to %sysfunc(dnum(&pid));
				%resolvefile()
				%if &type ne %then %readfile();
			%end;
			%MetaShort(&lib)
		%end;
	%else
		%do;
			%resolvefile()
			%readfile()
		%end;
	options source;
	%put NOTE: == Row data have been read to library ori. ==;
	%put NOTE: == Macro ReadData runing completed. ==;
%mend ReadData;

/* ******************************************************
 * macro resolvefile.sas resolve the file name and type
 * *******************************************************/
%macro resolvefile() /minoperator;
	%if %superq(oriname) eq %then
		%let fullname=%qsysfunc(dread(&pid, &i));
	%else %let fullname=&oriname;
	%let position=%sysfunc(find(&fullname, . ,-99));
	%let type=%upcase(%scan(&fullname, -1, .));
	%let name=%qsubstr(&fullname, 1 , &position-1);
	%let name=%sysfunc(prxchange(s![^a-z_0-9]!_!i, -1, &name));
 	%let name=%sysfunc(prxchange(s![_]+!_!i, -1, &name));

	%if &position > 33 %then
		%do;
			%put WARNING- The length of the file &name is over 32 and has been truncated to 32;
			%let name=%substr(&name, 1 , 32);
		%end;

	%if %superq(ext) ne and %superq(oriname) eq %then
		%do;
			/*if combined with above statement, %eval() will evaluate all condition. 
			if the ext is empty, the %eval() will eject an error in log*/
			%if not (&type  in &ext) %then
				%let type=;
		%end;
%mend resolvefile;

%macro readfile() /minoperator;
	%local i;
	%if &type in(TXT CSV DAT DATA ASC) %then
		%do;
			%if %length(%superq(struc))=0 %then
				%do;
					%if &type = TXT or &type=DAT or &type=ASC %then
						%let type=tab;
					proc import datafile = "&path\&fullname"
						out=&lib..&name
						dbms=&type
						replace;
						getnames=yes;
						%if %length(%superq(delm)) ne 0 %then	delimiter="&delm"%str(;) ;
						guessingrows=max;
						%*a large number will take some time, but it is faster than semi-automatic;
					run;
				%end;
			%else
				%do;
					data &lib..&name;
						infile "&path\&fullname" truncover %if &ext=csv %then dsd;
						%str(;)
						input &struc;
					run;
				%end;
		%end;
	%else %if &type eq SAS7BDAT %then
		%do;
			libname templb "&path";
			proc datasets noprint;
				copy in=templb out=&pname memtype=data;
				select &name;
			run;
			quit;
			libname templb clear;
		%end;
	%else %if &type eq XPT %then
		%do;
			libname templb XPORT "&path\&fullname";

			proc copy in=templb out=&pname memtype=data;
			run;

			libname templb clear;
		%end;
	%else %if &type in (XLS XLSB XLSM XLSX) %then
		%do;
			libname templb excel "&path\&fullname";

			proc sql noprint;
				select tranwrd(trim(compress(memname, ,"p")), " " , "_") as setname, 
					case when substr(memname, 1,1)= "'" then memname 
						else quote(trim(memname)) end as tname 
				into :setname1-:setname999, :tname1-:tname999
				from sashelp.vtable
				where libname= "TEMPLB" and memname ? "$";
				%let num=&sqlobs;
			quit;

			%do i=1 %to &num;
				/*if there is a same name of dataset, then rename */
				%if %sysfunc(exist(&lib..&&setname&i))=1 %then %do;
					%let suff=%substr(&fullname, 1,3);
					%let setname&i=&suff._&&setname&i;
					%if %length(&&setname&i)>32 %then %do; 
						%let setname&i=%substr(&&setname&i, 1,32);
						%put WARNING: &&tname&i in &fullname was renamed to &&setname&i;
					%end;
				%end;

				proc import datafile= "&path\&fullname" 
					out=&lib..&&setname&i
					dbms=excel 
					replace;
					sheet= &&tname&i;
					getnames=yes;
				run;
			%end;

			libname templb clear;
		%end;
	%else  %if &type in (MDB ACCDB) %then
		%do;
			libname templb access "&path\&fullname";

			proc sql noprint;
				select tranwrd(strip(memname), " ","_") , quote(strip(memname))
				into :setname1-:setname999, :tname1-:tname999
				from dictionary.tables
					where  libname= "TEMPLB";
				%let num=&sqlobs;
			quit;
			%do i=1 %to &num;
				%if %sysfunc(exist(&lib..&&setname&i))=1 %then %do;
					%let suff=%substr(&fullname, 1,3);
					%let setname&i=&suff._&&setname&i;
					%if %length(&&setname&i)>32 %then %do; 
						%let setname&i=%substr(&&setname&i, 1,32);
						%put WARNING: &&tname&i in &fullname was renamed to &&setname&i;
					%end;
				%end;

				proc import 
					datatable=&&tname&i
					out=&lib..&&setname&i
					dbms=access
					replace;
					database= "&path\&fullname";
				run;
				%if %sysfunc(nobs(&lib, &&setname&i)) %then 
					%ReLen(lib=&lib, dn=&&setname&i);
			%end;

			libname templb clear %str(;);
		%end;
%mend readfile;
