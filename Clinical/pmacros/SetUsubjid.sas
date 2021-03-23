%macro SetUsubjid(lib=orilib, dataset=, length=, siteid=1);
    %local i count usubjid;

    %if &siteid =1 %then %let usubjid=%str(catx('.',studyid,siteid,subjid));
    %else %let usubjid=%str(catx('.',studyid,subjid));

    proc sql noprint;
    %if %superq(dataset)=  %then %do;
        select  memname
            into : su_dataset1- 
            from dictionary.tables
            where libname="%upcase(&lib)";

        %let count=&sqlobs;
        %do i=1 %to &count;
            alter table &lib..&&su_dataset&i
                add usubjid char &length format=$&length.. label="Unique Subject Identifier";
            update &lib..&&su_dataset&i
                set usubjid=&usubjid;
        %end;
    %end;
    %else %do;
        alter table &lib..&dataset
            add usubjid char (&length) format=$&length.. label="Unique Subject Identifier";
        update &lib..&dataset
                set usubjid=&usubjid;
    %end;
    quit; 
    
    %put NOTE: == The usubjid has been set. ==;
    %put NOTE: == Macro SetUsubjid runing completed. ==;
%mend SetUsubjid;
