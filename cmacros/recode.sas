/* *********************************************************
	macro recode
	create the code to recode the char variables to numeric variables
	dn: the dataset that the variables need recode
	path: full folder path to outfile(include the last /). default is project folder
	outfile: the file name which contain the recode code. default is recode.sas
* **********************************************************/	
%macro recode(dn, outfile, path);
	%if %superq(dn)=  %then %do;
			%put ERROR: ======== the dataset is missing========== ;
			%goto exit;
		%end;
	%if %superq(outfile)=  %then %let outfile=recode;
	%if %superq(path)=  %then %let path=&pdir;
	%local i j;
	proc sql noprint;
		select name, count(name)
		into :cvarlist separated by " ", :varnum
		from dictionary.columns
		where libname=upcase("&pname") and memname=upcase("&dn") and type="char";
		
		%do i=1 %to &varnum;
			%let name=%scan(&cvarlist, &i, %str( ));
			select distinct &name as val, count(distinct &name)
				into :v_&name separated by " ", :n_&name
				from &dn;	
		%end;
	quit;
	
	filename &outfile "&path.&outfile..sas";
	data _null_;
		file &outfile;
		%do i=1 %to &varnum;
			%let name=%scan(&cvarlist, &i, %str( ));
/*			put "select (&name);";
			%do j=1 %to 	&&n_&name;
				%let value=%scan(&&v_&name, &j, %str( ));
				put "when %bquote(('&value')) &name._n=&j;";
				%if &j=&&n_&name %then put "otherwise &name._n=.; end;"; ;
			%end;*/
			put "&name._n=";
			%do j=1 %to 	&&n_&name;
				%let value=%scan(&&v_&name, &j, %str( ));
				%if &j ne &&n_&name %then put "&j*(&name='&value')+";
				%else put "&j*(&name='&value');"; ;
			%end;

		%end;
	run;
%exit:
%mend recode;
