/* **********************************************************************************************************
     Name  : ReLenStd.sas
     Author : Jun Fang  Feb 2017
*    --------------------------------------------------------------------------------------------------------*
     Description : Detect the max length required for a char variable,   
                         and then reduce the variable-length as the real requirement.
     Purpose      : Before submitting, reduce the size of datasets. 
*    --------------------------------------------------------------------------------------------------------*
     Parameters : standard = The name of the standard, SDTM or ADaM. Required
                         lib           = The libref in which the datasets are stored . The default is project library.
                         datasets  = The list of the datasets in which the char variable length will be reduced. 
                                            The default is all dataset.
                         minlen    = The minimum length.  If it was assigned, only the length 
                                            larger than this value would be change. Optional
*   **********************************************************************************************************/
%macro ReLenStd(standard, lib, datasets, minlen)/minoperator des="";
    %local i num;

    /*assertions*/
    %if %superq(standard) = %then %do;
        %put ERROR: == The standard is not assigned ==;
        %return;
    %end;
    %if %upcase(&standard) ne SDTM and %upcase(&standard) ne ADAM %then %do;
        %put ERROR: == A wrong standard is assigned ==;
        %return;
    %end;
    /*default value assignments*/
    %if %superq(lib)= %then %let lib=%getLib;

    %if %superq(datasets) ne %then %StrTran(datasets);

    /*refer the metadata file as lib*/
    libname templib xlsx "&pdir.&standard._METADATA.xlsx";

    /*some char variables for which the length is known, such as USUBJID, would not be included.*/
    proc sort data = templib.VariableLevel
                out= work.rlv_resize(keep= domain varnum variable length);
        where upcase(type) in ("TEXT",  "CHAR", "DATE")
        and upcase(variable) not in ("STUDYID", "DOMAIN", "USUBJID", "SUBJID")
       and upcase(codelistname) ne "YN"
            %if %superq(datasets) ne %then and domain in (&datasets) ;
            %if %superq(minlen) ne %then and length>&minlen;
            ;
        by domain varnum;
    run;

     /*Get the real max length and stored the values in macro variables by call execute() routine*/
    data _null_;
        set work.rlv_resize end=eof;
        by domain varnum;
        length getlength mvarlist$ 32767;
        retain getlength mvarlist;

        if _N_=1 then call execute('proc sql noprint; ');

        /*Initialization for each domain*/
        if first.domain then do;
            call missing(getlength);
            call missing(mvarlist);
        end;
   
        /*Create the code*/
        getlength=catx(",", getlength, cats("max(lengthn(", variable, "))"));
        mvarlist=catx(",", mvarlist, cats(":",domain,variable,"len"));

         /*create a select statement for each domain*/
        if last.domain then do;
            call execute("select "||trim(getlength)||' into '||trim(mvarlist)||'  from '
                        ||trim(domain)||";");
        end;

        if eof then call execute(' quit;');
    run;

    /*Modify the variables length if necessary.*/
    data work.rlv_resize;
        set work.rlv_resize;
        by domain varnum;
        length modifyList compList $ 32767;
        keep domain varnum variable length realLen;
        retain modifyList compList;

        /*Get the real length from the macro variables created by the call execute()*/
        realLen=input(symget(cats(domain,variable,"len")), 8.);

        /*Initialization for each domain*/
        if first.domain then do;
            call missing(modifylist);
            call missing(compList);
        end;

         /*If the length needs to be reduced, output to rlv_resize and create the modify code*/
        if length>realLen then do;
            output;
            modifylist=catx(",", modifylist, catx(" ", variable, cats("char(", realLen, ")")));
            complist=catx(" ", complist, variable);
        end;

        /*if a domain needs to be modified, call %mdVarLen() by function dosubl() to modify*/
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

        /*update the metadata excel file      */
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

    /*clear the work area*/
    libname templib clear;

    proc datasets lib=work noprint;
        delete rlv_: ;
    run;
    quit;
%mend ReLenStd;
