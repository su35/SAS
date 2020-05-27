libname pub "D:\SAS\clinical trial\Projects\pub";
proc fcmp outlib=pub.funcs.val;
*  DELETESUBR ;
*  DELETEFUNC ;
run;
/* *********************************************************** */
proc fcmp outlib=pub.funcs.val; 
   function splitdn(dn $, part $) $32;
      length name $32;
      p=index(dn, '.');
      if upcase(part) = "LIB" or upcase(part) = "LIBRARY" then do;
         if p = 0 then do;
            put  "NOTE: The dataset name is a one level name. There is no library part and user library is retrun.";
            name=getoption("user");
         end;
         else name = substr(dn, 1, p-1);
      end;
      else if upcase(part)="SET" or upcase(part)="DATASET" then do;
         if p = 0 then name=dn;
         else name=substr(dn, 1+p);
      end;
      else do;
         name=" ";
         put "WARNING: Which part would be extracted has not been specified or an error value be assigned";
      end;
      return(trim(name));
   endsub; 
run; 
/* *********************************************************** */

/* ****************************************************** */
proc fcmp outlib=pub.funcs.val; 
   function nobs(dn $) ;
      dsid=open(dn);
      if dsid = 0 then do;
         put (sysmsg());
         record=.;
         end;
      else do;
         record=attrn(dsid, "NLOBS");
         dsid=close(dsid);
         end;
      return(record);
   endsub; 
run; 
/*macro var_length is defined in tools.sas*/
proc fcmp outlib=pub.funcs.val; 
   function var_length(dn $, var $) ;
      length lib setn $32;
      lib=splitdn(dn, "lib");
      if missing(lib) then lib=getoption(user);
      setn=splitdn(dn, "set");
      rc = run_macro('var_length', lib, setn, var, len); 
      if rc eq 0 then return (len);
         else return(0);
   endsub; 
run; 

/* ******************************************************
* check_missing call routine
* call macro check_missing to count the missing value for the SDTM
   required variables.
* parameters
* dataset: the name of the dataset 
* variable: the variables list would be checked
* ********************************************************/
proc fcmp outlib=pub.funcs.chk;
   subroutine check_missing(dataset $, variable $); 
      rc = run_macro('check_missing', dataset, variable);
   endsub;
run;

proc fcmp outlib=pub.funcs.rep;
/* ******************************************************
* dm_summary_set call routine
* call macro dm_summary_set to create dm report dataset for report.
* parameters
* setname: the name of the dm dataset; character
* varlist: the dm dataset variables list which planned to report; character
* class: grouping variable including both character and numerice variables, 
      usually be arm/trtp armcd/trtpn; character
* analylist: required statistic data specified for the numeric variables.
* ********************************************************/

   subroutine dm_summary_set(setname $, varlist $, class$, analylist $);
      rc=run_macro('dm_summary_set',setname,varlist,class, analylist);
   endsub;
/* ******************************************************
* ae_summary_set call routine
* call macro ae_summary_set to create ae report dataset for report.
* parameters
* setname: the name of the ae dataset; character
* var: the variable name based on which the ae would be counted
* ********************************************************/

   subroutine ae_summary_set(setname $, var $);
      re=run_macro('ae_summary_set', setname,var);
   endsub;

run;

/* ******************************************************
* insert_excel call routine
* call macro insert_excel to create a excel file or inset a sheet into an existed excel file
* parameters
* lib: specify the libaray
* dataset: the name of the original dataset; character
* file: the name of the excel file
* *******************************************************
proc fcmp outlib=pub.funcs.crt;
   subroutine insert_excel(lib $, dataset $); 
      rc = run_macro('insert_excel', lib, dataset);
   endsub;
run;*/
/*Proc fcmp does not support 'optional' arguments. so there is no default value for base. pass '.' for no specific date*/
proc fcmp outlib=pub.funcs.cdate;
   function createdate(base);
      if base =.  then date=today()+INT(RAND('UNIForm') *100);
      else date = base+INT(RAND('UNIForm') *100);
      return (date);
   endsub;
run;
/*firstday (0 or 1) refer the first is set day0 or day1*/
proc fcmp outlib=pub.funcs.sdate;
   function set_date( in_date, event_date);
      date= event_date + in_date;
      return (date);
   endsub;
run;
/*
proc fcmp outlib=pub.funcs.val; 
   function str_comp(str1 $, str2 $, t $) ;  length str $ 100;OUTARGS
 str1;
/*    length comm diff $ 32767;
   s1=tranwrd(compbl(str1), ' ', '" "');
   s2=tranwrd(compbl(str2), ' ', '" "');
   l1=length(str1)-length(compress(str1)) + 1; 
   l2=length(str2)-length(compress(str2)) + 1; 
put s1=;
put l1=;
   /* rc = run_macro('str_comp', str1, str2, t, comm, diff); 
      if rc eq 0 then do;
         if t="c" or t="comm" then result=strip(comm);
         else if t="d" or t="diff" then result=strip(diff);
         return ("yes");
      end;
         else return("no");*/
/* str1="dfakjfkdjfa";
return(str1);
   endsub; 
run; */
