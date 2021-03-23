/* ***********************************************************************************************
     Name  : mdVarLen.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: reduce the length of the char type variables to real requirement.
*    --------------------------------------------------------------------------------------------*
     Program type : Subroutine
*    --------------------------------------------------------------------------------------------*
     Parameters : inlib          = The libref in which the length of the variables will be reduce,
                         dataset     = The dataset in which the length of the variables will be reduce.
                         modifyList = The SQL alter modify code.
                         compList   = The list of variables whose length will be reduced, 
                                              use to select the variables in proc compare
*   *********************************************************************************************/
%macro mdVarLen(inLib, dataset, modifyList, compList);
    /*remove the "'"*/
    %let modifylist=%sysfunc(compress(&modifylist,  %str(%')));

    /*create a copy for validation*/
    proc copy in=&inLib out=work memtype=data;
        select &dataset;
    run;

    /*modify the length*/
    proc sql;
        alter table &inLib..&dataset
        modify &modifyList;
    quit;

    /*Only the Value Comparison will be print when the values are different*/
    ods exclude CompareDatasets CompareSummary CompareVariables;
    proc compare base=&inLib..&dataset comp=work.&dataset
                out=work.rlv_comp outnoequal;
            var &compList;    
    run;

    /*if no error, then delete the copy*/
    %if %sysfunc(nobs(work.rlv_comp))=0 %then %do;
        proc datasets lib=work noprint;
           delete &dataset ;
        run;
        quit;
    %end;
    %else %do;
        %put ERROR: There is an issue when relength the variables in &dataset;
        %put ERROR- A copy of orignal &dataset keeped in work library.;
    %end;
%mend mdVarLen;
