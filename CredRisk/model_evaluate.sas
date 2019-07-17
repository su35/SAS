/*create model candidate*/
ods listing close;
ods output bestsubsets=models;
proc logistic data=train1 des  namelen=32; 
	model fault =&iv_select / selection=score start=4 stop=12 best=2; 
run;
ods output close;
ods listing;

/* cost matrix information in order of 00 01 11 10*/
%let matrix = 0 1 5 0;
%LogModSelect(train1,valid1,models,fault,matr=&matrix)
proc sgplot data=mod_result;
	xaxis values=(0 to 20 by 1);
	yaxis values=(0.71 to 0.83 by 0.01);
	series y=auc x=index /group=dataset smoothconnect ;
run;
proc sgplot data=mod_result;
	xaxis values=(0 to 20 by 1);
	yaxis ranges=(380-450 650-750);
	series y=bic x=index /group=dataset smoothconnect ;
run;
proc sgplot data=mod_result;
	xaxis values=(0 to 20 by 1);
	series y=avg_cost x=index /group=dataset smoothconnect ;
run;
proc sgplot data=mod_result;
	xaxis values=(0 to 20 by 1);
	series y=ks x=index /group=dataset smoothconnect ;
run;
data _null_;
	set models  (firstobs=6 obs=6) ;
	call symputx("inmodel", variablesinmodel);
run;
/*modeling*/
ods listing close;
proc logistic data = train1 des namelen=32 outest=model_parm; 
	model fault =&inmodel / outroc=roc_t; 
	output out=pred_probs p=pred_status lower=pl upper=pu;
	score data=valid1 out=scored outroc=roc_v  ;
run;

/* ***** model evaluate   ********/
/*compare the confusion matrix of train dataset and valid dataset */
%CMCompare(pred_probs, pred_status, scored, fault)

proc sql noprint;
	select sum(fault)/count(fault)
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
%ModelEval(roc_v, pi1=, rho1=&rho1, matr=&matrix);

/*create scorecard*/
proc sql noprint;
	select int((1-cutoff)/cutoff)
	into :baseodds
	from roc_v1
	having  cost=min(cost);
quit;
/*generate scorecard dataset*/
%ScordCard(model_parm, 600, &BaseOdds, 20, scard);
/*output scorecard code*/
%SCSasCode(scard,600, &BaseOdds, 20, ScoreCard, 1);


