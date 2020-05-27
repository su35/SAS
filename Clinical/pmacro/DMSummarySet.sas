/* *****************************************************************************************
* macro DMSummarySet: create DM report dataset for report.
* parameters
*   dn: the name of the dm dataset; character
*   varlist: the dm dataset variables list which planned to report; character
*           the variables order in the dm report follow the same order in this list. 
*           the group variable in report dataset could be used to change this order.
*   class: grouping variable including both character and numerice variables, 
            usually be arm/trtp armcd/trtpn; character
*    analylist: required statistic data specified for the numeric variables; character
* *****************************************************************************************/
%macro DMSummarySet(dn, varlist=, class=, analylist=) /minoperator;
    %local i group classc varnum stanum staname stalist nobs trtlevel;
    %if %superq(dn)= %then %let dn=addm; 
    %if %symglobl(blankno)=0 %then %let blankno=&#160%str(;) ;
    /*The variable name will be upcase when the variables are refered in statistic table */
    %let class=%upcase(&class);
    %let varlist=%upcase(&varlist);
    %let classc=%scan(&class, 1, %str( ));
    %let class  = %scan(&class, 2, %str( ));
    %let group = 1;
    ods select none;
    options nonotes;

    /*count the variable number and required statistic number*/
    %let varnum = %sysfunc(Countw(&varlist));
    %let stanum = %sysfunc(Countw(&analylist));
    %do i=1 %to &stanum;
        %let staname=%scan(&analylist, &i);
        %let stalist=&stalist &staname=&staname;
    %end;

    /*add total value, and delete dmreport dataset*/
    proc sql noprint;
        select  count(usubjid), put(count(distinct &class), 1.)
            into :nobs, :trtlevel
            from &dn;
        %if %sysfunc(exist(dmreport)) %then drop table dmreport; ;
    quit;

    data work.dms_&dn;
        set &dn;
        output;
        &class = &trtlevel;
        &classc="Total";
        output;  
    run;

    /*distribution check for numeric variables*/
    ods output TestsForNormality = work.dms_normality;
    proc univariate data=&dn normal;
    run;
    ods output close;

    %StrTran(varlist)
    data _null_;
        set work.dms_normality;
        where varname in (&varlist) and 
        /*select methord basing the obs number*/
        testlab =   %if %eval(&nobs < 2000) %then "W"; 
                %else "D";
                ;
        call symputx(trim(varname)||"pval", pvalue);
    run;

    %StrTran(varlist)
    /* create the dataset for dm report*/
    %do i=1 %to &varnum;
        %let variable = %scan(&varlist, &i, %str( ));
        %GetDMStatistic()
        proc append base=dmreport data=work.dms_&dn.temp;
        run; 
        %let group=%eval(&group+1);
    %end;

    proc datasets lib=work noprint;
    delete dms_: ;
    run;
    quit;

    options notes;
    ods select all;
    %put NOTE:  ==The dataset dmreport was created.==;
    %put NOTE:  ==The macro DMSummarySet executed completed.== ;
%mend DMSummarySet;

%macro GetDMStatistic();
    %local i method cellmin;
    %if %symexist(&variable.pval) %then %do; /*numeric variable*/
        /*get the pvalue for each term*/
        %if  %eval(&&&variable.pval>=0.05) %then %do; /*normal*/
            ods output equality=work.dms_ppvalue ttests=work.dms_pvalue;
            proc ttest data=&dn;
                class &class;
                var &variable;
            run;
            ods output close;

            /*identify the method*/
            data _null_;
                set work.dms_ppvalue;
                if probf < 0.05 then call symputx("method" , "SATTERTHWAITE");
                else call symputx("method" , "POOLED");
            run;
            /*get the pvalue, reuse the &variable.pval to hold the value*/
            data _null_;
                set work.dms_pvalue;
                where  upcase(method)=symget("method");
                call symputx("&variable"||"pval", probt);
            run;
        %end;
        %else %if  %eval(&&&variable.pval<0.05) %then %do; /*abnormal*/
            proc npar1way  data = &dn   wilcoxon   noprint;
                class &class;
                var &variable;
                output out = work.dms_pvalue wilcoxon;
            run;
            data _null_;
                set work.dms_pvalue;
                call symputx("&variable"||"pval", P2_wil);
            run;        
         %end;   

         /*get the statistic for each term*/
          proc sort data=work.dms_&dn; 
                by &class;
          run;

          proc univariate data=work.dms_&dn noprint; 
                by &class;
                var &variable;
                output out=work.dms_&dn.temp &stalist;
          run;

          proc transpose data=work.dms_&dn.temp name = term 
                            out=work.dms_&dn.temp(drop=_LABEL_) prefix=ori; 
                id &class;
          run;

        data work.dms_label;
            length term $ 50 pvalue $ 8;
            term = "&variable";
            pvalue =put (&&&variable.pval, d5.3-R);
        run;

        data work.dms_&dn.temp;
            length  group 3 term $ 50 &class.0-&class.&trtlevel $20 ;
            /*The first obs read form dms_label*/
            set work.dms_label  work.dms_&dn.temp;
            array ori(*)  ori0-ori&trtlevel;
            array tar(*) $ &class.0-&class.&trtlevel;
            label pvalue= "P_value" term="Term";
            group =&group;
            if _n_ >1 then do; 
                if lowcase(term)="min" then term=cats("&blankno", "Minimum");
                else if lowcase(term)="max" then term=cats("&blankno", "Maximum");
                else term= cats("&blankno", propcase(term));
                do i=1 to dim(ori);
                    if find(ori0, ".") then tar[i]=put(ori[i], 8.1-L);
                    else tar[i]=put(ori[i], 8.-L);
                end;
            end;
            keep term group &class.0-&class.&trtlevel pvalue;
        run;
    %end;
    %else %do; /*char variable*/
        proc freq data=&dn noprint;
            where &class not is missing and &variable not is missing;
            table &variable*&class /chisq outpct out=work.dms_ptemp; /*Itls the option outpct，not the statement output*/
            output out= work.dms_pvalue pchi;
        run;
        proc sql noprint;
            select min(count) into : cellmin
                from work.dms_ptemp;
        quit;
        %if &cellmin < 5 %then %do;
        /*there are some counts less than 5, get fisher pvalue */
            proc freq data=&dn noprint;
                where &class not is missing and &variable not is missing;
                table &variable*&class /exact ;
                output out= work.dms_pvalue exact;
            run;
            data _null_;
                set work.dms_pvalue;
                call symputx("&variable"||"pval", xp2_fish);
            run;
            %end;
        %else %do;
            data _null_;
                set work.dms_pvalue;
                call symputx("&variable"||"pval", P_PCHI);
            run;
            %end;
    
        proc freq data=work.dms_&dn noprint;
            where &class not is missing;
            table &class*&variable / missing outpct out=work.dms_&dn.temp; 
        run;

        /* Save the names that would be generated by following proc transpose into the macro variables 
        for variable order controlling.*/
        data work.dms_&dn.temp;
            set work.dms_&dn.temp;
            by &class;
            where &variable ne "";
            length value $ 20; /*those values will store in trtpn0 - trtpnN*/
            if count=0 then value=0;
            else  value=cats(count)||' ('||trim(put(pct_row,5.1-L))||'%)';
        run;

        proc sort data=work.dms_&dn.temp; 
            by &variable;
        run;
        proc transpose data=work.dms_&dn.temp 
                            out=work.dms_&dn.temp(drop=_name_) prefix=&class;
            var value;
            by &variable;
            id &class;
        run;
        data work.dms_label;
            length term $ 50 pvalue $ 8;
            term = "&variable";
            pvalue =put(&&&variable.pval, d5.3-R);
        run;

        data work.dms_&dn.temp; 
            length  group 3  term $ 50 &class.0-&class.&trtlevel $ 20; /*define the variable order in the dataset*/
            set work.dms_label work.dms_&dn.temp;
            label pvalue= "P_value" term="Term";
            group =&group;
            keep term &class.0-&class.&trtlevel pvalue group;
            /*add the indentation for report*/
            if _n_ >1 then term = "&blankno"||&variable;
        run;
    %end;
%mend GetDMStatistic;
