/* ***********************************************************************************************
     Name  : DMReportSet.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: Create DM report dataset for report
*    --------------------------------------------------------------------------------------------*
     Parameters : indn   = One- or two-level data set name. 
                                            The default is ADSL.
                         varlist    = The dm dataset variables list which planned to report; 
                                            The variables order in the dm report follow the same order 
                                            in this list. the group variable in report dataset could be 
                                            used to change this order. 
                                            The default is age sex race
                         class      = Grouping variable including both character and numerice 
                                            variables, usually be trt01p/arm/trtp trt01pn/armcd/trtpn;
                                            The default is trt01p/trt01pn.
                         analylist = Required statistic data specified for the numeric variables;
                                            The default is n mean median min max.
                         outdn    = The out put DM report dataset.
                                            The default is dmreport
*   *********************************************************************************************/
%macro DMReportSet(indn, varlist, class, analylist, outdn) /minoperator;
    %local i group classc varnum stanum staname stalist nobs trtlevel maxlev tempset;
    
    /*set the default value if the paramter has not assigned*/
    %if %superq(indn)= %then %let indn=adsl; 
    %if %superq(varlist) = %then %let varlist=age sex race;
    %if %superq(class) = %then %let class=trt01p trt01pn;
    %if %superq(analylist) = %then %let analylist=n mean median min max;
    %if %superq(outdn) = %then %let outdn=dmreport;
    %if %symglobl(blankno)=0 %then %let blankno=&#160%str(;) ;

    /*The variable name will be upcase when the variables are refered in statistic table */
    %let varlist=%upcase(&varlist);
    %let class=%upcase(&class);

    /*split the class to char class and num class*/
    %let classn  = %scan(&class, 2, %str( ));
    %let class = %scan(&class, 1, %str( ));

    /*initialize the group*/
    %let group = 1;

    /*count the variable number and required statistic number*/
    %let varnum = %sysfunc(Countw(&varlist));
    %let stanum = %sysfunc(Countw(&analylist));

    /*create the statistic list for proc univariate*/
    %do i=1 %to &stanum;
        %let staname=%scan(&analylist, &i);
        %let stalist=&stalist &staname=&staname;
    %end;

    /*add total value, and delete dmreport dataset if it is exist*/
    proc sql noprint;
        select  count(usubjid), put(count(distinct &classn), 1.), max(classn)+1
            into :nobs, :trtlevel, :maxlev
            from &indn;
        %if %sysfunc(exist(dmreport)) %then drop table dmreport; ;
    quit;

    data work.dms_&indn;
        set &indn;
        output;
        &classn = &maxlev;
        &class = "Total";
        output;  
    run;

    /*distribution check for numeric variables*/
    ods select none; 
    ods output TestsForNormality = work.dms_normality;
    proc univariate data=&indn normal;
    run;
    ods output close;

    %StrTran(varlist)
    data _null_;
        set work.dms_normality;
        where varname in (&varlist) and 
        /*select method basing the obs number*/
        testlab =   %if %eval(&nobs < 2000) %then "W"; 
                %else "D";
                ;
        call symputx(trim(varname)||"nompval", pvalue);
    run;

    %StrTran(varlist)
    /* create the dataset for dm report*/
    %let tempdn=work.dms_&indn.temp;
    %do i=1 %to &varnum;
        %let variable = %scan(&varlist, &i, %str( ));
        /*get the statistic data for each variable*/
        %GetDMStatistic(&indn, &variable, class=&classn, outdn=&tempdn, group=&group
            %if %symexist(&variable.nompval) %then , pval=&&&variable.nompval
                                                                            , stalist=&stalist;
            )
        proc append base=&outdn data=&tempdn;
        run; 
        %let group=%eval(&group+1);
    %end;

    ods select default; 

    proc indn lib=work noprint;
    delete dms_: ;
    run;
    quit;

    %put NOTE:  ==The dataset &outdn was created.==;
    %put NOTE:  ==The macro DMReportSet executed completed.== ;
%mend DMReportSet;
