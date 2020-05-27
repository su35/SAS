*---------------------------------------------------------------*;
* MakeEmptyDataset.sas creates a zero record dataset based on a 
* dataset metadata spreadsheet.  The dataset created is called
* EMPTY_** where "**" is the name of the dataset.  This macro also
* creates a global macro variable called **keeplist that holds 
* the dataset variables desired and listed in the order they  
* should appear.  [The variable order is dictated by VARNUM in the 
* metadata spreadsheet.]
*
* MACRO PARAMETERS:
* standard = ADaM or SDTM
* dataset = the dataset or domain name you want to extract
*---------------------------------------------------------------*;
%macro MakeEmptyDataset(standard, dataset=)/minoperator;
    %local i j dmlist dmnum;
    options nonotes;

    %if %sysfunc(libref(&standard.file)) ne 0 %then  
        libname &standard.file "&pdir.&standard._METADATA.xlsx";;

    %if %superq(dataset)=  %then %do;
        proc sql noprint;
            select distinct domain
                into :dmlist separated " "
                from &standard.file."VARIABLE_METADATA$"n
                where domain is not missing;
        quit;
        %let  dmnum = &sqlobs;
    %end;
    %else %let dmnum=1;

    %do j = 1 %to &dmnum;
        %if &dmnum > 1  %then %let dataset = %scan(&dmlist, &j, ' ' ); 
        ** sort the dataset by expected specified variable order;
        proc sort   data=&standard.file."VARIABLE_METADATA$"n out=work._settemp;
            where domain = upcase("&dataset");
            by varnum;    
        run;
        ** create keeplist macro variable and load metadata 
        ** information into macro variables;
        %global &dataset.keeplist;
        data _null_;
            set work._settemp nobs=nobs end=eof;
            length format $ 20.;
            if _n_=1 then
            call symput("vars", cats(nobs));

            call symputx(cats('var', _n_), variable);
            call symputx(cats('label',  _n_), label);
            call symputx(cats('length', _n_), cats(length));

            ** valid ODM types include TEXT, INTEGER, FLOAT, DATETIME, 
            ** DATE, TIME and map to SAS numeric or character;
            if upcase(type) in ("INTEGER", "FLOAT") then
            call symputx(cats('type', _n_), "");
            else if upcase(type) in ("TEXT", "DATE", "DATETIME", "TIME", "CHAR") then
            call symputx(cats('type', _n_), "$");
            else
            put "ERR" "OR: not using a valid ODM type.  " type=;

            ** create **keeplist macro variable;
            length keeplist $ 32767;     
            retain keeplist;        
            keeplist = catx(' ', keeplist, variable); 
            if eof then
            call symputx("&dataset.keeplist", keeplist);
        run;
        ** create a 0-observation template data set used for assigning 
        ** variable attributes to the actual data sets;
        data EMPTY_&dataset;
            %do i=1 %to &vars;           
                attrib &&var&i label="&&label&i"
                %if "&&length&i" ne "" %then
                length=&&type&i.&&length&i... ;
                ;
            %end;
            stop;
        run;
    %end;
    options notes;
    %put NOTE:  ==The macro MakeEmptyDataset executed completed.== ;
    %put NOTE:  ==The empty &standard dataset was created.==;
%mend MakeEmptyDataset;
