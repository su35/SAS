/* ***********************************************************************************************
     Name  : ReadData.sas
     Author: Jun Fang   August, 2016 
*    --------------------------------------------------------------------------------------------*
     Summary : description : Using pipe get all file name in a location, and then 
                                          call subroutine %readexl(), %readtxt(), %readacs(), %readsas()
                                          and %xpt2loc() to read the files into a dataset. Majorly used 
                                          when there are lots of text data file and no data structure 
                                          are available
                      purpose      : batch read the external files to datasets
*    --------------------------------------------------------------------------------------------*
     Contexts : program type   : routine
                     SAS type          : macro
*    --------------------------------------------------------------------------------------------*
     Specifications: input    : required: path, lib
                                         optional: delm
                           output : datasets named basing on the name of the external files
*    --------------------------------------------------------------------------------------------*
     Parameters : path  = the unqouted path to the data files location. 
                                     the default is the project data folder
                         lib     = the libref in where the new dataset would stored, the default
                                     is the project orilib.
                         delm = the delimiter for dlm type files. value with quote.
*   *********************************************************************************************/
%macro ReadData(path, lib, delm) /minoperator 
    des ="call subroutine to batch read the external files to datasets";
    /*since the excel file and access file may have multi-sheet or multi_table,
    * when the readexl() and readacs() are called in ReadData(), they need to update the expected 
    * number of datasets. However, when they are called in open code, there is not update needed.
    * so, the prefix rd_ is added  */
    %local rd_expnum renum;

    /*set the defualt value of the required params if the value is null*/
    %if %superq(path)= %then %let path=&pdir.data;
    %if %superq(lib)= %then %let lib=orilib;

    /*get the name of the files*/
    %dirlist(&path, work.rd_rawfiles)

    data work.rd_rawfiles;
        set work.rd_rawfiles end=eof;
        drop count;

        count+1;
  
        /*basing on the extname, call corresponding subroutine*/
        if extname in ("xls", "xlsb", "xlsm", "xlsx") then 
            call execute('%nrstr(%readexl("'||trim(fullname)||'", '||"&lib))");
        else if extname in ("txt", "csv", "dat", "data", "asc", "jmp"," ") then 
            call execute('%nrstr(%readtxt("'||trim(fullname)||'", '||"&lib))");
        else if extname in ("mdb", "accdb") then 
            call execute('%nrstr(%readacs("'||trim(fullname)||'", '||"&lib))");
        else if extname in ("xpt","v9xpt") then 
            call execute('%nrstr(%xpt2loc(libref='||"&lib, memlist="||trim(filename)||", filespec='&path\"||trim(fullname)||"'))");
        else if extname ="sas7bdat" then call execute('%nrstr(%readsas("'||trim(filename)||'", '||"&lib))");
        else do;
/*             count - 1;*/
             put "WARNING: A new extion name was found. File name is " fullname;
             return;
        end;
        if eof then call symputx('rd_expnum', count);
    run;

    /*get the number of dataset in &lib.*/
    proc sql noprint;
        select count(distinct memname)
        into :renum
        from dictionary.tables
        where libname=%upcase("&lib");
    quit;

    %put WARNING- The macro ReadDate() has executed. The number of input dataset is &renum.;
    %put WARNING- The validation files of text data files are stored in &ptemp.;
    %if &rd_expnum ne &renum %then
        %put ERROR-  However, the expected number of datasets is &rd_expnum. Check if all data has input.;

%mend ReadData;


