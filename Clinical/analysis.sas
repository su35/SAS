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

/*********************************
* Prepare analysis dataset
**********************************/
proc sql;
    create table anur as 
        select a.usubjid, trtp, trtpn, a.avisitn, (trtedt-trtsdt+1) as enday ,
                case when calculated enday <84 then  calculated enday  else 84 end as lastday,
                ceil((calculated lastday)/7) as lastweek, a.ady,  weekval, base,
                case when sum(crit1fn) =0 then 0 else 1 end as f_value, 
                case when calculated lastday< 84 then 1 else 0 end as drop_censor
            from adur as a, 
                (select usubjid, avisitn, ady, case when sum(crit1fn) = 0 then 0 else 1 end as weekval
                    from adur 
                    group by usubjid, avisitn) as b,
                    adsl as d
            where a.usubjid=b.usubjid and a.avisitn=b.avisitn and a.usubjid=d.usubjid
                    and a.ady=b.ady and a.avisitn between 1 and 12
            group by a.usubjid
            order by base, a.usubjid, a.ady;
quit;

/*survival analysis*/
proc sort data = anur out = _survival(keep=trtp lastday drop_censor) nodupkey;
    by usubjid;
run;
ods select none;
ods output ProductLimitEstimates = _survivalist  HomTests=_survpval;
proc lifetest   data = _survival;
    time lastday * drop_censor(0);
    strata trtp; /*trtp can be used as refer name*/
run;
ods output close;
ods select all;

/*************************************************
* Prepare analysis dataset for main study week
*************************************************/
proc sort data= anur  
            out=_anmain (keep=usubjid trtpn trtp avisitn weekval base drop_censor);
    where avisitn between 6 and 12;
    by usubjid;
run;

proc sort data=_anmain nodup;
    by base;
run;


/* *********************************************************************************************
* The percentage of subjects with a negative methamphetamine use week in study weeks
* **********************************************************************************************/
ods select none;
ods output crosstabfreqs=_base_weekval;
proc freq data=_anmain;
    by base;
    table trtp*avisitn*weekval /cmh missing;
    output out=_pvalue_bw cmh;
run;
ods output close;
ods select all;

proc sort data=_base_weekval;
    by trtp avisitn base;
run;

data _base_weekval;
    length ppcent tpcent 6.2;
    retain ppcent tpcent;
    set _base_weekval;
    keep base trtp avisitn weekval ppcent tpcent ;
    where weekval=0 and avisitn not is missing;
    if base =0 then ppcent=rowpercent;
    if base=1;
    tpcent=rowpercent;
run;

ods output  GEEEmpPEst =_gee_pvalue FitPanel=_gee_fit;
ods graphics on;
proc genmod data=_anmain;
    class usubjid trtp ;
    model weekval=trtp avisitn trtp*avisitn / dist=bin;
    repeated subject=usubjid ;
    effectplot fit (plotby=trtp x=avisitn);
*   lsmeans armcd*weeks/means ;
run;
ods graphics off;
ods output close;

proc sql;
    create table _gee_means as 
    select _plotby as trtp, _xcont1 as weeks, _predicted*100 as means, floor(_xcont1) as week, 
                mean(_predicted)*100  as week_mean
        from _gee_fit
        group by trtp, calculated week;
quit;
