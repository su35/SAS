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
        %local i lib dset;
        %let lib=%sysfunc(splitdn(&setname,lib));
        %let dset=%sysfunc(splitdn(&setname,set));
        /*if setname is one-level data set name, then get the libref*/
        %if %superq(lib)= %then %let lib=%getLib();

        %parsevars(&setname, vars)
        %StrTran(vars); 

        proc sql noprint;
            select ifc(type = "char", name, ""), 
                      ifc(type = "num", name, "")
                into :charlist separated by ' ', :numlist separated by ' '
                from dictionary.columns
                where libname= %upcase("&lib") and 
                            memname = %upcase("&dset") and 
                            upcase(name) in (%upcase(&vars));
        quit;
    %end;

    %if %superq(charlist) ne %then %do;
        title "The value of the char type";
        ods output OneWayFreqs = work.LV_freq;
        proc freq data = &setname;
            %do i=1 %to %sysfunc(countw(&charlist));
                tables %scan(&charlist, &i, %str(" ")) / nocum nopercent;
            %end;
        run;
        %CombFreq(work.LV_freq)
    %end;
    %if %superq(numlist) ne %then %do;
        title "The statistic result of the numeric type";
        proc means data=&setname n nmiss min max;
            var &numlist;
        run;
    %end;
    title;
%mend LegVal;
