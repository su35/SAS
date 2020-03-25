/*********************************************************************************************
**	macro BinEasy: Discretize the numeric variables
**	dn: The name of the dataset that need analysis
**	outdn: The name of the dataset that contain the result
**	pdn: The name of the dataset that contain the variable information
**	vlist: The list of variables that need discretized
**	target: The target variable
**	nbin: The binning number
**	method: The discretizing method. 1: Equal frequency; 2: Equal distance; 3:Quantile
**********************************************************************************************/
%macro BinEasy(dn, outdn=easybin, pdn=vars, method=, nbins=, vlist=, target=);
	%local i varnum var varlist bsize;
	options nonotes;

	%strtran(vlist)
	proc sql noprint;
		select variable
		into :varlist separated by " "
		from &pdn
		where variable in (&vlist) and class="interval";

		%if %sysfunc(exist(&outdn))=0 %then %do;
		create table &outdn
		( variable char(32) label='Variable',
		  d_var char(1000)  label='Bin Variable',
		  ef_code char(1000)  label='EqFreq Code',
		  ed_code char(1000)  label='EqDist Code',
		  qt_code char(1000)  label='Quant Code');
		%end;

		%if %superq(target)= %then %do;
		select variable
		into :target
		from &pdn
		where target not is missing;
		%end;
	quit;

 	%let varnum=%sysfunc(countw(&varlist));
	%do i=1 %to &varnum;
		%let var=%scan(&varlist, &i, %str( ));
		%if %length(&var)>30 %then %let b_var=b_%substr(&var, 1, 30);
		%else %let b_var=b_&var;
		%if %superq(method)= %then %do;
			%EqFreq()
			data &outdn;
				update &outdn work.be_&outdn;
				by variable;
			run;
			%EqDist();
			data &outdn;
				update &outdn work.be_&outdn;
				by variable;
			run;
			%quant();
			data &outdn;
				update &outdn work.be_&outdn;
				by variable;
			run;
		%end;
		%else %do;
			%if &method = 1 %then %EqFreq();
			%else %if &method=2 %then %EqDist();
			%else %quant();
			data &outdn;
				update &outdn work.be_&outdn;
				by variable;
			run;
		%end;
	%end;

	proc datasets lib=work noprint;
	   delete be_: ;
	run;
	quit;

	options notes;
	%put NOTE: ====Macro BinEasy exacute completed, result stored in Easybin====;
%mend;
%macro EqFreq();
	%local j;
	proc sort data=&dn (keep=&var &target) out=work.be_&dn.var;
		by &var;
	run;

	data work.be_&dn.var;
		set work.be_&dn.var end=eof;
		_obs = _n_;
		if eof then call symputx("bsize", _obs/&nbins);
	run;

	data work.be_&outdn;
		variable="&var";
		d_var="&b_var";
		ef_code="select; when (missing(&var)) &b_var=-1;"
		%do j = 1 %to %eval(&Nbins-1);
			||"when (&var<=&j*&bsize) &b_var=&j;"
		%end;
		||"otherwise &b_var=&Nbins; end;";
	run;
%mend;
%macro EqDist();
	%local j;
	data _null_;
		set &pdn;
		where variable="&var";
		call symputx("bsize", (max-min)/&nbins);
	run;

	data work.be_&outdn;
		variable="&var";
		d_var="&b_var";
		ed_code="select; when (missing(&var)) &b_var=-1;"
		%do j = 1 %to %eval(&Nbins-1);
			||"when (&var<=&j*&bsize) &b_var=&j;"
		%end;
		||"otherwise &b_var=&nbins; end;";
	run;
%mend;
%macro quant();
	options noquotelenmax;

	%local q1 mediam q3;
	data _null_;
		set &pdn;
		where variable="&var";
		call symputx("q1", q1);
		call symputx("median", median);
		call symputx("q3",q3);
	run;

	data work.be_&outdn;
		variable="&var";
		d_var="&b_var";
		qt_code="select; when (missing(&var)) &b_var=-1; 
when (&var<=&q1) &b_var=1; when (&var<=&median) &b_var=2; 
when (&var<=&q3) &b_var=3; otherwise &b_var=4;end;";
	run;
	options quotelenmax;
%mend;
