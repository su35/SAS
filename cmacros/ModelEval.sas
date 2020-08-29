/******************************************************************************
* Macro ModelEval: evalute the model on roc datasets output by proc logistic 
*           or other roc-like dataset by Confusion Matrix approach
*       rocdn- dataset created by outroc option
*       rho1-proportions of target=1 in trainning dataset if oversampled or undersampled and 
*           priorevent= was not specified
*       pi2- proportions of target=1 in validation dataset
*       matr- profit or cost matrix
*       type- type of matrix, p=>profit c=>cost
* ****************************************************************************/
%macro ModelEval(rocdn,  rho1=, pi2=, matr=, type=c);
    %if %superq(rocdn)=  or (%superq(pi2)= and %superq(rho1)= )%then %do;
        %put ERROR: === Parameter Error ===;
        %return;
    %end;
    %local mn ksref costref obs plodn;
    %let mn=%scan(&rocdn, -1, _);

    data &rocdn._eval;
        set &rocdn;
        retain auc 0;
        %if %superq(rho1)^= %then cutoff=prob*&pi2*(1-&rho1)/(prob*&pi2*(1-&rho1)+
            (1-prob)*(1-&pi2)*&rho1);
        %else cutoff=prob;
        ;
        specif=1-fpr;
        tp=&pi2*sensit;
        fn=&pi2*(1-sensit);
        tn=(1-&pi2)*specif;
        fp=(1-&pi2)*fpr;
        depth=tp+fp;
        if 0<depth<1 then do;
            pospv=tp/depth;
            negpv=tn/(1-depth);
        end;
        else if depth=1 then do;
            pospv=tp;
            negpv=0;
        end;
        else do;
            pospv=0;
            negpv=tn;
        end;
        acc=tp+tn;
        lift=pospv/&pi2;
        ks=sensit-fpr;
        auc=auc + sum(sensit, lag(sensit))*abs(sum(fpr, -lag(fpr)))/2;

        %if %superq(matr)^= %then %do;
            %local m00 m01 m10 m11 parm;
            %let m00=%scan(&matr, 1, %str( ));
            %let m01=%scan(&matr, 2, %str( ));
            %let m10=%scan(&matr, 3, %str( ));
            %let m11=%scan(&matr, 4, %str( ));
            %if &type=c %then %let parm=cost;
            %else %if &type=p %then %let parm=profit;
            &parm=tn*&m00+fp*&m01+fn*&m10+tp*&m11;
        %end;
        keep cutoff tn fp fn tp sensit fpr specif depth pospv negpv acc lift ks auc
        %if %superq(matr)^= %then &parm ;%str(;)
    run;

    proc sql noprint;
        select cutoff 
        into :ksref
        from &rocdn._eval
        having  ks=max(ks);

        select max(cutoff), max(auc), max(ks) 
        into :max_cut, :auc, :ks
        from &rocdn._eval;

        %if %superq(matr)^= %then %do;
            select cutoff 
            into :&parm.ref
            from &rocdn._eval
            having  &parm=min(&parm);
        %end;
    quit;
    /*if there is too may obs, the java memery leak will issued when proc sgplot running.
    * it may need to create a subset*/
    data _null_;
        set &rocdn._eval nobs=obs;
        if obs>10000 then call symputx("obs", obs);
        stop;
    run;
    %if %superq(obs)= %then %let plodn=&rocdn._eval;
    %else %do;
        proc surveyselect data=&rocdn._eval out=work.me_tmp
                seed=1234 method=SRS SAMPSIZE=5000;
        run;
        %let plodn=work.me_tmp;
    %end;
    proc sgplot data=&plodn;
        title "ROC Curve for the validation Data Set";
        title2 "AUC=&auc";
        xaxis values=(0 to 1 by 0.1);
        series x=fpr  y=sensit /smoothconnect ;
        series x=fpr y=fpr;
    run;
    proc sgplot data=&plodn;
        title "Lift Chart for  the model &mn";
        xaxis values=(0 to 1 by 0.1);
        series x=depth y=lift /smoothconnect ;
    run;
    proc sgplot data=&plodn;
        title "Lorenz  Curve for the model &mn";
        xaxis values=(0 to 1 by 0.1);
        series x=depth y=tp /smoothconnect ;
    run;
    proc sgplot data=&plodn;
        title "KS Curve for the model &mn";
        title2 "KS=&ks";
        xaxis values=(0 to 1 by 0.1);
        yaxis values=(0 to 1 by 0.1)  label="Sensitivity";
        y2axis values=(0 to 1 by 0.1)  label="1-Specif";
        series x=depth y=sensit /smoothconnect ;
        series x=depth y=fpr/y2axis smoothconnect  ;
        series x=depth y=ks/smoothconnect  ;
    run;
    proc sgplot data=&plodn;
        title "Selected Statistics against Cutoff"; 
        xaxis values=(0 to &max_cut by 0.1);
        yaxis values=(0 to 1 by 0.1)  label="Sensitivity, Specif, depth, and PV+ ";
        series x=cutoff y=sensit /smoothconnect curvelabel="Sensitivity" lineattrs=(color=black);
        series x=cutoff y=specif/smoothconnect  curvelabel=" Specif" lineattrs=(color=blue);
        series x=cutoff y=depth/smoothconnect  curvelabel="Depth" curvelabelpos=start lineattrs=(color=green);
        series x=cutoff y=pospv/smoothconnect  curvelabel="PV+" lineattrs=(color="#8B008B") ;
        refline &ksref /axis= x  transparency=0.5  label="With Max KS cutoff = &ksref" 
                lineattrs=(color="#FF4500") labelpos=min labelloc=inside;
        %if  %superq(matr)^= %then %do;
            %local label;
            %if &type=c %then %let label=With Min Cost;
            %else %if &type=p %then %let label=With Max Profit;
            Y2AXIS label="&parm";
            series x=cutoff y=&parm /y2axis smoothconnect curvelabel="&parm" lineattrs=( color=red);
            refline &&&parm.ref /axis= x transparency=0.5 label="&label cutoff = &costref" 
                lineattrs=(color="#FF00FF");
        %end;
    run;
    title;
    proc datasets lib=work noprint;
       delete me_: ;
    run;
    quit;
    
    %put NOTE: == The macro ModelEval exacuted completed. ==; 
    %put NOTE: == The result stored in &rocdn._eval. ==;
%mend ModelEval;
