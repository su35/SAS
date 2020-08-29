/****************************************************************************
macro getCdiscSetMeta
Create attributelist, keeplist and orderlist for each CDISC standard dataset 
and store those data in a dataset.
****************************************************************************/
%macro getCdiscSetMeta(standard, domains=)/minoperator;
    %if %superq(standard) = %then %do;
        %put ERROR: == The standard is not assigned ==;
        %return;
    %end;
    %if %upcase(&standard) ne SDTM and %upcase(&standard) ne ADAM %then %do;
        %put ERROR: == A wrong standard is assigned ==;
        %return;
    %end;

    %if %symglobl(&standard.file)=0 %then 
            %let &standard.file=&pdir.&standard._METADATA.xlsm;
    libname templib xlsx "&&&standard.file";

    /*get the attribute and keeplist*/
    proc sort   data=templib.VariableLevel 
            out=work.gcm_settemp(keep=domain varnum variable type length label);
        %if %superq(domains) ne %then %do;
            %strtran(domains)
            where upcase(domain) in (%upcase(&domains));
        %end;
        by domain varnum;    
    run;

    data work.gcm_seqtemp (index=(domain)) ;
        set templib.contents (keep=name domainkeys);
        %if %superq(domains) ne %then %do;
            %strtran(domains)
            where upcase(name) in (%upcase(&domains));
        %end;
        rename name=domain domainkeys=orderlist;
        label domainkeys="orderList";
    run;

    data &standard.meta work.gcm_settemp;
        set work.gcm_settemp;
        by domain;
        length labellist $ 8000  keepList lengthlist $3200 orderList $640 len $8;
        retain labellist keeplist lengthlist orderList ;
        keep domain labellist keeplist lengthlist orderList ;
        if first.domain then do;
            set work.gcm_seqtemp key=domain; /*get the orderlist*/
            call missing(labellist);
            call missing(keeplist);
            call missing(lengthlist);
        end;
        if upcase(type) in ("INTEGER", "FLOAT", "NUM") then do;
            if length>0 then len=cats(length);
            else len="1";
        end;
        else if upcase(type) in ("TEXT", "DATE", "DATETIME", "TIME", "CHAR") then do;
            if length>0 then len=cats("$",length);
            else len="$1";
        end;
        else do;
            put "ERR" "OR: it isn't a valid ODM type.  " type=;
            return;
        end;
        labellist=catx(" ", labellist, variable, "='"||trim(label)||"'");
        keeplist=catx(" ", keeplist, variable);
        lengthlist=catx(" ", lengthlist, variable, len);
        if substr(variable, length(variable)-2, 3)="SEQ" then 
                orderList=catx(" ", orderlist, variable); /*add the --SEQ variable*/
        if last.domain then output;
    run;

    %reLenVars(datasets=&standard.meta)

    /* make a proc format control dataset out of the SDTM or ADaM metadata;*/
    %if &standard = SDTM %then %do;
        options varlenchk=nowarn;
        data work.gcm_formatdata;
            length fmtname $ 32 start end $ 16 label $ 200 type $ 1;
            set templib.CODELISTS;
            keep fmtname start end label type;

            fmtname = compress(codelistname);
            label = left(codedvalue);
            if upcase(sourcetype) in ("NUMBER", "NUM", "N","INTEGER","FLOAT") then
                type = "N";
            else if upcase(sourcetype) in ("CHARACTER", "TEXT", "CHAR", "C") then
                type = "C";
            
            start = trim(scan(sourcevalue, 1,','));
            end = trim(scan(sourcevalue, -1,',')); 
        run;
        /* create a SAS format library to be used in SDTM or ADaM conversions;*/
        proc format
            library=&pname
            cntlin=work.gcm_formatdata
            fmtlib;
        run;
        options varlenchk=warn;
    %end;

    libname templib clear;

    proc datasets lib=work noprint;
        delete gcm_: ;
    run;
    quit;

    %put NOTE:  ==The macro getCSISCmeta executed completed.== ;
    %put NOTE:  ==The attribute and keeplist stored in dataset &standard.meta.==;
    %put NOTE:  ==The formats are stored in &pname.==;
%mend getCdiscSetMeta;
