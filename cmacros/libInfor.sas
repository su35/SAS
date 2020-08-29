/* *************************************************************************
* LibInfor
* report the metadata of variables in the given lib including dateset name, variable,
* type, length, and label
* *************************************************************************/
%macro LibInfor(lib, dataset);
    %local i setnum;
    %if %superq(lib)= %then %let lib=&pname;
    %if %superq(dataset) ne %then %let setnum=%sysfunc(countw(&dataset));
    proc format;
        value type 2="Char"
                    1 = "Num";
    run;

    proc datasets library=&lib  memtype=data noprint ;
        %if %superq(dataset) = %then contents data=_all_   out=work.temp%str(;) ;
        %else 
            %do i=1 %to &setnum;
                contents data=%scan(&dataset, &i, %str( )) out=work.temp&i;
            %end;
    run;
    quit;

    proc datasets library=work memtype=data noprint;
        %do i=1 %to &setnum;
            %if &i = 1 %then %do;
                %if %sysfunc(exist(work.temp)) %then age temp1 temp%str(;);
                %else change temp1=temp%str(;);
            %end;
            %else append base=temp data=temp&i%str(;);
        %end;
    run;
    quit;

    proc sql noprint;
        select path into: libpath
        from Dictionary.members
        where libname =upcase("&lib");          
    quit;

    %let libpath=%sysfunc(strip(&libpath));

    libname templb xlsx "&libpath\&lib.meta.xlsx";
    data templb.orimeta;
        keep  memname name type ntype length nobs;
        set work.temp(rename=(type=ntype)) ;
        rename memname=dataset name=variable;
        if ntype=2 then type="char";
        else type="num";
    run;
    libname templb clear;

    /*relength label to avoid the log error when run proc report*/
    proc sql;
        alter table work.temp
        modify label char(78);
    quit;

    title "Datasets in &lib";
    title2 "The content has been stored in &libpath\orimeta.xlsx";
    ods html5 path="&libpath" (url="")
    body="meta.html";
    proc report data=work.temp headline headskip spacing=2 ;
        columns memname name type length format informat label;
        define memname /order order=data "Dataset" ;
        define name /display  "Variable";
        define type /display  format=type. "Type";
        define length /display  "Length";
        define format /display "Format";
        define informat /display  "Informat";
        define label /display  "Label";
        compute after memname;
        line ' ';
        endcomp;
    run;
    ods html5 close;
    ods html;
    title ;
    title2;
%mend LibInfor;
