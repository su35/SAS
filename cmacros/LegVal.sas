/* ***************************************************** 
* macro LegVal: find the illegal valus
* parameters
* setname: the name of the dataset, libref could be included
* vars: the list of variable that would like to evalued
 ********************************************************/
%macro LegVal(setname, vars)/minoperator;
    %local charlist numlist;
    %if %length(%superq(vars)) =  %then %do;
        %let charlist=_CHAR_;
        %let numlist=_NUMERIC_;
    %end;
    %else %do;
        %local i lib dset ;
        %let lib=%sysfunc(splitdn(&setname,lib));
        %let dset=%sysfunc(splitdn(&setname,set));
        %parsevars(&setname, vars)
        %StrTran(vars); 
        proc sql noprint;
            select case when type = "char" then name else " " end, 
                case when type = "num" then name else " " end
                into :charlist separated by ' ', :numlist separated by ' '
                from dictionary.columns
                where libname= %upcase("&lib") and 
                            memname = %upcase("&dset") and 
                            upcase(name) in (%upcase(&vars));
        quit;
    %end;

    %if %superq(charlist) ne %then %do;
        proc freq data = &setname;
            tables &charlist / nocum nopercent;
        run;
    %end;
    %if %superq(numlist) ne %then %do;
        proc means data=&setname n nmiss min max;
            var &numlist;
        run;
    %end;
%mend LegVal;
