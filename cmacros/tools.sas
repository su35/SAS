/* ***********************************************************************************************
     Name  : Tools.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Include frequently used small macro
*   *********************************************************************************************/
/*********************************************************************************************************
  Remove the temporary dataets.
  Parameters : lib = The libref of the library that will be cleared. The default is the user library
* ********************************************************************************************************/
%macro cleanLib(lib);
   proc datasets %if not(%superq(lib)=) %then lib=&lib; 
               noprint;
      delete empty: _: temp: tmp:;
   run;
   quit;
%mend cleanLib;
/*********************************************************************************************************
  Delete the custom global macro variables except those are defined in setProjectEnvironment.sas
* ********************************************************************************************************/
%macro DelMvars() /minoperator;
   proc sql noprint;
      select distinct name
         into :cleanlist separated by ' '
         from sashelp.vmacro
         where scope = 'GLOBAL' and substr(name,1,3) ne 'SYS'  and substr(name,1,3) ne 'SQL'  
               and name not in("MVARCLEAN","PDIR","PNAME","PROOT","POUT","PTEMP");
   quit;
   %if %symexist(cleanlist) =1 %then %do;
      %symdel &cleanlist;
      %put NOTE: The global macro variables &cleanlist were deleted;
   %end;
   %else %put NOTE: There is no more global macro variables would be deleted;
%mend DelMvars;
/******************************************************************************************************
  Transforming a list of variables between quotes and without quotes. 
  Parameters : list = the name of a variable or a macro variable which value is a char list.
* ****************************************************************************************************/
%macro StrTran(list);
    %local oriops;
    %let oriops= %getops(quotelenmax, mlogic, symbolgen, mprint );

   options noquotelenmax nomprint nosymbolgen nomlogic;
   %if %sysfunc(prxmatch(/['""']/, &&&list)) %then 
      %let &list=%sysfunc(prxchange(s/\s+/%str( )/i, -1, 
                          %sysfunc(prxchange(s/[^\w_]/%str( )/i, -1, &&&list))));
   %else %do;
      %let &list="&&&list";
      %let &list=%sysfunc(prxchange(s/[\s]+/%str(" ")/i, -1, &&&list));
   %end;
   options &oriops;
%mend StrTran;
/******************************************************************************************************
  Modify the value of a up level macro variable that stored the name of a dataset or dataset 
  variable directly. Since it modify up level macro variable, add a prefix to param to avoid name collisions.
* ****************************************************************************************************/
%macro truncName(tn_name, len);
    /*Remove the illegal charactors*/
    %if %superq(len)= %then %let len=32;
    %let &tn_name=%sysfunc(prxchange(s/[_]+/_/i, -1, %sysfunc(prxchange(s/[^\w]/_/i, -1, %bquote(&&&tn_name)))));
    /*If the length is larger than &len, modify the name*/
    %if %length(&&&tn_name) >&len %then %do;
        %local i j name2;
        %let oriops=%getops(quotelenmax);
        options noquotelenmax;
        %let i=%sysfunc(countw(&&&tn_name, _));

        /*remove charactor "_"*/
        %if &i>1 %then %do;
            %do j=1 %to &i;
                    %let name2=&name2%sysfunc(propcase(%scan(&&&tn_name, &j, _)));
            %end;
            %put WARNING- The "_" has been removed from &tn_name;
            %let &tn_name=&name2;
       %end;

       /*if the length is still over &len, then truncate it to len*/
        %if %length(&&&tn_name) >&len %then %do;
            %let &tn_name=%substr(&&&tn_name, 1 , 32);
            %put WARNING- The length of the &tn_name truncated to &&&tn_name;
        %end;
       options &oriops;
   %end;
%mend truncName;

/******************************************************************************************************
  Modify a char string to a valid SAS dataset name, majorly using to modify the name from 
  the external file.
  Parameters : string = A quoted string which would be validated.
                      len     = the length of the variable
* ****************************************************************************************************/
%macro validname(string, len);
    %if %superq(len)= %then %let len=32;

    /*converts  the illegal chars to blank and remove the leading and trailing blanks*/
    %let string=%cmpres(%qsysfunc(prxchange(s/[_\W]/ /i, -1, &string)));

    /*if the length is larger than &len, then remove blanks, else converts blanks to "_"*/
    %if %length(&string)>&len %then %do;
        %let string=%sysfunc(compress(&string));
        /*if the length is still larger than &len after remove blank, then trunc the length to &len*/
        %if %length(&string)>&len %then %let string=%substr(&string,1,&len);    
    %end;
    %else %let string=%sysfunc(tranwrd(&string, %str( ), _));
    &string
%mend validname;

/* ***********************************************************************************************
    Parse the variable list, such as AE:, v1-v5 and so on
    Parameters : dname = one- or two-level data set name from which the variables 
                                        would be parse
                         vlist    = a macro variable name whose value is a list of variable name
*   *********************************************************************************************/
%macro parsevars(dname, vlist);
    proc transpose data=&dname (obs=0) out=work._variables (keep=_NAME_); 
        var &&&vlist;
    run;      
    proc sql noprint;
        select trim(_name_) into : &vlist separated by " " 
        from work._variables;
    quit;
%mend parsevars;

/*output data from a dataset to excel file. 
*  varlist= define the output variables. if it is null then output all.
* the output file will open automatically unless setting the open to another value */
%macro ToExcel(dataset, outfile=, sheet=, varlist=, open=1); 
   %local dn ext;
    /*if the &dataset may include the lib name, spilt the dataset name */
    %let dn=%sysfunc(splitstr(&dataset, right, .));
    %if %superq(sheet)= %then %let sheet=&dn;
    %if %superq(varlist) ne %then  %parsevars(&dn, varlist);
     /*if there is ext name in file, then remove the ext name*/
    %if %superq(outfile) = %then %let outfile=&pout.&dn;
    %else %if %sysfunc(prxmatch(/[\/\\]/, &outfile)) =0 %then %let outfile=&pout.&outfile;

   proc export data=&dataset%if %superq(varlist)^= %then (keep=&varlist);
      outfile="&outfile" DBMS=xlsx replace;
      sheet="&sheet";
   run;
   %if &open %then  x "&outfile..xlsx";
   ;
%mend ToExcel;

/* ***********************************************************************************************
     Get the real length of the char variables in a dataset
*    --------------------------------------------------------------------------------------------*
     Parameters : indn   = one- or two-level data set name for which the variable length
                                     would be checked
                         outdn = one- or two-level data set name in which the variable length 
                                       would be stored
*   *********************************************************************************************/
%macro getVarLen(indn, outdn); 
    %local lib setname varn getlen;

    %let lib=%extract(&indn, L, .);
    %let setname=%extract(&indn, R, .);
    %if &lib=&setname %then %let lib=%getLib;
    %if %superq(outdn) = %then %let outdn==_varLen;

    proc sql noprint;
        select catx(" ","max(lengthn(", name, ")) as ", name)
        into :getlen separated by ","
        from dictionary.columns
        where memname=upcase("&setname") and libname=upcase("&lib") and type="char";

        create table &outdn as
        select &getlen
        from &indn;
    quit;

    proc transpose data=&outdn out=&outdn(rename=(col1=length)) name=variable;
        var _all_;
    run;

    %put NOTE: ==The real length of the char variables in a dataset &dn is stored in &outdn.==;
%mend getVarLen;

%macro showPath;
    %put %sysget(sas_execfilepath);
%mend;

/* ================ Macro Functions ================= */
/******************************************************************************************************
  Get the current options for resetting after changing the options temprarily. 
  Since the number of the options is not ascertained, 
    using the parmbuff option to hold the parameters.
* ****************************************************************************************************/
%macro getops()/parmbuff;
    %local i ops buff;
    %let buff=%unquote(%sysfunc(compress(%str(&syspbuff),%str((,)))));
    %let i=1;
    %do %until (%scan(&buff, &i)=%str());
        %let ops=&ops %sysfunc(getoption(%scan(&buff, &i)));
        %let i=%eval(&i+1);
    %end;
    &ops
%mend getops;
/******************************************************************************************************
  Setting the libname, when it is needed but not assigned.
* ****************************************************************************************************/
%macro getLib();
    %local lib temp;
    %let temp=%sysfunc(getoption(user));
    %if %symglobl(pname)=1 %then %do;
        %if %sysfunc(libref(&pname)) = 0 %then %let lib=&pname;
    %end;
    %else %if %superq(temp) ne %then %let lib=&temp;
    %else %let lib=WORK;
    &lib
%mend getLib;
/******************************************************************************************************
  Get the engine of a libref. basically, for interacting with excel file. 
  The name of the sheet is different between the xlsx engine and excel engine

  Parameters : lib = The libref of the library that will be examed.
* ****************************************************************************************************/
%macro getEngine(lib);
    %local lid rc enginenum engine;
    %let lid=%sysfunc(open(sashelp.vlibnam(where=(libname=%upcase("&lib")))));
    %if &lid = 0 %then %do;
        %put %sysfunc(sysmsg());
        %return;
    %end;
    %let rc=%sysfunc(fetch(&lid));
    %let enginenum=%sysfunc(varnum(&lid, engine));
    %let engine=%sysfunc(getvarc(&lid, &enginenum));
    %let rc=%sysfunc(close(&lid));
    &engine
%mend getEngine;
/******************************************************************************************************
  Check if a variable exists in the data set. If it exists, return its position, else return 0.
  Parameters : dn = one- or two-level data set name for which the variable would be checked.
                      var = The name of the variable that would be checked.
* ****************************************************************************************************/
%macro existsVar(dn, var);
   %local dsid check rc lib;
   %let dsid = %sysfunc(open(&dn));
   %if &dsid=0 %then %put %sysfunc(sysmsg());                                                                                                             
   %else %let check = %sysfunc(varnum(&dsid, &var));
   %let rc = %sysfunc(close(&dsid));
   &check
%mend existsVar;
/* ***********************************************************************************************
     Split a string to two part. Typically, a full file name to path and file name or
     a two-level dataset name to library and dataset name.
*    --------------------------------------------------------------------------------------------*
     Parameters : source = The char string which will be split
                         side     = Which part required. 
                                       For left part, it could be l, left, and 1. 
                                       For right part, it could be r, right, and 2.
                         dlm     = The delimiter.
*   *********************************************************************************************/
%macro extract(source, side, dlm) /minoperator;
    %local value position;

    /*set the defualt value of the required params if the value is null*/
    %if %superq(dlm) =  %then %let dlm=.;
    %if %superq(side)= %then %let side=R;

    %if %upcase(&side) in (L LEFT 1 R RIGHT 2) %then %do;
        %let position=%sysfunc(find(%nrbquote(&source), &dlm, -260, i));
        %if &position %then %do;
            /*if the last char in source is the dlm, then remove it first*/
            %if %length(&source)=&position %then 
                %let source=%qsubstr(%nrbquote(&source), 1,%eval(&position-1));

            %if %upcase(&side) in (R RIGHT 2) %then %do;
                %let value=%qscan(%nrbquote(&source), -1, &dlm);
            %end;
            %else %do;
                %let value=%qsubstr(%nrbquote(&source), 1, 
                                                %eval(%sysfunc(find(%nrbquote(&source), &dlm, -260, i))-1));
            %end;
        %end;
        %else %do;
            %let value=&source;
            %put WARNING- === The delimiter was not found, return the original value ===;
        %end;
    %end;
    %else %do;
        %let value=&source;
        %put WARNING- === The parameter side was not assinged rightly, return the original value ===;
    %end;
    &value
%mend extract;
/******************************************************************************************************
  Return the variable list of a given dataset. 
  Parameters : dsn = one- or two-level data set name.
* ****************************************************************************************************/
%macro getVarList(dsn);  
    %local dsid cnt rc i rtnStr;
    %let dsid=%sysfunc(open(&dsn));
    %let cnt=%sysfunc(attrn(&dsid,nvars));

    %do i = 1 %to &cnt;
        %let rtnStr=&rtnStr %sysfunc(varname(&dsid,&i));
    %end;

    %let rc=%sysfunc(close(&dsid));
    &rtnStr
%mend getVarList;

/* ====== macro call by customize function ====== */
/******************************************************************************************************
  Get the real max length for given variable
* ****************************************************************************************************/
%macro var_length();
   %let lib = %sysfunc(dequote(&lib));
   %let var = %sysfunc(dequote(&var));
   %let dn = %sysfunc(dequote(&setn));
   proc sql noprint;
      select max(lengthn(&var)) into :len
      from &lib..&dn;
   quit;
%mend var_length;

