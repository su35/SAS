/* ***********************************************************************************************
     Name: readexl.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     purpose      : input the data from an excel file
*    --------------------------------------------------------------------------------------------*
     program type   : routine
     SAS type          : macro
*    --------------------------------------------------------------------------------------------*
     Input    : required: filename
                   optional: lib
     Output : dataset name basing on the external file name and sheet name
*    --------------------------------------------------------------------------------------------*
     Parameters : filename = A quoted physical filename of the excel file that could include 
                                           the path. Since the excel file has several extention name, 
                                           the extention name should be include.
                         lib          = The libref that the input dataset would reside in                                    ,
*    -------------------------------------------------------------------------------------------*
     Note: Except ' \ / : * ？ " < > | ', other charactors that illegal for SAS are legal for 
              PC file naem. So, using data step is easy to control the dataset name
*   *********************************************************************************************/
%macro readexl(filename, lib);
    %local setname path prefix num;
    /*detect if the filename include the path. if it include the path, extract the setname. else, add
      project data path to filename*/
    %let filename=%nrbquote(%sysfunc(dequote(&filename)));
    %if %index(&filename,\) %then %let setname=%extract(&filename, R, \);
    %else %do;
        %let setname=&filename;
        %let filename=&pdir.data\&filename;
    %end;
    %if %superq(lib)= %then %let lib=%getlib();

    libname templb excel "&filename";

    /* if the sheets name include invalid char, the sheet name will be quoted*/
    proc sql noprint;
        select quote(dequote(compress(memname,'&,%'))), nliteral(dequote(memname))
        into :re_setname1-, :re_sheetname1-
        from dictionary.tables
        where libname= "TEMPLB" and memname not contains "FilterDatabase";
    quit;

    %let num=&sqlobs;

    /*if this call is come from %readdata(), update the re_expnum.*/
    %if %symexist(rd_expnum) %then %let rd_expnum=%eval(&rd_expnum+&num-1);

    %do i=1 %to &num;
        /*if noly one sheet, using the file name as dataset name.*/
        %if &num=1 %then %let re_setname&i=&setname;

        /*valid the name as SAS dataset name*/
        %let re_setname&i=%validname(&&re_setname&i);

        /*if there is a same name of dataset, then rename*/
        %if %sysfunc(exist(&lib..&&re_setname&i))=1 %then %do;
           %if %length(&&re_setname&i)>29 %then 
                    %let re_setname&i=%substr( &&re_setname&i, 1, 29);
           %let prefix=%substr(&setname, 1,3);
           %let re_setname&i=&prefix&&re_setname&i;
           %put WARNING- === &&re_sheetname&i in &setname was renamed to &&re_setname&i ===;
        %end;

        data &lib..&&re_setname&i;
            set templb.&&re_sheetname&i; 
        run;
    %end;

    libname templb clear;
%mend readexl;
