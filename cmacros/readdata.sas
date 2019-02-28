/* ****************************************************************************
 * macro readdata.sas: read the data stored in local external files
 * option minoperator: make the in() operator is available in macro, 
 * parameters
 * path: the folder where the data is stored. default is the data folder.
 * lib: the library where the dataset would be stored.default is ori.
 * ext: specify the file type(extention name) in which the data would be input.
default is empty which means all types.
* oriname: specify the file name in which the data would be input.
default is empty which means all file.
* struc: specify the data structure if it is available, for input statement�?
 * *****************************************************************************************************/
%macro readdata(path=&pdir.data, lib=ori, ext=, oriname=, delm=, struc= ) /minoperator;
	*options nosource;
	%local filrf rc pid  position fullname type name i;

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
				%resolvefile();

				%if &type ne %then
					%do;
						%readfile();
					%end;
			%end;

			%meta_short(&lib);
		%end;
	%else
		%do;
			%resolvefile();
			%readfile();
		%end;

	*options source;
%mend readdata;

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

	%if &position > 33 %then
		%do;
			%let name=%substr(&name, 1 , 32);
			%put NOTES- The length of the file name is over 32 and has been truncated to 32;
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

	%if &type in(TXT CSV DAT ASC) %then
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

						%if %length(%superq(delm)) ne 0 %then
							delimiter="&delm"; ;
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
						run

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
				create table work.temp as
					select tranwrd(trim(compress(memname, ,"p")), " " , "_") as setname, 
						case 
							when substr(memname, 1,1)= "'" then memname 
							else "'"||trim(memname)||"'" 
						end 
					as tname 
						from sashelp.vtable
							where libname= "TEMPLB" and substr(memname, length(memname), 1) in ("'" "$");
				select count(distinct setname) into :number
					from work.temp;
				select tname, setname
					into :table1- :table%sysfunc(left(&number)), 
						:sname1-:sname%sysfunc(left(&number))
					from work.temp;
			quit;

			%do i=1 %to &number;

				proc import datafile= "&path\&fullname" 
					out=&lib..&name._&&sname&i 
					dbms=excel 
					replace;
					sheet= &&table&i;
					getnames=yes;

					%*	        mixed=yes;
				run;

			%end;

			libname templb clear;
		%end;
	%else  %if &type in (MDB ACCDB) %then
		%do;
			libname templb access "&path\&fullname";

			proc sql noprint;
				create table work.temp as
					select tranwrd(trim(memname)," " ,"_") as setname, "'"||trim(memname)||"'" as tname,  name as vname, 
						'max(length('||trim(name)||'))' as qlist, . as len
					from dictionary.columns
						where  libname= "TEMPLB" and type = "char"
							order by setname, tname;
				select count(distinct tname) into :number
					from work.temp;
				select distinct tname, setname
					into :table1- :table%sysfunc(left(&number)), 
						:sname1-:sname%sysfunc(left(&number))
					from work.temp;
			quit;

			%do i=1 %to &number;

				proc import 
					DATATABLE=&&table&i
					out=&lib..&name._&&sname&i 
					dbms=access
					replace;
					database= "&path\&fullname";
				run;

			%end;

			data work.temp;
				set work.temp;
				by setname;
				length modifylist $ 32767;
				retain modifylist;
				len = get_vars_length("&lib",setname,qlist);

				if first.setname then
					modifylist="";
				mdf=trim(vname)||" char("||trim(left(len))||") format=$"||trim(left(len))||
					". informat=$"||trim(left(len))||".";
				modifylist = catx(",", modifylist, mdf);

				if last.setname then
					call symputx(trim(setname)||"modifylist", modifylist);
			run;

			proc sql noprint;
				%do i=1 %to &number;
					%let setname=&&sname&i;
					alter table &lib..&name._&&sname&i
						modify &&&setname.modifylist;
				%end;
			quit;

			libname templb clear %str(;);
		%end;
%mend readfile;
