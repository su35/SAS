/* ***************************************
* Include frequently used small macro
* ***************************************/
/*macro cleanLib: remove the temporary dataets*/
%macro cleanLib(lib);
   proc datasets %if not(%superq(lib)=) %then lib=&lib; 
               noprint;
      delete empty: _: temp: tmp:;
   run;
   quit;
%mend cleanLib;
/* ***************************************************************
*  macro str_tran
*  add or remove the quotation marks surrounding variables
*  list: the name of the macro variable 
* ****************************************************************/
/*delet global macro variables*/
%macro DelMvars() /minoperator;
   proc sql noprint;
      select distinct name
         into :cleanlist separated by ' '
         from sashelp.vmacro
         where scope = 'GLOBAL' and substr(name,1,3) ne 'SYS'  and substr(name,1,3) ne 'SQL'  
               and name not in("MVARCLEAN","PDIR","PNAME","PROOT","POUT");
   quit;
   %if %symexist(cleanlist) =1 %then %do;
      %symdel &cleanlist;
      %put NOTE: The global macro variables &cleanlist were deleted;
   %end;
   %else %put NOTE: There is no more global macro variables would be deleted;
%mend;
/*transfer a list of variables between with quotes and without quotes.
* the "list" is the name of a variable or a macro variable which value is a char list.*/
%macro StrTran(list);
   options noquotelenmax;
   %if %sysfunc(prxmatch(/['""']/, &&&list)) %then 
      %let &list=%sysfunc(prxchange(s/\s+/%str( )/i, -1, 
                          %sysfunc(prxchange(s/[^\w_]/%str( )/i, -1, &&&list))));
   %else %do;
      %let &list="&&&list";
      %let &list=%sysfunc(prxchange(s/[\s]+/%str(" ")/i, -1, &&&list));
   %end;
%mend;
/*Parse the variable list, such as AE:, v1-v5 and so on  *
* the varlist is a name of a macro variable                     */
%macro parsevars(dataset, varlist);
    proc transpose data=&dataset (obs=0) out=work._variables (keep=_NAME_); 
        var &&&varlist;
    run;      
    proc sql noprint;
        select trim(_name_) into : &varlist separated by " " 
        from work._variables;
    quit;
%mend;
/*Parse the dataset name. 
* The libvar and setvar are two macro variable names defined in parent*/
/*%macro paresdset(dn, libvar, setvar);*/
/*    %if %index(&dn, .) %then */
/*        %do;*/
/*            %let &libvar=%scan(&dn, 1, .);*/
/*            %let &setvar=%scan(&dn, 2, .);*/
/*        %end;*/
/*    %else */
/*        %do;*/
/*            %if %symglobl(pname) %then  %let &libvar= &pname%str(;); */
/*             %else %let &libvar= work;  ;*/
/*            %let &setvar=&dn;*/
/*        %end;*/
/*%mend;*/

/*Split a string to two part. Typically, a full file name to path and file name or
* a two-level dataset name to library and dataset name.*/
%macro extract(source, delimiter, side);
    %if %superq(delimiter) =  %then 
        %do;
            %put ERROR: The paras delimiter is missing, %extract failed;
            %return;
        %end;
    %if %superq(side)= %then %let side=L;
   %local point value;
   %let point=%qsysfunc(find(&source, &delimiter, -999));
   %if &point=0 %then 
        %do;
            %put NOTE: The delimiter has not been found, the &source will be retrun;
            %let value=&source;
        %end;
   %else %do;
      %if %upcase(&side)=L or &side=1 %then 
                        %let value=%qsubstr(&source, 1, %eval(&point-1));
      %else %let value=%qsubstr(&source, %eval(&point+1));
   %end;
   &value
%mend extract;
/*output data from a dataset to excel file. 
*  varlist= define the output variables. if it is null then output all.
* the output file will open automatically unless setting the open to another value */
%macro ToExcel(dataset, outfile=, sheet=, varlist=, open=y); 
   %local point dn;
   /*if the &dataset may include the lib name, spilt the dataset name */
   %let point=%index(&dataset, %str(.));
   %if &point %then %let dn=%substr(&dataset, %eval(&point+1) );
   %else %let dn=&dataset;

   %if %superq(outfile)^= %then %do;
      /*check if the file include the path*/
      %let point=%sysfunc(find(&outfile,/, -500));
      %if &point=0 %then %let point=%sysfunc(find(&outfile,\, -500));
      %if &point=0 %then %let outfile=&pout.&outfile;  

      /*if there is ext name in file, then remove the ext name*/
      %let point=%sysfunc(find(&outfile,%str(.), -500));
      %if &point %then %let outfile=%substr(&outfile, 1, %eval(&point-1));
   %end;
   %else %let outfile=&pout.&dn;
   %if %superq(sheet)= %then %let sheet=&dn;
   proc export data=&dataset%if %superq(varlist)^= %then (keep=&varlist);
      outfile="&outfile" DBMS=xlsx replace;
      sheet="&sheet";
   run;
   %if &open=y %then  x "&outfile..xlsx";
   ;
%mend;
%macro readexcel(dn, file, nlist=);
   %local point tranlist dlist relist;
   %let point=%sysfunc(find(&file, ., -999));
   %if &point=0 %then %let file=&file..xlsx;
   %let point=%sysfunc(find(&file, \, -999));
   %if &point=0 %then %let file=&pout.&file;

   proc import datafile="&file"  out=&dn replace;
      getnames=yes;
   run;

   %if %superq(nlist)^= %then %do;
      %strtran(nlist)
      proc sql noprint;
         select trim(name)||"_n=input("||trim(name)||", 8.)",
            trim(name), trim(name)||"_n="||trim(name)
         into :tranlist separated by "; ", :dlist separated by " ", :relist separated by " "
         from dictionary.columns
         where libname=upcase("&pname") and memname=upcase("&dn")
            and type="char" and name in (&nlist);
      quit;
   %end;

   %if %symlocal(tranlist) and %superq(tranlist)^= %then %do;
      data &dn(rename=(&relist));
         set &dn;
         &tranlist;
         drop &dlist;
      run;
   %end;
%mend readexcel;

/*output data from a dataset to csv file*/
%macro ToCSV(dataset, outfile=, vlist=, open=y); 
   %local point dn ln nlist uplist;
   /*if the &dataset may include the lib name, spilt the dataset name */
   %let point=%index(&dataset, %str(.));
   %if &point %then %do;
      %let ln=%substr(&dataset, 1, %eval(&point-1) );
      %let dn=%substr(&dataset, %eval(&point+1) );
   %end;
   %else %do;
      %let ln=&pname;
      %let dn=&dataset;
   %end;
   %if %superq(outfile)^= %then %do;
      /*check if the file include the path*/
      %let point=%sysfunc(find(&outfile,/, -500));
      %if &point=0 %then %let point=%sysfunc(find(&outfile,\, -500));
      %if &point=0 %then %let outfile=&pout.&outfile;  
      /*if there is ext name in file, then remove the ext name*/
      %let point=%sysfunc(find(&outfile,'.', -500));
      %if &point %then %let outfile=%substr(%str(&outfile), 1, %eval(&point-1));
   %end;
   %else %let outfile=&pout.&dn;

   %if %superq(vlist)^= %then %strtran(vlist);
   proc sql noprint;
      select name, name, ifc(type="char", trim(name)||"=trim("||trim(name)||")", ""),
      ifc(type="char", trim(name)||" $"||put(length+5, 8.), "")
      into :varlist separated by " ',' ", :nlist separated by ",", :tranlist separated by " ",
         :lenlist separated by " "
      from dictionary.columns
      where libname=%upcase("&ln") and memname=%upcase("&dn")
         %if %superq(vlist)^= %then and name in (&vlist);
      ;
      %if %superq(tranlist)^= %then %do;
         %let tranlist=%sysfunc(tranwrd(%sysfunc(compbl(&tranlist)), =, ='"'||));
         %let tranlist=%sysfunc(tranwrd(&tranlist, %str( ), %str(||'"';)))||'"'%str(;);
      %end;
   quit;
   options missing=" ";
   filename &dn "&outfile..csv";
   data _null_;
      %if %superq(lenlist)^= %then length &lenlist; ;
      set &dataset;
      rc=fdelete("&dn");
      file &dn lrecl=32767;
      if _N_=1 then put "&nlist";
      %if %superq(tranlist)^= %then &tranlist; ;
      put &varlist;
   run;
   options missing=".";
   %if &open=y %then  x "&outfile..csv";
   ;
%mend;
/*  macro getVarLen. get the real length of the char variables in a dataset*/
%macro getVarLen(dn, outdn=varLen); 
    %local i lib setname varn getlen;
    %let lib=%sysfunc(splitdn(&dn, lib));
    %let setname=%sysfunc(splitdn(&dn, set));
    proc sql noprint;
        select catx(" ","max(lengthn(", name, ")) as ", name)
        into :getlen separated by ","
        from dictionary.columns
        where memname=upcase("&setname") and libname=upcase("&lib") and type="char";

        create table &outdn as
        select &getlen
        from &dn;
    quit;

    proc transpose data=&outdn out=&outdn(rename=(col1=length)) name=variable;
        var _all_;
    run;

    %put NOTE: ==The real length of the char variables in a dataset &dn is stored in &outdn.==;
%mend getVarLen;

 %macro debuger(intera, vars=);
   %local i;
   %if %superq(intera)= %then %let intera=1;
   %do i=1 %to &intera;
      go;
      examine %if %superq(vars)^= %then &vars;
               %else _all_;
               ;
   %end;
%mend debuger;

/* Check if a variable exists in the data set. If it exists, return its position, else return 0. */
%macro existsVar(dn=, var=);
   %local dsid check rc lib;
   %let dsid = %sysfunc(open(&dn));
   %if &dsid=0 %then %put %sysfunc(sysmsg());                                                                                                             
   %else %let check = %sysfunc(varnum(&dsid, &var));
   %let rc = %sysfunc(close(&dsid));
   &check
%mend existsVar;
/*convert char to numeric*/
%macro c2n(dn, vlist);
   %local i n var rename;
   %let n=%sysfunc(countw(&vlist));
   data &dn;
      set &dn;
      %do i=1 %to &n;
         %let var=%scan(&vlist, &i, %str( ));
         &var.n=input(&var, 8.);
         %let rename=&rename &var.n=&var;
      %end;
      drop &vlist;
      rename &rename;
   run;
%mend;


/* ====== macro call by customize function ====== */
/* macro var_length: get the real max length for given variable */
%macro var_length();
   %let lib = %sysfunc(compress(&lib,"'"));
   %let var = %sysfunc(compress(&var,"'"));
   %let dn = %sysfunc(compress(&setn,"'"));
   proc sql noprint;
      select max(lengthn(&var)) into :len
      from &lib..&dn;
   quit;
%mend var_length;

