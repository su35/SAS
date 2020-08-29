/* ***********************************************************************
* tdn: train dataset
* vdn: valid dataset
* mdn: dataset contain info. of models
* target: the target variable
* outdn: the output dataset which contain the results
* popul: the data set that contain the population data of train and valid dataset
* matr: the matix of cost or profit
* d: matrix type c=>cost, p=>profit
* ***********************************************************************/
%macro LogModSelect(tdn, vdn, mdn, target, outdn=mod_result, popu=, matr=, d=c);
	%local i models w0 w1 m11 m10 m01 m00 list_len d vlist vnum models;
	options nonotes noquotelenmax;

	proc sql noprint;
		select variablesinmodel, NumberOfVariables,lengthc(variablesinmodel)
		into :ms_vlist1 - :ms_vlist999, :ms_vnum1 - :ms_vnum999 , :list_len
		from &mdn;
		%let models = &sqlobs;

		%if %sysfunc(exist(&outdn)) %then drop table &outdn%str(;);
	quit;
	%if %superq(popu)^= %then %do;
		%local pi1 pi2 rho1;
		proc sql noprint;
			select pi1, pi2, rho1 into :pi1, :pi2, :rho1 
			from &popu;
		quit;
		%let w1=%sysevalf(&pi1/&rho1);
		%let w0=%sysevalf((1-&pi1)/(1-&rho1));
	%end;
	%else %do;
		%let w1=1;
		%let w0=1;
	%end;
	%if %superq(matr)^= %then %do;
		%let m00=%scan(&matr, 1, %str( ));
		%let m01=%scan(&matr, 2, %str( ));
		%let m10=%scan(&matr, 3, %str( ));
		%let m11=%scan(&matr, 4, %str( ));
		%if &d=c %then %let d=cost;
		%else %if &d=p %then %let d=profit;
	%end;

	options varlenchk=nowarn;
	ods select none;
	ods noresults;

	%do i=1 %to &models;
		%let vlist=&&ms_vlist&i;
		%let vnum=&&ms_vnum&i;
		ods output scorefitstat=work.lms_fit_score;
		proc logistic data=&tdn des;
			model &target=&vlist;
			score data=&tdn  out=work.lms_scoredtrain(keep=&target p_1 p_0)  fitstat	;
			score data=&vdn out=work.lms_scoredvalid(keep=&target p_1 p_0)  fitstat
			%if %symexist(pi2)^= %then priorevent=&pi2;
			;
		run;
		ods output close;

		proc npar1way edf wilcoxon data=work.lms_scoredtrain; 
			class &target;
			var p_1; 
			output out=work.lms_ks_t(keep= _D_  rename=( _D_=ks_t));
		run;
		proc npar1way edf wilcoxon data=work.lms_scoredvalid; 
			class &target;
			var p_1; 
			output out=work.lms_ks_v(keep= _D_  rename=( _D_=ks_v));
		run;
		data _null_;
			set work.lms_ks_t;
			set work.lms_ks_v;
			call symputx("ks_t", ks_t);
			call symputx("ks_v", ks_v);
		run;
		data work.lms_&outdn;
			index=&i;
			numberofvariables=&vnum;
			length variablesinmodel $&list_len dataset $8;
			variablesinmodel="&vlist";
			set	work.lms_fit_score;
			if _N_=1 then do;
				dataset="train";
				ks=&ks_t;
			end;
			else if _N_=2 then do;
				dataset="valid";
				ks=&ks_v;
			end;
			d_auc=(lag(auc)-auc)*100;
			label  ks="KS"  d_auc="AUC Shrinkage (%)";
			drop  freq loglike;
		run;

		/*since in scorefitstat the order is train first and then valid, we use the same order to
		assess the matris/ASE, then we not need to sort and merge*/
		%assess(train);
		%assess(valid);
		data work.lms_&outdn;
			set  work.lms_&outdn;
			set   work.lms_&outdn.2;
			%if %superq(matr)^= %then
			&d._shir=round((lag(avg_&d)-avg_&d)/avg_&d*100,0.01);
			;
		run;
		proc append base=&outdn data=work.lms_&outdn force;
		run;
		proc datasets library=work  nodetails nolist;
		    delete lms_:;
		run;quit;
	%end;
	ods results;
	ods select all;
	options varlenchk=warn quotelenmax notes;
	%put NOTE: == Dataset mod_result was created ==;
	%put NOTE: == Macro LogModSelect running completed ==;
%mend LogModSelect;
%macro assess(dn);
/* sort data set from likely to unlikely to respond */
	proc sort data=work.lms_scored&dn;
		by descending p_1;
	run;

/* create assessment data set */
	data work.lms_assess;
		/* 2 x 2 count array, or count matrix */
		array n[0:1,0:1] _temporary_ (0 0 0 0);
		/* sample weights array */
		array w[0:1] _temporary_ (&w0 &w1);


		set work.lms_scored&dn end=last nobs=obs;
		/* T is a flag for response */
		if vtype(&target)="C" then t=(strip(&target)="1");
		else t=(&target=1);

		%if  %superq(matr)^= %then %do;
			/* matrix associated with each decision */
			d1=&m11*p_1+&m01*p_0;
			d0=&m10*p_1+&m00*p_0;

			/* D is the decision, based on profit/cost. */
			d=(d1
			%if &d=p %then >;
			%else <;
			d0);
			n[t,d] + w[t];
		%end;
		/* update the count matrix, sse, and c */
		sse + (&target-p_1)**2;
		if last then do;
			%if  %superq(matr)^= %then %do;
				total_&d = sum(&m11*n[1,1],&m10*n[1,0],&m01*n[0,1],&m00*n[0,0]);
				avg_&d = total_&d/sum(n[0,0],n[1,0],n[0,1],n[1,1]);
			%end;
			ASE = sse/obs;
			output;
		end;
		keep %if %superq(matr)^= %then total_&d avg_&d;
				ase;
	run;

	proc append base=work.lms_&outdn.2 data=work.lms_assess force;
	run;
%mend assess;
