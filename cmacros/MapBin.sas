/*******************************************************/
/* Macro MapBin */
/*******************************************************/
%macro MapBin(DSin, Varlist, preVarX, preMap, DSout);
	/* Applying a mapping scheme; to be used with 
	macro BinContVar */

	/* Generating macro variables to replace the cetgories with their bins */
	%if %superq(DSout) = %then %let DSout=&DSin;
	%else %do;
		data &dsout;
			set &dsin;
		run;
		%end;
	%local m i;
	%let d = 1;
	%do %while(%scan(&varlist,&d, %str( ))^= );
		%let VarX=%scan(&varlist,&d,%str( ) );

		proc sql noprint;
			select count(Bin) into:m from &preMap._&varx;
		quit;

		%do i=1 %to &m;
			%local Upper_&i Lower_&i Bin_&i;
		%end;

		data _null_;
			set &preMap._&varx;
			call symput ("Upper_"||left(_N_), UL);
			call symput ("Lower_"||left(_N_), LL);
			call symput ("Bin_"||left(_N_), Bin);
		run;

		/* the actual replacement */
		Data &DSout;
			set &DSout;

			/* first bin - open left */
			IF &VarX < &Upper_1 Then
				&preVarX&VarX=&Bin_1;

			/* intermediate bins */
			%do i=2 %to %eval(&m-1);
				if &VarX >= &&Lower_&i and &VarX < &&Upper_&i Then
					&preVarX&VarX=&&Bin_&i;
			%end;
			/* last bin - open right */
			if &VarX >= &&Lower_&i Then
				&preVarX&VarX=&&Bin_&i;
		Run;
		%let d=%eval(&d+1);
	%end;

%mend;
