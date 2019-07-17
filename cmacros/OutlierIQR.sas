/****************************************************************
This macro will list and remove outliers based on the interquartile range.
The original dataset is renamed with suffix _ori. The outliers keep in _temp_dataset name

dataset: the data set name 
id: the ID variable 
var:   Variables to test for outliers  
n_iqr:  Number of interquartile ranges. The default is 1.5
method: list, delet or modify. The default is list
miss: How to treat missing value. 0 as outliers, 1 as keep. 
****************************************************************/
%macro OutlierIQR(dataset=, id=, var=,  n_iqr=1.5, method=list, miss=1 );
	%local err;

	%if %superq(dataset)= %then
		%do;
			%put ERROR: No dataset assigned;
			%let err=1;
		%end;
	%if %superq(id)=  %then
		%do;
			%put ERROR: No id variable assigned;
			%let err=1;
		%end;

	%if %superq(err) ne %then
		%goto exit;

	proc sql;
		select text into: title
		from Dictionary.Titles
		where number =1 and type="T";          
	quit;

	/*since the following code will refer the vars, so not use the _numeric_*/
	%if %superq(var)= %then %do;
		proc sql noprint;
			select name into: var separated  by ' '
			from dictionary.columns where libname=upcase("&pname") 
			and memname = upcase("&dataset") and type = "num" ;

			select name into: vlist separated  by ' '
			from dictionary.columns where libname=upcase("&pname") 
			and memname = upcase("&dataset");
		quit;
	%end;

	ods output Summary=_tmp;
	proc means data=&dataset q1 q3 qrange;
		var &var;
	run;
	ods output close;

	%let q1 =%sysfunc(tranwrd(&var, %str( ), _q1%str( )))_q1;
	%let q3 =%sysfunc(tranwrd(&var, %str( ), _q3%str( )))_q3;
	%let qr =%sysfunc(tranwrd(&var, %str( ), _qrange%str( )))_qrange;

	title1 "Outliers removed From Dataset &dataset (stored in _temp_&dataset) Based on &N_iqr Interquartile Ranges";
	data 
		%if %upcase(&method) ne LIST %then  &dataset._ori &dataset; 
			 _temp_&dataset;
		set &dataset;
		file print;
		if _n_ = 1 then set _tmp;
		keep &vlist;
		length err $ 200;
		mod=0;

		array v_name(*) Vname:;
		array vars(*) &var;
		array q1(*) &q1; 
		array q3(*) &q3; 
		array qr(*) &qr; 

		%if %upcase(&method) ne LIST %then output &dataset._ori;;

		do i=1 to dim(vars);
			if vars[i] le q1[i] -1.5*qr[i] %if &miss=1 %then and not missing(vars[i]);
				or vars[i] ge q3[i] + 1.5*qr[i] 
			then do;
				err=catx(' ',err, v_name[i],'=',vars[i]) ;
				if vars[i] le q1[i] -1.5*qr[i] %if &miss=1 %then and not missing(vars[i]);
					then vars[i] = q1[i] -1.5*qr[i];
				else vars[i] = q3[i] + 1.5*qr[i];
			end;
		end;
		if err ne "" then do;
			put &id= err;
			output _temp_&dataset;
		end;
		%if  %upcase(&method) ne LIST %then else output &dataset ;;
	run;

	%if %upcase(&method)=MODIFY %then %do;
		proc append base=&dataset data=_temp_&dataset; 
		run;
	%end;
	 title1 "&title";
%exit:
%mend;
