/* ******************************************************************************************
* macro GetMatelen.sas: get the length of the variables and store the data in a Excel file
* parameters
*       lib: specify the libaray
*       dataset: the name of the original dataset
*       file: the name of the xml file
* ******************************************************************************************/
%macro GetMatelen(lib=,dataset=, file=);
    %if %superq(lib) = %then %do;
        %if %sysfunc(libref(&pname)) = 0 %then %let lib=&pname;
        %else %let lib=WORK;
    %end;
    %if %superq(dataset) ne %then  %StrTran(dataset);
    %if %superq(file)= %then %let file =&pout.&lib._matelen.xlsx;
    %local i  mnum;
    options nonotes;
    data work.gm_tmp;
        set sashelp.vcolumn (keep=libname memname name type length format);
        where libname="%upcase(&lib)" 
            %if %superq(dataset) ne %then and memname in (%upcase(&dataset)); ;
        drop libname;   
    run;

    proc sql noprint;
        select distinct memname into :gm_mem1- 
        from work.gm_tmp;
    quit;
    %let mnum=&sqlobs;

    %do i=1 %to &mnum;
        proc export data=work.gm_tmp(where=(memname="&&gm_mem&i")) 
                    outfile="&file" DBMS=xlsx replace;
            sheet="&&gm_mem&i";
        run;
    %end;
    proc datasets lib=work noprint;
       delete gm_: ;
    run;
    quit;

    options notes;
    %put NOTE: == The &file created. ==;
    %put NOTE: == Macro GetMatelen runing completed. ==;
%mend GetMatelen;
