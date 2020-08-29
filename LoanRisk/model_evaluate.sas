/*== Discretize the numeric variables and collaspsing the levels of the char variables ==*/	
data _null_;
	set train1 nobs=obs;
	leafsize=ceil(obs*0.05);
	call symputx("leafsize", leafsize);
	put leafsize=;
	stop;
run;
/*Call macro BinVars to bin the variables by proc split. 
*  This is an interactive process to call BinVars repeatedly if necessary. */
%BinVars(train1, leafsize=&leafsize,  type=num)

%BinVars(train1, leafsize=&leafsize, type=nom)
%BinVars(train1, leafsize=2500, varlist= addr_state, type=nom)

proc print data=vars(where=(exclude is missing and class="nominal"));
run;
/*Call macro BinOpt to bin the numeric variables that couldn't be binned by macro BinVars*/
proc sql;
	select variable
	into :binlist separated by " "
	from vars
	where exclude is missing and nlevels>10 and class in ("interval" "ordinal") and variable not in (
			select variable from bin_interval);
quit;

%BinOpt(train1, varlist=&binlist)

/*Modify the border of bin result of the numeric variables manually.
*  For example, change the age border from 20.5 to 20 or balance border 
*  from 1001 to 1000 which would make the result more clear business sense.
*  If the modification made, call macro BinUpdate(dataset_name,type=border) 
*  to update the dataset.*/
%ToExcel(bin_interval)
x "&pout.bin_interval.xlsx";
%ToExcel(bin_optim)
x "&pout.bin_optim.xlsx";

/*Create discretized code datasets and code files, and update vars dataset*/
%BinMap(bin_interval,type=num)
%BinMap(bin_nominal,type=nom)
%BinMap(bin_optim, type=opt)
/*Create the train dataset for logistic regression modeling.*/
data train_log_iv;
	set train1;
	%include "&pout.bin_code_num.txt";
	%include "&pout.bin_code_opt.txt";
	%include "&pout.bin_code_nom.txt";
run;
/*== modify the bin manually and repeat if necessary.  ==*/
/*Calculate the woe, create woe_iv and iv dataset*/
%WoeIv(train_log_iv) 
/*if the manual adjustment of the bin is required, output the woe data to a xlxs file.
* Since the update code using select (), when modify the bin the newbin should be include
* the whole bin set of the variable*/
%ToExcel(woe_iv)
x "&pout.woe_iv.xlsx";
/*output BinUpdate dataset and the BinUpdate.txt*/
%BinUpdate(woe_iv) 

data train_log_iv;
	set train_log_iv;
	%include "&pout.BinUpdate.txt";
run;
/*=====================================*/
/*Re-calculate the woe, create woe_iv and iv dataset*/
%WoeIv(train_log_iv) 

proc sql noprint;
	select quote(trim(variable)) into :plotlist separated by " "
	from vars
	where exclude ^=1 and class in ("interval","ordinal");
quit;
/*monotonicity checking*/
%plot(woe_iv, variable, bin, woe, &plotlist)

/*create woe_code.txt, apply woe, create w_ variables*/
%WoeMap(train_log_iv)
data train_log_iv2;
	set train_log_iv;
	%include "&pout.woe_code.txt";
run;

/* == variable cluster and select the variable candidate ==*/
/*create varclusters dataset*/
%vclus(train_log_iv2) 
proc sql;
	create table varselect as
	select a.*, c.iv, c.binlevel, c.ks
	from (select * from varclusters) as a left join (select variable, ori_woe from vars) as b
	on a.variable=b.variable left join 
		(select * from iv) as c 
		on b.ori_woe=c.variable;
quit;
proc sort data=varselect;
	by clus_n descending iv descending rsquareratio binlevel;
run;
data _null_;
	set varselect end=eof;
	by clus_n;
	length selection $1000;
	retain selection;
	if first.clus_n then selection=catx(" ", selection, variable);
	if eof then call symputx("iv_select", selection);
run;
proc sort data=varselect;
	by clus_n descending rsquareratio descending iv;
run;
data _null_;
	set varselect end=eof;
	by clus_n;
	length selection $1000;
	retain selection;
	if first.clus_n then selection=catx(" ", selection, variable);
	if eof then call symputx("rs_select", selection);
run;
/*check if any value in valid, but not in train. if there is a such value, modify the bin_*.txt file
proc sql noprint;
	create table work.tmp as
	select distinct variable 
	from (select distinct variable from bin_nominal) union
			(select distinct variable from BinUpdate where substr(variable, 1, 2) not in ("b_", "c_"));
	select variable into :f_list separated by " "
	from work.tmp;
quit;
ods output OneWayFreqs=work._freq;
proc freq data=valid; 
	table &f_list  /missing nocum ;
run;
ods output close;
%CombFreq(work._freq, work._freq2)
title "The following variables, if any,  has value that exist in validation dataset only";
proc sql;
	select * 
	from (select variable, value from work._freq2) except (select variable, value from freq);
quit;
title;*/

/*Create valid dataset for logistic modeling*/
filename code "&pout.BinUpdate.txt";
data _null_;
	set BinUpdate;
	rc=fdelete("code");
	file code lrecl=32767;
	put code;
run;

data valid_log_iv;
	set valid;
	%include "&pout.mapcode.txt";
	%include "&pout.recode.txt";
run;
data valid_log_iv;
	set valid_log_iv;
	%include "&pout.bin_code_num.txt";
	%include "&pout.bin_code_nom.txt";
	%include "&pout.bin_code_opt.txt";
run;
%WoeMap(valid_log_iv)
data valid_log_iv;
	set valid_log_iv;
	%include "&pout.BinUpdate.txt";
	%include "&pout.woe_code.txt";
run;




/*Multicollinearity verification by Variance Inflation Factor(vif<5)*/
proc reg data=train1 ;
	model fault=&iv_select / vif;
	model fault=&rs_select / vif;
run;quit;
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


