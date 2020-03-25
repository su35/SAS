/* *********************************************************************************************/
* macro BinHPSplit: discretize the interval variables and collaspsing the levels of 
* the ordinal and nominal variables by proc hpsplit ;
/* ********************************************************************************************/
%macro BinHPSplit()/minoperator;
	%if %upcase(&t_class) =INTERVAL %then %let t_class=int;
	%else %let t_class=nom;
	%local i;

	%if %superq(interval)^= %then %do;
		%let nvars=%sysfunc(countw(&interval));
		%do i=1 %to &nvars;
			%let var=%scan(&interval, &i, %str( ));
			ods exclude PerformanceInfo DataAccessInfo;
			proc hpsplit data=&dn(keep=&target &var) leafsize=&leafsize;
				input &var/level=int;
				target &target/level=&t_class;
				output  nodestats=work.hp_tree;
			run;

			data work.hp_tree;
				length variable d_var $32  cluster $1000 class branch $8;
				set work.hp_tree;
				where decision not is missing;
				variable="&var";
				class="interval";
				d_var="b_"||substr(variable, 1, 30);
				border=input(compress(scan(decision, 1 ," "),"><="), 8.);
				cluster=" ";
				bin=.;
				nlevels=.;
				branch="hps";
				keep variable class d_var border cluster bin nlevels branch;
			run;
			proc sort data=work.hp_tree nodupkey;
				by border;
			run;

			data work.hp_tree;
				set work.hp_tree end=eof;
				if eof then nlevels=_N_+1;
			run;

			proc sql;
				delete from &outdn
				where variable="&var" and branch="hps";
			quit;

			proc append base=work.bv_tree data=work.hp_tree force;
			run;
		%end;
	%end;

	%if %superq(ordinal)^= %then %do;
		%let nvars=%sysfunc(countw(&ordinal));
		%do i=1 %to &nvars;
			%let var=%scan(&ordinal, &i, %str( ));
			ods exclude PerformanceInfo DataAccessInfo;
			proc hpsplit data=&dn(keep=&target &var) leafsize=&leafsize;
				input &var/level=int;
				target &target/level=&t_class;
				output  nodestats=work.hp_tree;
			run;

			data work.hp_tree;
				length variable d_var $32  cluster $1000 class branch $8;
				set work.hp_tree;
				where decision not is missing;
				variable="&var";
				class="ordinal";
				d_var="b_"||substr(variable, 1, 30);
				border=ceil(input(compress(scan(decision, 1 ," "),"><="), 8.));
				cluster=" ";
				bin=.;
				nlevels=.;
				branch="hps";
				keep variable class d_var border cluster bin nlevels branch;
			run;
			proc sort data=work.hp_tree nodupkey;
				by border;
			run;

			data work.hp_tree;
				set work.hp_tree end=eof;
				if eof then nlevels=_N_+1;
			run;

			proc sql;
				delete from &outdn
				where variable="&var" and branch="hps";
			quit;

			proc append base=work.bv_tree data=work.hp_tree force;
			run;
		%end;
	%end;

	%if %superq(nominal)^= %then %do;
		%let nvars=%sysfunc(countw(&nominal));
		%do i=1 %to &nvars;
			%let var=%scan(&nominal, &i, %str( ));
			ods exclude PerformanceInfo DataAccessInfo;
			proc hpsplit data=&dn(keep=&target &var) leafsize=&leafsize;
				input &var/level=nom;
				target &target/level=&t_class;
				output  nodestats=work.hp_tree;
			run;

			data work.hp_tree;
				length variable d_var $32  cluster $1000 class branch $8;
				set work.hp_tree ;
				where leaf not is missing;
				variable="&var";
				class="nominal";
				d_var="c_"||substr(variable, 1, 30);
				border=.;
				cluster=tranwrd(decision, "or Missing", " ");
				cluster='"'||strip(tranwrd(cluster, ',', '" "'))||'"';
				bin=.;
				nlevels=.;
				branch="hps";
				keep variable class d_var border cluster bin nlevels branch;
			run;
			proc sort data=work.hp_tree nodupkey;
				by cluster;
			run;

			data work.hp_tree;
				set work.hp_tree end=eof;
				bin=_N_;
				if eof then nlevels=_N_;
			run;

			proc sql;
				delete from &outdn
				where variable="&var" and branch="hps";
			quit;

			proc append base=work.bv_tree data=work.hp_tree force;
			run;
		%end;
	%end;
%mend BinHPSplit;


