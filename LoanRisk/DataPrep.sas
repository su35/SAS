/* ==== run macro readdata() to input data ==== */
%ReadData(oriname=accepted_2007_to_2018.csv);
proc print data=orilib.accepted_2007_to_2018 (obs=10);
run;
/* ==== Get the real length of the char variables in accepted_2007_to_2018 ====*/
%getVarLen(orilib.accepted_2007_to_2018, outdn=_varlen)
/* ==== Out put the variables infor. and compare with variable dictionary. ==== */
proc sql;
    select name, type, length, rellen
    from (select name, type, length from dictionary.columns
       where memname="ACCEPTED_2007_TO_2018" and libname="ORILIB"
      ) as a left join
            (select variable, length as rellen from _varlen) as b on a.name=b.variable 
     order by 1;
quit;
/* check if the value of the char variables which have long length is free text.
*   if it is, then exclude it to reduce the dataset size.*/
proc sql;
   select name
   into :lvarlist 
   from dictionary.columns 
   where libname="ORILIB" and memname="ACCEPTED_2007_TO_2018"
                     and length>=20;
quit;

%let lvarlist=desc emp_title title hardship_type hardship_reason;

%CharValChk(orilib.accepted_2007_to_2018, &lvarlist)
/*hardship_type has only one value, check the percent of missing*/
proc freq data=orilib.accepted_2007_to_2018(keep=hardship_type);
    table hardship_type /nocum missing;
run;
/*1. The desc, emp_title, and title are free text. then exclude them.
*  2. The hardship_type has only one value, and 99.52% is missing value, so exclude it.
*  3. The member_id has missing value only, so exclude it.
*  4. The zip_code is too detail and keep the same type information as addr_state. exclude it.
*  5. The url is irrelative*/
%let exclude=desc emp_title title hardship_type member_id zip_code url;
/*Transform the datetime value to date value*/
proc sql noprint;
   select   "if not missing("||name||") then "||trim(name)||"=datepart("||trim(name)||")", trim(name)
   into :trlist separated by "; ", :folist separated by " "
   from dictionary.columns
   where libname="ORILIB" and memname="ACCEPTED_2007_TO_2018" and 
      format="DATETIME.";
quit;
/* ==== Copy the dataset to the loan library. ==== */
/*1. The id has a type as char and the length is 48, this is abnormal. 
*      Output the obs those the id length large than 10 to tmp_accp*/
data accepted tmp_accp;
   set orilib.accepted_2007_to_2018 (drop=&exclude);
   &trlist;
   format &folist date9. ;
   if lengthn(id) >12 then output tmp_accp;
   else output accepted;
run;
proc print data= tmp_accp;
run;

proc sql noprint;
   select max(length(id)) into :idlen trimmed
   from accepted (keep=id);

   alter table accepted
   modify id char(&idlen) format=$&idlen.. informat=$&idlen..;
quit;
proc print data=accepted(obs=10);
run;
/* ======== Input the data dictionary in project lib. ========== */
%ReadData(oriname=LCDataDictionary.xlsx);
/* The dictionary includes three sheets, but in each sheet the variables name are different 
** and  some variable in browsenotes, which include the variables that are available to 
** the investors, are not included data set.
** Map the variables among the sheets basing on the variable description, and mark the 
** variables that would be included in data set. */
%strtran(exclude)
proc sql noprint;
   create table vardict as
   select name as variable, type,  length
   from dictionary.columns
   where memname="ACCEPTED" and libname="LOAN" and name not in (&exclude)
   order by 1;

   select length into :desLen
   from dictionary.columns
   where memname="LCD_LOANSTATS" and libname="ORILIB" and lowcase(name)="description";
quit;

options varlenchk=nowarn;
data _brow(index=(description));
 /*when the data was input into SAS lib, the variable name would be truncated to 32*/
    length browsenotesfile $32;
    set orilib.lcd_browsenotes;
    description=strip(description);
run;
data _loanstats(index=(variable));
    length variable $32;
    set orilib.lcd_loanstats (rename=(loanstatnew=variable));
    /*remove all the illegal char such as blank, tab, linefeed and so on*/
    pid=prxparse("s/[^\w]//");
    variable=prxchange(pid, -1, variable);
    description=strip(description);
    drop pid;
run;
options varlenchk=warn;
/*check if there are variables that their name is different with the name 
in both of loanstats and browsenotesfile */
proc sql;
    select variable
    from vardict
    where variable not in (select browsenotesfile from _brow union
                                            select variable from _loanstats);
quit;
data _loanstats(index=(variable));
    set _loanstats;
    if variable="verified_status_joint" then variable="verification_status_joint";
run;

data vardict;
    length variable $32  description $&desLen;
    call missing(description);
    set vardict;
    set _loanstats key=variable;
    set _brow key=description;
    if _iorc_ eq 0 then apply=1;
    /*The issue_d and loan_status couldn't include in browsenotesfile. 
    However, issue_d is the time window variable and loan_status is the target. 
    So, both sould be keep in the dataset*/
    if variable in ("issue_d" "loan_status") then apply=1;
    if variable="id" then id=1;
    drop browsenotesfile;
    _error_=0;
run;

/*check if there is variable that should be included in apply risk model but doesn't include
* in browsenotes*/
proc print data=vardict;
   where apply is missing;
run;

/* Output to excel file, make it's easy to modify or correct.
** 1.  Add variable "class" and assign the value basing on description.
** 2.  Adjust the variable position if necessary*/
proc export data=vardict
                    outfile="&pout.vardict"
                    DBMS=xlsx;
run;
x "&pout.vardict.xlsx";

libname templib xlsx "&pout.vardict.xlsx";
proc copy in=templib out=&pname memtype=data;
run;
libname templib clear;

/* ==== Check missing value ==== */
%MissChk(accepted)
proc print data=acceptedmiss;
run;

/* Check if the value is associated with special time point. */
proc sql noprint;
   select variable 
   into :miss separated by " "
   from acceptedmiss;
quit;
/*For large dataset and long list of variables, 
    it will take time to exacute the marcro MissTimeWid*/
%MissTimeWid(accepted, &miss, issue_d, speed=1)
proc print data=misswid(keep=variable monthinterval where=(monthinterval>0)) ;
run;
/*Update variable dictionary dataset*/
proc sort data=misswid out=_misswid(index=(variable) drop=start);
   by variable;
   where monthinterval>0;
run;
data vardict;
   set vardict;
   call missing(timepoint, monthinterval);
   set _misswid key=variable;
   _error_=0;
run;
/* == Check the illegal of char value and map the char value to numeric value == */
proc sql noprint;
   select variable
   into :keeplist separated by  " "
   from vardict
   where type="char" and id is missing;
quit;
/*read the char variable only to reduce the excuting time.*/
ods output OneWayFreqs=_freq;
proc freq data=accepted(keep=&keeplist);
   table _char_ /missing nocum;
run;
ods output close;
proc sort data=_freq;
   by table;
run;

data _null_;
   file "&pout.charmap.csv";
   set _freq end=eof;
   by table;
   retain vid 0;
   if first.table then vid+1;
   variable=substr(table, 7);
   value=compbl(cat(of F_:));
   put vid " , " variable " , " value;
run;
/* Define the numeric value.
*  Since a macro variable included, the double quotes is need*/
x "&pout.charmap.csv";
data CharMap;
   infile "&pout.charmap.csv" dsd ;
   length vid value_n 4. variable value $32;
   input vid  variable   value value_n; 
run;
proc print data=CharMap;
run;
%ReCode(CharMap, outfile=reCode)
/*check the code*/
x "&pout.recode.txt";
/*transform the char variable to numeric variable*/
data accepted_n;
   set accepted;
   %include "&pout.recode.txt";
run;
proc print data=accepted_n (obs=10);
run;

%cleanLib()
