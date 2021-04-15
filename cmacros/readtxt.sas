/* Macro %readtxt(): input the data from an text file.
*   Params:
*   filename: The source file that could include the path. 
*                  since the extention name is used to determin the dbms, the ext name should be include.
*                  
*   lib: the libref that the input dataset would reside in.
*   Except ' \ / : * ？ " < > | ', other charactors that illegal for SAS are legal for PC file naem.  
*   a validation file will output to project outfile folder*/

%macro readtxt(filename, lib, delm)/minoperator;
    %local setname path type ext;
/*    %if %superq(delm)= %then %let delm=dlm;*/
    /*detect if the filename include the path. if it include the path, extract the setname. else, add
      project data path to filename*/
    %if %superq(lib)= %then %let lib=orilib;
    %let filename=%nrbquote(%sysfunc(dequote(&filename)));
    %if %index(&filename,\) %then %let setname=%extract(&filename, R, \);
    %else %do;
        %let setname=&filename;
        %let filename=&pdir.data\&filename;
    %end;
    %if %index(&setname, .) %then %do;
        %let ext=%extract(&setname, R, .);
        %let setname=%extract(&setname, L, .);
    %end;
    %else %let ext=;
    %if %upcase(&ext) = CSV or %upcase(&type) = JMP %then %let type=&ext;
    %else %let type=dlm;
    %let setname=%validname(&setname);

   proc import datafile = "&filename"
                          out=&lib..&setname
                          dbms=&type
                          replace;
      getnames=yes;
      /*a large number will take some time, but it is faster than semi-automatic;*/
      guessingrows=max;
      /* if specify DBMS=DLM, the DELIMITER= statement must also specify .*/
      %if &type=dlm %then  %do;
            %if %superq(delm) ne  %then  delimiter=&delm%str(;) ;
            %else delimiter=" "%str(;) ;
        %end;
   run;

   /*output the dataset as the same type and compare with the original file by compare software*/
       proc export data=&lib..&setname
                            outfile="&pout&setname..&ext"
                            dbms=&type
                            replace;
          %if &type=dlm %then  %do;
                %if %superq(delm) ne  %then  delimiter=&delm%str(;) ;
                %else delimiter=" "%str(;) ;
            %end;
        run; 
   
%mend readtxt;
