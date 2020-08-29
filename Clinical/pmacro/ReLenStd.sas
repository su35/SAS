*----------------------------------------------------------------*;
* macro ReLenStd.sas
* detect the max length required for a char variable, 
* and then reduce the variable length as the real requirement
*
* MACRO PARAMETERS:
* standard: SDTM or ADaM. 
* lib: the libref. the default is project library.
* dn: the dataset list. the default is all dataset
* min: the minimum length. only the length larger than this value
*           would be relength
*----------------------------------------------------------------*;
%macro ReLenStd(standard, lib=, dn=, min=8)/minoperator ;
    %local i num;
    %if %superq(standard) = %then %do;
        %put ERROR: == The standard is not assigned ==;
        %return;
    %end;
    %if %upcase(&standard) ne SDTM and %upcase(&standard) ne ADAM %then %do;
        %put ERROR: == A wrong standard is assigned ==;
        %return;
    %end;
    %if %superq(lib)= %then %let lib=%getLib;
    %if %superq(dn) ne %then %StrTran(dn);

    libname templib xlsx "&pdir.&standard._METADATA.xlsm";

    proc sort data = templib.VariableLevel
                out= work.rlv_resize(keep= domain varnum variable length);
        where upcase(type) in ("TEXT",  "CHAR", "DATE")
/*        and upcase(variable) not in ("STUDYID", "DOMAIN", "USUBJID", "SUBJID")*/
       and upcase(codelistname) ne "YN"
            %if %superq(dn) ne %then and dn in (&dn) ;
            %if %superq(min) ne %then and length>&min;
            ;
        by domain varnum;
    run;

     /*get the real max length, and stored the values in macro variables*/
    data _null_;
        set work.rlv_resize end=eof;
        by domain varnum;
        length getlength mvarlist$ 32767;
        retain getlength mvarlist;

        if _N_=1 then call execute('proc sql noprint; ');
        if first.domain then do;
            call missing(getlength);
            call missing(mvarlist);
        end;
        getlength=catx(",", getlength, cats("max(lengthn(", variable, "))"));
        mvarlist=catx(",", mvarlist, cats(":",domain,variable,"len"));
        if last.domain then do;
            call execute("select "||trim(getlength)||' into '||trim(mvarlist)||'  from '
                        ||trim(domain)||";");
        end;
        if eof then call execute(' quit;');
    run;

    data work.rlv_resize;
        set work.rlv_resize;
        by domain varnum;
        length modifyList compList$32767;
        keep domain varnum variable length realLen;
        retain modifyList compList;
        realLen=input(symget(cats(domain,variable,"len")), 8.);
        if first.domain then do;
            call missing(modifylist);
            call missing(compList);
        end;
        if length>realLen then do;
            output;
            modifylist=catx(",", modifylist, catx(" ", variable, cats("char(", realLen, ")")));
            complist=catx(" ", complist, variable);
        end;
        if last.domain and not missing(modifylist) then do;
            modifylist=cats("'",modifylist,"'");
            modifylist=catx(", ", "&lib", domain, modifylist, complist);
            modifylist=cats('%mdVarLen(', modifylist, ')');
            rc=dosubl(modifylist);
        end;
    run;

    %if %sysfunc(nobs(work.rlv_resize))>0 %then %do;
        title "The length of the variables had been modified "; 
        proc print data= work.rlv_resize noobs;
        run;
        title ;

        /*update the excel file      */
        data templib.VariableLevel;
            if _N_=1 then do;
                declare hash resize(dataset: "work.rlv_resize(drop=length rename=(realLen=length))");
                resize.definekey("domain", "varnum");
                resize.definedata("length");
                resize.definedone();
            end;
            set templib.VariableLevel;
            rc=resize.find();
        run;
    %end;
    %else %put NOTE:  There is no variable need to relength.;

    libname templib clear;

    proc datasets lib=work noprint;
        delete rlv_: ;
    run;
    quit;
%mend ReLenStd;

%macro mdVarLen(inLib, domain, modifyList, compList);
        /*create a copy for validation*/
        proc copy in=&inLib out=work memtype=data;
            select &domain;
        run;

        %let modifylist=%sysfunc(compress(&modifylist, %str(%')));

        /*relength*/
        proc sql;
            alter table &inLib..&domain
            modify &modifyList;
        quit;

        /*Only the Value Comparison will be print when the values are different*/
        ods exclude CompareDatasets CompareSummary CompareVariables;
        proc compare base=&inLib..&domain comp=work.&domain
                    out=work.rlv_comp outnoequal;
                var &compList;    
        run;

        /*if no error, then delete the copy*/
        %if %sysfunc(nobs(work.rlv_comp))=0 %then %do;
            proc datasets lib=work noprint;
               delete &domain ;
            run;
            quit;
        %end;
        %else %do;
            %put REEOR: There is an issue when relength the variables in &domian;
            %put ERROR- A copy of orignal &domain keeped in work library.;
        %end;
%mend mdVarLen;
