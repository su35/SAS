/* ******************************************************************************
*  extract the frequency and the percent of variables from OneWayFreqs
*  that created by proc freq.
* ******************************************************************************/
%macro CombFreq(dn, outdn);
    %if %superq(dn)=  %then %do;
            %put ERROR: == The dataset which hold the freq output is required;
            %return;
        %end;
    %if %superq(outdn)= %then %let outdn=&dn;
    %local vlen lib point dn_t;
    %let lib=%sysfunc(splitdn(&dn, lib));
    %let dn_t=%sysfunc(splitdn(&dn, set));
    %if %superq(lib) =  %then %let lib=%getLib;

    proc sql noprint;
        select max(length) into :vlen
        from dictionary.columns 
        where libname=upcase("&lib") and memname=upcase("&dn_t")
                and name like "F_%";
    quit;

    data &outdn;
        length variable $32  %if %superq(vlen) ne %then value $&vlen; ;
        set &dn;
        variable=substr(table, 7);
        value=strip(cats(of F_:));
        if missing(value) or value="." then missing=1;
        else missing=0;
        keep variable missing value frequency percent;
    run;
%mend CombFreq; 
