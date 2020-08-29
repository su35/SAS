*---------------------------------------------------------------*;
* MakeFormats.sas creates a permanent SAS format library
* stored to the &lib from the codelist metadata file 
* &standard_METADATA.xlsm.  The permanent format library that is created
* contains formats that are named as the codelistname in the 
* codelist sheet. 
*---------------------------------------------------------------*;
%macro MakeFormats(standard, lib=&pname);
    %if %superq(standard) = %then %do;
        %put ERROR: == The standard is not assigned ==;
        %return;
    %end;
    
    libname templib xlsx "&pdir.&standard._METADATA.xlsm";

    /* make a proc format control dataset out of the SDTM or ADaM metadata;*/
    options varlenchk=nowarn;
    data formatdata;
        length fmtname $ 32 start end $ 16 label $ 200 type $ 1;
        set templib.CodeLists;
        /*where setformat = 1;
        where sourcevalue ne "";*/
        keep fmtname start end label type;
        fmtname = compress(codelistname);
        %if &standard = SDTM %then %do;
            start = trim(scan(sourcevalue, 1,','));
            end = trim(scan(sourcevalue, -1,','));          
        %end;
        %else %do;
            start = trim(scan(CODEDVALUE, 1,','));
            end = trim(scan(CODEDVALUE, -1,','));
        %end;
        label = left(codedvalue);
        if upcase(sourcetype) in ("NUMBER", "NUM", "N","INTEGER","FLOAT") then
            type = "N";
        else if upcase(sourcetype) in ("CHARACTER", "TEXT", "CHAR", "C") then
            type = "C";
    run;
    
    libname templib clear;

    /* create a SAS format library to be used in SDTM or ADaM conversions;*/
    proc format
        library=&lib
        cntlin=formatdata
        fmtlib;
    run;
    options varlenchk=warn;
    %put NOTE:  ==The macro MakeFormats executed completed.==;
    %put NOTE:  ==The formats are stored in &lib.==;
%mend MakeFormats;
