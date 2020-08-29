proc sql noprint;
    select off, rho1, pi2 
    into :off, :rho1,:pi2 from loan_popu;

    alter table trainApp_woe add off num;
    update trainApp_woe set off=&off;
quit;
/* cost matrix information in order of 00 01 11 10*/
%let matrix = 0 1 5 0;

/*======= RandomForest modeling =============*/
proc sql;
    select variable
    into :vlist separated by " "
    from vars
    where exclude is missing and derive_var is missing;
quit;
%put &vlist;

/*modeling by random forest approach*/
%RFTrain(trainApp_woe, vlist=&vlist)
/*validation, and output a roc-like dataset for model evaluation*/
%RFValid(validApp1)
/*model evalute, confusion matrix approach*/
%ModelEval(RFScore,  pi2=&pi2, rho1=&rho1, matr=&matrix)

/*======== logistic modeling =======*/
/*create model candidate*/
data _null_;
    set varselect_woe end=eof;
    by clus_n;
    where psi<0.1;
    length selection $1000;
    retain selection;
    if first.clus_n then selection=catx(" ", selection, variable);
    if eof then put selection;
run;
proc sql;
    select * from varselect_woe;
    select variable into :selection separated by " "
    from varselect_woe
    where iv>=0.02 and psi<0.1
    group by clus_n
    having iv=max(iv);
quit;

%put &selection;
%let selection=w_b_num_rev_tl_bal_gt_0 w_b_percent_bc_gt_75 w_b_avg_cur_bal 
w_b_sub_grade w_b_acc_open_past_24mths w_b_loan_amnt 
w_b_bc_open_to_buy w_b_mo_sin_old_rev_tl_op w_b_dti w_b_inq_last_6mths 
w_b_fico_range_high w_c_purpose w_b_inc_loan 
w_c_verification_status w_b_annual_inc w_b_mo_sin_rcnt_tl w_term;

/*Multicollinearity verification by Variance Inflation Factor(vif<5)*/
proc reg data=trainApp_woe ;
    model loan_status=&selection / vif;
run;quit;

/*create the model candidates*/
%strtran(selection)
data varselect_woe;
    set varselect_woe;
    call missing(iv_woe_r1);
    if variable in (&selection) then iv_woe_r1=1;
run;

%strtran(selection)
ods output bestsubsets=models nobs = work._nobs;
ods exclude bestsubsets ModelInfo NObs ResponseProfile;
proc logistic data=trainApp_woe des  namelen=32; 
    model loan_status =&selection / selection=score start=4  best=5; 
run;
ods output close;

%LogModSelect(trainApp_woe,validApp_woe,models,loan_status,popu=loan_popu, matr=&matrix)

data _null_;
    set work._nobs;
    If label="Number of Observations Used" then call symputx("nobs", nobsused);
run;
/*Caluclate the ScoreP base on scorechisq*/
%ScoreP(models, &nobs)

proc sort data=models;
    by numberofvariables variablesinmodel;
run;
proc sort data=mod_result;
    by numberofvariables variablesinmodel;
run;

data mod_result;
    merge mod_result models;
    by numberofvariables variablesinmodel;
run;
proc sort data=mod_result;
    by index;
run;

title "AUC: the large, the bette. Normally, AUC>0.7";
proc sgplot data=mod_result;
    xaxis grid values=(0 to 48 by 1);
    yaxis grid;
    scatter y=auc x=index /group=dataset;
    series y=auc x=index /group=dataset smoothconnect ;
run;
title "BIC: the small, the better";
proc sgplot data=mod_result;
    xaxis grid values=(0 to 48 by 1);
    yaxis grid;
    scatter y=bic x=index /group=dataset;
    series y=bic x=index /group=dataset smoothconnect ;
run;
title "COST: the small, the better";
proc sgplot data=mod_result;
    xaxis grid values=(0 to 48 by 1);
    yaxis grid;
    scatter y=avg_cost x=index /group=dataset;
    series y=avg_cost x=index /group=dataset smoothconnect ;
run;
title "KS: the large, the better. Normally, KS>0.2";
proc sgplot data=mod_result;
    xaxis grid values=(0 to 48 by 1);
    yaxis grid;
    scatter y=ks x=index /group=dataset;
    series y=ks x=index /group=dataset smoothconnect ;
run;
title "ScoreP: the small, the better";
proc sgplot data=mod_result;
    xaxis grid values=(0 to 48 by 1);
    yaxis grid;
    scatter y=scorep x=index /group=dataset;
    series y=scorep x=index /group=dataset smoothconnect ;
run;
title;
/*select the model that index is 21, then obs=21*2+1*/
data _null_;
    set mod_result  (firstobs=43 obs=43) ;
    call symputx("inmodel", variablesinmodel);
run;
/*modeling*/
ods listing close;
proc logistic data = trainApp_woe des namelen=32 outest=model_parm 
            plots(maxpoints=none); 
    model loan_status =&inmodel / outroc=roc_t; 
    output out=pred_probs p=pred_status lower=pl upper=pu;
    score data=validApp_woe out=scored outroc=roc_v  ;
run;

/* ***** model evaluate   ********/
/*compare the confusion matrix of train dataset and valid dataset */
%CMCompare(pred_probs, pred_status, scored, loan_status)

/*rename the variables to fit the macro ModelEval*/
data roc_v;
    set roc_v;
    rename _prob_=prob
            _sensit_=sensit
            _1mspec_=fpr;
run;
%ModelEval(roc_v, pi2=&pi2, rho1=&rho1, matr=&matrix)

/* ===== create scorecard ====*/
proc sql noprint;
    select int((1-cutoff)/cutoff)
    into :baseodds
    from roc_v_eval
    having  cost=min(cost);
quit;
/*generate scorecard dataset*/
%ScordCard(model_parm, 600, &BaseOdds, 20, scard)
/*output scorecard SAS code (txt). if need the SQL code, call macro SCSqlCode */
%SCTxtCode(scard,600, &BaseOdds, 20, ScoreCard, 1)

/*stability check*/
proc sql noprint;
    select distinct b_var, ori_var
    into :bvar separated by " ", :ovar separated by " "
    from scard;
quit;

data stabbase;
    set trainApp_woe;
    %include "&pout.ScoreCard.txt";
    keep &ovar &bvar points;
run;

data stabcheck;
    set accepted_n;
    where '01JAN2016'd<= issue_d and issue_d<'01JUL2016'd;
    %include "&pout.misscode.txt";
    %include "&pout.mapcode.txt";
    %include "&pout.bin_code.txt";
    %include "&pout.ScoreCard.txt";
    keep &ovar &bvar points issue_d;
run;

proc means data=stabbase  p25 p50 p75;
    var points;
    output out=_pmeans(drop=_type_ _freq_) p25=p25 p50=p50 p75=p75; 
run;

proc transpose data=_pmeans name=bin out=bin_point ;
run;

data bin_point_code;
    set bin_point end=eof;
    length code $100;
    if _N_=1 then code="select;when (points<="||trim(left(col1))||") bin_point="||left(_N_)||";";
    else code="when (points<="||trim(left(col1))||") bin_point="||left(_N_)||";";
    output;
    if eof then do;
        code="when (points>"||trim(left(col1))||") bin_point="||left(_N_+1)||";"; 
        output;
        code="otherwise bin_point=.; end;";
        output;
    end;
run;
filename code "&pout.bin_point_code.txt";
data _null_;
    set bin_point_code;
    rc=fdelete("code");
    file code lrecl=32767;
    put code;
run;

data stabbase;
    set stabbase;
    %include "&pout.bin_point_code.txt";
run;
data stabcheck;
    set stabcheck;
    %include "&pout.bin_point_code.txt";
run;
/*calculate the variable PSI*/
%PSI(stabbase, stabcheck, &bvar bin_point, tvar=issue_d, mvar=bin_point, outdn=StabPSI)

