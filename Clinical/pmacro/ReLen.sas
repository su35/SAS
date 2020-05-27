*----------------------------------------------------------------*;
* macro ReLen.sas
* detect the max length required for a char variable, 
* and then reduce the variable length as the real requirement
*
* MACRO PARAMETERS:
* standard = SDTM or ADaM. 
*----------------------------------------------------------------*;
%macro ReLen(standard, lib=, dn=)/minoperator ;
    %local i num;
    %if %superq(lib)= %then %let lib=&pname;
    %if %superq(dn) ^= %then %StrTran(dn);
    %if %superq(standard) ^= %then %do;
        %if %sysfunc(libref(&standard.file)) ne 0 %then  
            libname &standard.file "&pdir.&standard._METADATA.xlsx";;

        proc sort data = &standard.file."VARIABLE_METADATA$"n ( rename=(domain=dn)) 
                    out= work._resize(keep= dn variable length);
            where upcase(type) in ("TEXT", "DATE", "DATETIME", "TIME", "CHAR")
            %if %superq(dn) ^= %then and dn in (&dn) ; ;
            by dn variable;
        run;
    %end;
    %else %do;
        proc sql;
            create table work._resize as
            select memname as dn, name as variable, length
            from dictionary.columns
            where libname="%upcase(&lib)" and type="char"
            %if %superq(dn) ^= %then and memname in (%upcase(&dn)) ;
            ;
        quit;
        proc sort data=work._resize;
            by dn variable;
        run;
    %end;

    data  work._resize(keep= dn variable length rel_length);
        set  work._resize end=eof;
        by dn variable;
        length modifylist $ 32767;
        retain modifylist n ;
        n=0;
        rel_length = var_length("&lib", dn, variable) ;
        if first.dn then modifylist="";
        if rel_length +3< length then do;  
            modifylist = catx(",", modifylist, trim(variable)||" char("||cats(rel_length)||")") ;
            output;
        end;
        if last.dn and modifylist ne "" then do;
            n=sum(n,1);
            call symputx("modifylist"||left(n), modifylist);
            call symputx("dn"||left(n), dn);
        end;
        if eof and n>0 then call symputx("num", n);
    run;
    
    %if %superq(num)= %then %do;
        %put NOTE:  ==No re-length required.==;
        %return;
    %end;
    %else %do;
        %do i=1 %to &num;
            proc sql;
                alter table &lib..&&dn&i
                    modify &&modifylist&i;
            quit;

            %RemoveAttr(lib=&lib, setlist=&&dn&i)
        %end;

        %if %superq(standard) ^= %then %do;
            proc sql;
                create table work._out as
                select a.domain, a.varnum, a.variable, a.type, 
                    case when b.rel_length then b.rel_length else a.length end as length, a.label, a.keysequence, 
                    a.significantdigits, a.origin, a.commentoid, a.displayformat, 
                    a.computationmethodoid, a.codelistname, a.mandatory, a.role, a.sasfieldname, 
                    a.orivariable, a.setformat
                from sdtmfile."VARIABLE_METADATA$"n as a left join
                (select dn, variable, rel_length from work._resize) as b
                on a.domain=b.dn and a.variable=b.variable
                order by domain, varnum;
            quit;

            libname &standard.file clear;

            proc export data=work._out(where=(domain is not missing))
                            file="&pdir.&standard._METADATA.xlsx" dbms=xlsx replace;
                sheet="VARIABLE_METADATA";
            run;
        %end;

        title "The length of the variables had been modified "; 
        proc print data= work._resize noobs;
        run;
        title ;
    %end;
%mend ReLen;
