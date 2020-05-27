/* **************************************************************
* macro cdsic.sas
* Create the xpt datasets and define.xml file for ADaM and SDTM
* Call macro P21Validate to validate the exported xpt datasets
* standard:  ADaM or SDTM
* file: specify the metadata file. the default is the adam_metadata.xlsx
* or sdtm_metadata.xlsx file under the project folder
* **************************************************************/
%macro cdsic(standard, file, xsldefine)/minoperator ;
    %if %sysfunc(fileexist(&pdir&standard))=0 %then %do;
        data _null_;
            NewDir=dcreate("&standard","&pdir");
        run; 
    %end;
    %if %superq(file)=  %then %let file=&standard._METADATA.xlsx;
    %if %superq(xsldefine)=  %then %let xsldefine=define2-0-0.xsl;

    %local i;
    %let path=&pdir.&standard;
    %let metadatafile=&pdir.&file;
    %sysexec copy &proot.pub\&xsldefine &path.\&xsldefine;

    options nonotes;
    options varlenchk=nowarn;

    %make_define(path=&path, metadata=&metadatafile);

    /*work.md_toc_metadata was created by make_define*/
    proc sql noprint;
        select name
            into :dmlist separated " "
            from work.md_toc_metadata;
    quit;
    %let dmnum=&sqlobs;

    /*create the xpt files*/
    %do i = 1 %to &dmnum;
        %let dataset = %scan(&dmlist, &i); 
        /*remove the sort flag to avoid the warnning in log*/
        proc datasets noprint;
            modify &dataset(sortedby=_null_);
        run;
        quit;

        libname templb  xport "&path.\&dataset..xpt";
        proc copy in=&pname out=templb ;
            select &dataset;
        run;
    %end;
    libname templb clear;
    
    %if %upcase(&standard) = ADAM %then %do;
        %let ctdatadate=2016-03-25;
        %let config=ADaM 1.0.xml;
    %end;
    %else %if %upcase(&standard) = SDTM  %then %do;
        %let ctdatadate=2016-06-24;
        %let config=SDTM 3.2.xml;
    %end;
    %else %put WARN ING: The standard is &standard. Please run p21_validate with correct parameters manually.;

    /*Since the install path of pinnacle21-community wouldn't change, the p21path had been 
    * hard-cording in macro P21Validate. If move to another computer, it is need to re-cording
    * in P21Validate, or assign the p21path= para*/
    %P21Validate(type=&standard, sources=&path , ctdatadate=&ctdatadate, config=&config);

    proc datasets lib=work noprint;
        delete md_: ;
    run;
    quit;

    options varlenchk=warn;
    options notes;
    %put NOTE:  ==The macro CDSIC executed completed.==;
%mend cdsic;

