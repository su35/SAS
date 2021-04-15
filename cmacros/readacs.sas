/* ***********************************************************************************************
     Name: readacs.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     purpose      : input the data from an access file
*    --------------------------------------------------------------------------------------------*
     program type   : routine
     SAS type          : macro
*    --------------------------------------------------------------------------------------------*
     Input    : required: filename
                   optional: lib
     Output : dataset name basing on the external file name and table name
*    --------------------------------------------------------------------------------------------*
     Parameters : filename = A quoted physical filename of the excel file that could include the path. 
*                                         since the access file has 2 extention name, 
                                           the extention name should be include.
                         lib          =  the libref that the input dataset would reside in                                    ,
*    -------------------------------------------------------------------------------------------*
     Note: Except ' \ / : * ？ " < > | ', other charactors that illegal for SAS are legal for 
              PC file naem. So, using data step is easy to control the dataset name
*   *********************************************************************************************/
%macro readacs(filename, lib);
    %local setname path prefix num;
    /*detect if the filename include the path. if it include the path, extract the setname. else, add
      project data path to filename*/
    %let filename=%nrbquote(%sysfunc(dequote(&filename)));
    %if %index(&filename,\) %then %let setname=%extract(&filename, R, \);
    %else %do;
        %let setname=&filename;
        %let filename=&pdir.data\&filename;
    %end;
    %if %superq(lib)= %then %let lib=orilib;

    libname templb access "&filename";

     proc sql noprint;
        select quote(dequote(compress(memname,'&,%'))), nliteral(dequote(memname))
        into :ra_setname1-, :ra_tname1-
        from dictionary.tables
        where  libname= "TEMPLB";
     quit;

     %let num=&sqlobs;

    /*if this call is come from %readdata(), update the re_expnum.*/
    %if %symexist(rd_expnum) %then %let rd_expnum=%eval(&rd_expnum+&num-1);

     %do i=1 %to &num;
         /*if noly one table, using the file name as dataset name.*/
        %if &num=1 %then %let ra_setname&i=&setname;
        /*valid the name as SAS dataset name*/
        %let ra_setname&i=%validname(&&ra_setname&i);

        %if %sysfunc(exist(&lib..&&ra_setname&i))=1 %then %do;
           %if %length(&&ra_setname&i)>29 %then 
                    %let ra_setname&i=%substr( &&ra_setname&i, 1, 29);
           %let prefix=%substr(&setname, 1,3);
           %let ra_setname&i=&prefix.&&ra_setname&i;
           %put WARNING- === &&ra_tname&i in &setname was renamed to &&ra_setname&i ===;
        %end;

        data &lib..&&ra_setname&i;
            set templb.&&ra_tname&i;
        run;
     %end;

    libname templb clear;
%mend readacs;
