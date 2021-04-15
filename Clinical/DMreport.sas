/* ***********************************************************************************************
     Name  : DMreport.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: List the demographic data and statistical result.
*   *********************************************************************************************/
/* *******************************************************************************
* "blankno" define the indentation of sub-term.  for listing output, using the number of blanks 
* for HTML output, using a "&#160;", and use javascript and CSS file to control the indentation
* **************************************************************************************/
%let blankno=&#160%str(;) ;
/*define the list of variables that will be listed in the demographic report.*/
%let listvar=age sex race educatyr employ maritals;
%let analylist=n mean median min max;
%let class=trt01p trt01pn;
/* =========== Create Demographic Summary Table =========== */
%DMReportSet(adsl, varlist=&listvar, class=&class, analylist=&analylist, outdn=dmreport)

 /* put the number of subjects in each trt group into the global macro and remove blank */
proc sql noprint; 
        select count(usubjid), sum (ifn(trt01pn, 1, 0)) 
        into : totalsub trimmed, : trtsub trimmed
        from adsl;
quit;
%let plasub=%eval(&totalsub-&trtsub);

proc report data=dmreport headline headskip spacing=2 split="|";
    title1 "Protocal:  &pname";
    title2 "Demographics Table";
    footnote1 "Reported by Jun Fang on &sysdate9..";  

    columns group term trt01pn0 trt01pn1 trt01pn2 pvalue;
    define group /order order=internal noprint;
    define term /display width=23 "";
    define trt01pn0 /display width=15 "Placebo|No=&plasub";
    define trt01pn1 /display width=15 "Topiramate|No=&trtsub";
    define trt01pn2 /display width=15 "Tatal|No=&totalsub";
    define pvalue /display width=15 "|Pvalue";
run;
