/* *******************************************************************************
* "blankno" define the indentation of sub-term.  for listing output, using the number of blanks 
* for HTML output, using a "&#160;", and use javascript and CSS file to control the indentation
* **************************************************************************************/
%let blankno=&#160%str(;) ;

/* =========== Create Demographic Summary Table =========== */
%DMSummarySet(varlist=age sex race educatyr employ maritals, class=trtp trtpn, 
        analylist=n mean median min max)

/* ======== Create AE Summary Table, Count AE on Aesoc ======== */
%AESummarySet(adae)

/*survival analysis*/
ods select none;
ods output ProductLimitEstimates = _survivalist  HomTests=_survpval;
proc lifetest   data = adtte;
    time aval * cnsr(1);
    strata trtp; /*trtp can be used as refer name*/
run;
ods output close;
ods select all;

/* **********************************************************************************************
* The percentage of subjects with a negative methamphetamine use week in study weeks
* grope by basegr1
* **********************************************************************************************/
ods select none;
ods output crosstabfreqs=base_weekval;
proc freq data=adefp;
    by basegr1;
    table trtp*avisitn*aval / missing;
run;
ods output close;
ods select all;

proc sort data=base_weekval;
    by trtp avisitn basegr1;
run;

data base_weekval;
    length ppcent tpcent 6.2;
    retain ppcent tpcent;
    set base_weekval;
    keep basegr1 trtp avisitn aval ppcent tpcent ;
    where aval=0 and avisitn not is missing;

    if basegr1 ="N" then ppcent=rowpercent;
    if basegr1="Y";
    tpcent=rowpercent;
run;
/*primary outcome*/
ods output  GEEEmpPEst =gee_pvalue FitPanel=_gee_fit;
ods graphics on;
proc genmod data=adefp;
    class usubjid trtp ;
    model aval =trtp avisitn trtp*avisitn / dist=bin;
    repeated subject=usubjid;
    effectplot fit (plotby=trtp x=avisitn);
*   lsmeans armcd*weeks/means ;
run;
ods graphics off;
ods output close;

proc sql;
    create table gee_means as 
    select _plotby as trtp, _xcont1 as weeks, _predicted*100 as means, floor(_xcont1) as week, 
                mean(_predicted)*100  as week_mean
        from _gee_fit
        group by trtp, calculated week;
quit;
