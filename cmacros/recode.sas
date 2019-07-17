/* *******************************************************************************
** macro ReCode: translate the char value to num value.
** dn: the dataset name. it can be a variable define dataset or a data dataset
** outfile: name of re-code map dataset and re-cord txt file
** dtype: if the dn is the variable define dataset, the default is 1. If the dn is 
**  data dataset the dtype shoud be declare as 0 clearly.
** *******************************************************************************/
%macro ReCode(dn, outfile=ReCode, path=, dtype=1 );
	%if %superq(dn)=  %then %do;
			%put ERROR: ======== the dataset is missing========== ;
			%return;
		%end;
	%if %superq(path)=  %then %let path=&pout;
	options nonotes;
	%if &dtype=1 %then %defi_code();
	%else %if &dtype=0 %then %radn_code();

	options notes;
	%put  NOTE:  ==The dataset &outfile and &outfile..txt under &path were created.==;
	%put  NOTE:  ==The macro ReCode executed completed. ==;
%mend ReCode;

%macro defi_code();
	proc sql noprint;
		select distinct dataset as dataset
		into :dataset1-:dataset999
		from &dn;
	quit;
	%let dnum=&sqlobs;
	%do i=1 %to &dnum;
		proc sort data=&dn out=work._&dn;
			by vid;
			%if &dnum>1 %then where dataset="&&dataset&i"%str(;) ;
		run;
		%local tnum tnum2;
		proc sql noprint;
			select count(distinct variable)*35 as tnum, 2*(calculated tnum) as tnum2  
			into :tnum, :tnum2
			from work._&dn;
		quit;

		data work._&outfile;
			length dataset $32;
			set work._&dn end=eof;
			where type="char" or not missing(value_n);
			by vid;
			length code $ 100 d $&tnum r $&tnum2 ;
			retain newv d r;
			%if &dnum>1 %then dataset="&&dataset&i"%str(;);
			if _N_=1 then do;
				d= "drop ";
				r="rename ";
			end;
			if first.vid then do;
				newv=1;
				if missing(value_n) then value_n=newv;
				code="select ("||trim(variable)||"); when ('"||trim(value_c)||"') "||strip(variable)||"_n="||trim(left(value_n))||";";
				d=catx(" ", d, variable);
				r=catx(" ", r, trim(variable)||"_n="||trim(variable));
			end;
			else if last.vid=0 then do;
				if missing(value_n) then value_n=newv;
				code=" when ('"||trim(value_c)||"') "||strip(variable)||"_n="||trim(left(value_n))||";";
			end;
			else do; 
				if missing(value_n) then value_n=newv;
				code=" when ('"||trim(value_c)||"') "||strip(variable)||"_n="||trim(left(value_n))||";end;";
			end;
			newv+1;
			if eof then do;
				droplist=trim(d)||";";
				renamelist=trim(r)||";";
			end;
			keep dataset variable value_c value_n code droplist renamelist;
		run;
		filename code %if &dnum>1 %then "&path.&&dataset&i.._&outfile..txt"%str(;);
						%else "&path.&outfile..txt"%str(;);
		data _null_;
			set work._&outfile end=eof;
			rc=fdelete("code");
			file code lrecl=32767;
			put code;
			if eof then put #3 droplist  #4 renamelist;	
		run;
		%if %sysfunc(exist(&outfile)) %then %do;
			proc sql noprint;
				delete from &outfile where dataset="&&dataset&i";
			quit;
		%end;
		proc append base=&outfile data=work._&outfile force;
		run;
	%end;
%mend;

%macro radn_code();
	ods output OneWayFreqs=work.tmp_freq;
	proc freq data=&dn nlevels;
		table _char_/missing nocum;
	run;
	ods output close;
	proc sort data=work.tmp_freq;
		by table;
	run;

	%local tnum tnum2;
	proc sql noprint;
		select count(distinct table)*35 as tnum, 2*(calculated tnum) as tnum2  
		into :tnum, :tnum2
		from work.tmp_freq;
	quit;

	data work._&outfile(rename=(table=variable));
		length dataset $32;
		set work.tmp_freq end=eof;
		by table;
		length d droplist $&tnum r $&tnum2;
		retain d r;
		dataset="&dn";
		table=substr(table, 7);
		value_c=cats(of F_:);
		if _N_=1 then do;
			d= "drop ";
			r="rename ";
		end;
		if first.table then do;
			n=1;
			code=trim(table)||"_n="||trim(left(n))||"*("||trim(table)||'="'||trim(value_c)||'")+';
			d=catx(" ", d, table);
			r=catx(" ", r, trim(table)||"_n="||trim(table));
		end;
		else if last.table then code=trim(left(n))||"*("||trim(table)||'="'||trim(value_c)||'");';
		else code=trim(left(n))||"*("||trim(table)||'="'||trim(value_c)||'")+';
		value_n=n;
		n+1;
		if eof then do;
			droplist=trim(d)||";";
			renamelist=trim(r)||";";
		end;
		keep dataset table value_c value_n code droplist renamelist;
	run;
	filename code "&path.&dn._&outfile..txt";
	data _null_;
		set work._&outfile end=eof;
		rc=fdelete("code");
		file code lrecl=32767;
		put code;
		if eof then put #2 droplist  #3 renamelist;	
	run;
	%if %sysfunc(exist(&outfile)) %then %do;
		proc sql noprint;
			delete from &outfile where dataset="&dn";
		quit;
	%end;
	proc append base=&outfile data=work._&outfile force;
	run;
%mend;
