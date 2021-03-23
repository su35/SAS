/* ***********************************************************************************************
     Name : rawDataInput.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose :  1. Read data from local raw files into orilib and valid
                     2. Reset the attributes
                     3. Add new variable if it is necessary
                     4. Create new dataset if it is necessary
                     5. Select the subjects for validation
*   *********************************************************************************************/
/* ****** Input the data from the raw data files ********** */
%ReadData()
%RemoveAttr(lib=orilib)

/* *********  declare the libref and refer the dictionaris as the datasets  *******************/
libname dict xlsx "&pdir.documents\CSP1025-Dictionary.xlsx";

/*Get the sponsors terminology*/
data _null_;
    set sashelp.vtable(keep=libname memname);
    where libname="DICT" and memname ne "TABLES";
    call execute ('%nrstr(%spTermin('||trim(memname)||'))');
run;
/*Get the dataset label and variable's label from the variable dictionary.*/
data _null_;
    set dict.tables;
    call execute('%nrstr(%reSetLabel('||trim(table)||','||quote(table_description)||'))');
run;

libname dict clear;

/*There is no usubjid in overall original dataset, , create the usubjid for each dataset*/
%SetUsubjid(length=25)
proc print data=orilib.enrl(obs=10 keep=subjid usubjid);
run;

/***********************************************************************************************************
  since the data de-identification,  the date of randomization = day 0.  For practice reason, 
  create a random date as a subject's ramdomizqtion date. The createdate() is a customer function
* **********************************************************************************************************/
data random;
    length usubjid $25 randdate 8;
    label randdate="Random Date";
    format randdate E8601DA10.;
    set orilib.random (keep=usubjid gender use treat);
    randdate=createdate('01JUl2016'd);
run;
proc sort data=random;
    by usubjid;
run;
proc print data=random(obs=10 keep=usubjid randdate);
run;

/******************************************************************************************************
  Select subjects for validation , pickup one from each status randomly,   for the datasets 
  in which a subject may have multi-recording, such as lb, ur, ae, and so on
* ****************************************************************************************************/
proc sort data=orilib.term out=work._usubjid;
    by status;
run;
proc surveyselect data=work._usubjid out=work._validsubject 
                                seed=1234 method=SRS n=(1 1 1 1 1 1 1 1 1 1) noprint;
    strata status;
run;
proc print data=work._validsubject(keep=usubjid status);
run;

data validsubject;
    length validsubject $ 300;
    retain validsubject;
    keep validsubject;
    set work._validsubject end=eof;
    validsubject=catx(',', validsubject, quote(trim(usubjid)));
    if eof;
    call symputx("validsubject", validsubject);
run;

