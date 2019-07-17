/*create model candidate*/
ods listing close;
ods output bestsubsets=models;
proc logistic data=train2 des  namelen=32; 
	model y =&iv_select / selection=score start=4 stop=12 best=2; 
run;
ods output close;

proc freq data=valid1 noprint;
	table y/out=work.tmp_vfreq;
run;
data _null_;
	set work.tmp_vfreq (where=(y=1));
	call symputx('pi', percent/100);
run;
%LogModSelect(train2,valid1,models,y, pi1=&pi)

proc sgplot data=mod_result;
	xaxis values=(0 to 20 by 1);
	yaxis values=(0.77 to 0.8 by 0.01);
	series y=auc x=index /group=dataset smoothconnect ;
run;
proc sgplot data=mod_result;
	xaxis values=(0 to 20 by 1);
	yaxis ranges=(4500-4800 14500-14800);
	series y=bic x=index /group=dataset smoothconnect ;
run;
proc sgplot data=mod_result;
	xaxis values=(0 to 20 by 1);
	yaxis ranges=(0.079-0.081 0.12-0.123);
	series y=ase x=index /group=dataset smoothconnect ;
run;
proc sgplot data=mod_result;
	xaxis values=(0 to 20 by 1);
	series y=ks x=index /group=dataset smoothconnect ;
run;
data _null_;
	set models  (firstobs=11 obs=11) ;
	call symputx("inmodel", variablesinmodel);
run;
/*modeling*/
proc logistic data = train2 des namelen=32 outest=model_parm; 
	model y =&inmodel / outroc=roc_t; 
	output out=pred_probs p=pred_status lower=pl upper=pu;
	score data=valid1 out=scored outroc=roc_v ;
run;

/* ***** model evaluate   ********/
/*compare the confusion matrix of train dataset and valid dataset */
%CMCompare(pred_probs, pred_status, scored, y)

proc sql noprint;
	select sum(y)/count(y)
	into :rho1
	from valid1;
quit;
/*rename the variables to fit the macro ModelEval*/
data roc_v;
	set roc_v;
	rename _prob_=prob
			_sensit_=sensit
			_1mspec_=fpr;
run;
%ModelEval(roc_v, pi1=, rho1=&rho1);

data customers;
	set scored;
	where p_1>=0.273549;
	keep id p_1;
run;

