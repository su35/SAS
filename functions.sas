libname pub "D:\SAS\clinical trial\Projects\pub";
proc fcmp outlib=pub.funcs.val;
*	DELETESUBR strtran;
*	DELETEFUNC str_comp;
run;
/* ******************************************************
* get_vars_length function
* call macro get_vars_length to get the real max length of character variables .
* parameters
* dataset: the name of the dataset; character
* lib:  the name of the libaray
* query: the sql string to get the max length of the variable
* len: holding the max length of the  variable.
* ********************************************************/
proc fcmp outlib=pub.funcs.val; 
	function get_vars_length(lib $, dataset $, query $) ;
		rc = run_macro('get_vars_length', lib, dataset, query, len); 
		if rc eq 0 then return (len);
      	else return(.);
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
* ********************************************************/
proc fcmp outlib=pub.funcs.crt;
	subroutine insert_excel(lib $, dataset $); 
		rc = run_macro('insert_excel', lib, dataset);
	endsub;
run;
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
	function str_comp(str1 $, str2 $, t $) ; 	length str $ 100;OUTARGS
 str1;
/*		length comm diff $ 32767;
	s1=tranwrd(compbl(str1), ' ', '" "');
	s2=tranwrd(compbl(str2), ' ', '" "');
	l1=length(str1)-length(compress(str1)) + 1; 
	l2=length(str2)-length(compress(str2)) + 1; 
put s1=;
put l1=;
	/*	rc = run_macro('str_comp', str1, str2, t, comm, diff); 
		if rc eq 0 then do;
			if t="c" or t="comm" then result=strip(comm);
			else if t="d" or t="diff" then result=strip(diff);
			return ("yes");
		end;
      	else return("no");*/
/*	str1="dfakjfkdjfa";
return(str1);
	endsub; 
run; */
