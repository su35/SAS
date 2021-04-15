/* Macro %readsas(): copy sas dataset.
*   Params:
*   filename: The source file that could include the path. 
*                  since the extention name is used to determin the dbms, the ext name should be include.
*                  
*   lib: the libref that the input dataset would reside in.
*   Except ' \ / : * ？ " < > | ', other charactors that illegal for SAS are legal for PC file name.  */

%macro readsas(filename, lib)/minoperator;
    %local setname path;
    /*detect if the filename include the path and extention name. if it include the path, 
    extract the setname. else, add project data path to filename. if the extention is included,
    remove the extname.*/
    %let filename=%nrbquote(%sysfunc(dequote(%nrbquote(&filename))));
    %if %index(&filename,\) %then %do;
        %let setname=%scan(%extract(&filename, R, \), 1, .);
        %let path=%extract(&filename, L, \);
    %end;
    %else %do;
        %let setname=%scan(&filename, 1, .);
        %let path=&pdir.data;
    %end;
    %if %superq(lib)= %then %let lib=orilib;

    libname templb "&path";
    /*instead of using proc copy, using data step input data to avoid the encoding problem*/
    data &lib..&setname;
        set templb.&setname;
    run;
    libname templb clear;

%mend readsas;
