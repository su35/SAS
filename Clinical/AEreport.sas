/* ***********************************************************************************************
     Name  : AEreport.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: List the Adverse Events data and statistical result.
*   *********************************************************************************************/
/* *******************************************************************************
* "blankno" define the indentation of sub-term.  for listing output, using the number of blanks 
* for HTML output, using a "&#160;", and use javascript and CSS file to control the indentation
* **************************************************************************************/
%let blankno=&#160%str(;) ;

/* ======== Create AE Summary Table, Count AE on Aesoc ======== */
%AEReportSet(adae, outdn=aereport)

 /* put the number of subjects in each trt group into the global macro and remove blank */
proc sql noprint; 
        select cats(count(usubjid)), cats(sum (ifn(trtpn, 1, 0))) 
        into : totalsub, : trtsub
        from addm;
quit;
%let plasub=%eval(&totalsub-&trtsub);

ods proclabel "Adverse Event Report";
proc report data=aereport headline headskip spacing=5 split="|";
    title1 "Protocal:  &pname";
    title2 "Adverse Event Table";
    footnote1 "Reported by Jun Fang on &sysdate9..";  

    columns ( group term trtan0 trtan1 trtan2 );
    define group /order order=internal noprint;
    define term /display width=23 "";
    define trtan0 /display width=15 "Placebo|No=&plasub";
    define trtan1 /display width=15 "Topiramate|No=&trtsub";
    define trtan2 /display width=15 "Tatal|No=&totalsub";
run;
