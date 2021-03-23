/* ***********************************************************************************************
     Name : getCdiscSetMeta.sas
     Author: Jun Fang  Feb, 2017
*    --------------------------------------------------------------------------------------------*
     Purpose: Create attributelist, keeplist and orderlist for each CDISC standard dataset 
                    and store those data in a dataset.
*    --------------------------------------------------------------------------------------------*
     Input    : required: standard
                   optional: domsins
     Output : 
*    --------------------------------------------------------------------------------------------*
     Parameters : standard = SDTM or ADaM
                         domains  = The list of domains whoes meta date will be extracted. 
                                            The defualt is all domains
*   *********************************************************************************************/
%macro getCdiscSetMeta(standard, domains)/minoperator
                des="Create format, attributelist, keeplist and orderlist for each CDISC standard dataset 
and store those data in a dataset.";
    %if %superq(standard) = %then %do;
        %put ERROR: == The standard is not assigned ==;
        %return;
    %end;
    %if %upcase(&standard) ne SDTM and %upcase(&standard) ne ADAM %then %do;
        %put ERROR: == A wrong standard is assigned ==;
        %return;
    %end;

    %local fmtlen labelen st2ndlen opts;
    %if %symglobl(&standard.file)=0 %then 
            %let &standard.file=&pdir.&standard._metadata.xlsx;
    libname templib xlsx "&&&standard.file";

    /*fetch domain domainkeys*/
    data work.gcm_seqtemp (index=(domain)) ;
        set templib.contents (keep=name label domainkeys);
        %if %superq(domains) ne %then %do;
            %strtran(domains)
            where upcase(name) in (%upcase(&domains));
        %end;
        rename name=domain domainkeys=orderlist label=setlabel;
        label domainkeys="orderList";
    run;

    /*get the attribute of the variables*/
    proc sort data=templib.VariableLevel 
            out=work.gcm_settemp(keep=domain varnum variable type length label);
        %if %superq(domains) ne %then %do;
            where upcase(domain) in (%upcase(&domains));
        %end;
        by domain varnum;    
    run;

    /*get the length of the list variables*/
    data _null_;
        dsid=open("work.gcm_settemp");
        if dsid then do;
            nobs=attrn(dsid, "nobs");
            vlen=varlen(dsid, varnum(dsid,"Label"));
        end;
        call symputx("len_keep", nobs*9 );/*variable length is 8, plus a blank*/
        call symputx("len_length", nobs*13);/*variable, a $, 3 blank, plus 2 digits*/
        call symputx("len_label", nobs*(12+vlen));/*variable, an equal mark, 2 quotation mark, and a blank */
        rc=close(dsid);
        stop;
    run;

    /*save the meta data in dataset*/
    data &standard.meta;
        set work.gcm_settemp;
        by domain;
        length labellist $ &len_label  
                   keepList $ &len_keep
                   lengthlist $ &len_length ;
        retain labellist keeplist lengthlist orderList ;
        keep domain labellist keeplist lengthlist orderList setlabel;
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

        /*fetch the length*/
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
        if last.domain;
    run;

    /*reduce the length of variables to the real requirement*/
/*    %reLenVars(datasets=&standard.meta)*/

    /* make a proc format control dataset out of the SDTM or ADaM metadata;*/
    %if &standard = SDTM %then %do;
        %let dsid=%sysfunc(open(templib.CodeLists));
        %if (&dsid=0) %then                                                                                                                   
            %put %sysfunc(sysmsg());                                                                                                             
        %else                                                                                                                                 
            %let fmtlen=%sysfunc(varlen(&dsid, %sysfunc(varnum(&dsid,CodeListName))));     
            %let labelen=%sysfunc(varlen(&dsid, %sysfunc(varnum(&dsid,CodedValue))));
            %let st2ndlen=%sysfunc(varlen(&dsid, %sysfunc(varnum(&dsid,SourceValue))));
        %let rc=%sysfunc(close(&dsid));     

        %let opts=%getops(varlenchk);
        options varlenchk=nowarn;
         
        data work.gcm_formatdata;
            /*use the length statement to fix the variable position*/
            length fmtname $ &fmtlen start end $ &st2ndlen label $ &labelen type $ 1;
            set templib.CodeLists;
            keep fmtname start end label type;

            fmtname = codelistname; 
            label = codedvalue;
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
        options varlenchk=&opts;
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
