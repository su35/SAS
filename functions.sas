proc fcmp outlib=publib.funcs.val;
*  DELETESUBR ;
*  DELETEFUNC ;
run;
/* *********************************************************** */
proc fcmp outlib=publib.funcs.val; 
   function splitdn(dn $, part $) $32;
        length lib dataset $32;
        dataset=scan(dn, 2, ".");
        if not missing(dataset) then do;
            if upcase(part) = "LIB" or upcase(part) = "LIBRARY" then do;
                lib=scan(dn, 1, ".");
                return(trim(lib));
            end;
            else return(trim(dataset));
        end;
        else do;
            if upcase(part) = "LIB" or upcase(part) = "LIBRARY" then do;
                call missing(lib); /*if the "." not be found return missing value for lib*/
                return(lib);
            end;
            else return(dn);
        end;
   endsub; 
run; 
/* *********************************************************** */
proc fcmp outlib=publib.funcs.val; 
   function splitstr(str $, part $, delm $) $32;
        length lib dataset $32;
        if index(str, delm) then do;
            if upcase(part) = "L" or upcase(part) = "LEFT" then result= scan(str, 2, delm, "b");    
            else if upcase(part) = "R" or upcase(part) = "RIGHT " then result= scan(str, 1, delm, "b");  
            return(trim(result));
        end;
        else do;
            put "The delimiter could not be found";
            return(str);
        end;
   endsub; 
run; 

/* ****************************************************** */
proc fcmp outlib=publib.funcs.val; 
   function nobs(dn $) ;
      dsid=open(dn);
      if dsid = 0 then do;
         put (sysmsg());
         call missing(record);
         end;
      else do;
         record=attrn(dsid, "NLOBS");
         dsid=close(dsid);
         end;
      return(record);
   endsub; 
run; 

/*macro var_length is defined in tools.sas*/
proc fcmp outlib=publib.funcs.val; 
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


proc fcmp outlib=publib.funcs.rep;
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
proc fcmp outlib=publib.funcs.crt;
   subroutine insert_excel(lib $, dataset $); 
      rc = run_macro('insert_excel', lib, dataset);
   endsub;
run;*/
/*Proc fcmp does not support 'optional' arguments. so there is no default value for base. pass '.' for no specific date*/
proc fcmp outlib=publib.funcs.cdate;
   function createdate(base);
      if base =.  then date=today()+INT(RAND('UNIForm') *100);
      else date = base+INT(RAND('UNIForm') *100);
      return (date);
   endsub;
run;
