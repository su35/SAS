/* *******************************************************************************
** macro ReCode: translate the char value to num value.
** dn: the dataset name. it can be a variable define dataset or a data dataset
** outfile: name of re-code map dataset and re-cord txt file
** dtype: if the dn is the variable define dataset that include the value mapping 
**   information, the dtype set to 1. This is the default.  
**   If the dn is data dataset the dtype shoud be declare as 0 clearly.
** id: the id variable, when the dataset is a data dataset.
** *******************************************************************************/
%macro ReCode(dn, outfile=reCode, path=, dtype=1, id= );
    %if %superq(dn)=  %then %do;
            %put ERROR: ======== the dataset is missing========== ;
            %return;
        %end;
    %if %superq(path)=  %then %let path=&pout;

    %if &dtype=1 %then %defi_code();
    %else %if &dtype=0 %then %radn_code();
    proc datasets lib=work noprint;
       delete rc: ;
    run;
    quit;

    %put  NOTE:  ==The dataset &outfile and &outfile..txt under &path were created.==;
    %put  NOTE:  ==The macro ReCode executed completed. ==;
%mend ReCode;

%macro defi_code();
    %local dnum i  multdn codelen;

    proc sort data=&dn;
        by vid value_n;
    run;

    proc sql noprint;
        select count(distinct variable)*70 as codelen
        into :codelen
        from &dn;
    quit;

    /*create the mapping code*/
    data &dn;
        set &dn end=eof;
        where not missing(value_n);
        by  vid;
        length code d r $&codelen ;
        retain newv d r;

        if _N_=1 then do;
            d= "drop ";
            r="rename ";
        end;

        if lengthn(variable)>30 then mapvar=substr(variable, 1, 30)||"_n";
        else mapvar=trim(variable)||"_n";

        if first.vid then do;
            code=cats("select (", variable, "); when ('", value,"') ", mapvar, "=", value_n, ";");
            d=catx(" ", d, variable);
            r=catx(" ", r, trim(variable)||"_n="||trim(variable));
        end;
        else if last.vid=0 then do;
            code=cats(" when ('", value, "') ", mapvar, "=", value_n,";");
        end;
        else do; 
            code=cats(" when ('",value, "') ",mapvar,"=",value_n,"; otherwise ",mapvar,"=. ; end;");
        end;
        output;
        if eof then do;
            code=trim(d)||";";
            output;
            code=trim(r)||";";
            output;
        end;
        keep vid variable value value_n code;
    run;

    filename code "&path.&outfile..txt"%str(;);
    data _null_;
        set &dn;
        rc=fdelete("code");
        file code lrecl=32767;
        put code;
    run;
%mend;

%macro radn_code();
    %let setname=%sysfunc(splitdn(&dn, set));
    ods exclude all;
    ods output OneWayFreqs=work.rcfreq;
    proc freq data=&dn %if %superq(id)^= %then(drop=id); nlevels;
        table _char_/missing nocum;
    run;
    ods output close;
    proc sort data=work.rcfreq;
        by table;
    run;

    %local tnum tnum2;
    proc sql noprint;
        select count(distinct table)*35 as tnum, 2*(calculated tnum) as tnum2  
        into :tnum, :tnum2
        from work.rcfreq;
    quit;

    data work.&setname._&outfile(rename=(table=variable));
        length dataset $32;
        set work.rcfreq end=eof;
        by table;
        length d droplist $&tnum r $&tnum2;
        retain d r;
        dataset="&dn";
        table=substr(table, 7);
        value=cats(of F_:);
        if _N_=1 then do;
            d= "drop ";
            r="rename ";
        end;
        if first.table then do;
            n=1;
            code=cats(table, "_n=", n, "*(", table,'="', value, '")+');
            d=catx(" ", d, table);
            r=catx(" ", r, trim(table)||"_n="||trim(table));
        end;
        else if last.table then code=cats(n, "*(", table, '="', value, '");');
        else code=cats(n, "*(", table, '="', value, '")+');
        value_n=n;
        n+1;
        if eof then do;
            droplist=trim(d)||";";
            renamelist=trim(r)||";";
        end;
        keep dataset table value value_n code droplist renamelist;
    run;
    filename code "&path.&setname._&outfile..txt";
    data _null_;
        set work.&setname._&outfile end=eof;
        rc=fdelete("code");
        file code lrecl=32767;
        put code;
        if eof then put #2 droplist  #3 renamelist; 
    run;
%mend;
