/* ***********************************************************************************************
     Name  : Result.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: Analysis and output the result
* ***********************************************************************************************/
/*primary outcome*/
ods output  GEEEmpPEst =_gee_pvalue FitPanel=_gee_fit;
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
    create table _gee_means as 
    select _plotby as trtp, _xcont1 as weeks, _predicted*100 as means, floor(_xcont1) as week, 
                mean(_predicted)*100  as week_mean
        from _gee_fit
        group by trtp, calculated week;
quit;

%SGANNO

/* ***********************************************************************
* Generalized estimating equations (GEE) result
* ************************************************************************/
data _null_; /*get pvalue for image*/
    set _gee_pvalue;
    where parm="AVISITN*TRTP" and ProbZ not is missing;
     call symputx('geepval', put(probz, 4.2) );
run;
data _insertlab;
    %sgtext(label="p = &geepval", textcolor= "black",   textstyle="italic", textweight="bold",
        x1=50,  y1=60   );
run;

ods proclabel "Precentage of Subjects with Negative Methamphetamine Use Week";
proc sgplot data=_gee_means noborder sganno=_insertlab;
    scatter y=week_mean x=week/ group=trtp;
    reg y=means x=weeks/ group=trtp  nomarkers;
    xaxis label="Study Week" values=(6 to 12 by 1) offsetmin=0.05 offsetmax=0.05;
    yaxis label="Precentage of Subjects with Negative Methamphetamine Use Week" 
            values=(0 to 100 by 10) offsetmin=0.05 offsetmax=0.05;
run;

/* **********************************************************************************************
  The percentage of subjects with a negative methamphetamine use week in study weeks
  grope by basegr1 (the baseline is positive)
* **********************************************************************************************/
proc sort data=adefp;
    by basegr1 usubjid;
run;
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

data base_weekval2;
    length ppcent tpcent 6.2;
    retain ppcent tpcent;
    set base_weekval;
    keep basegr1 trtp avisitn aval ppcent tpcent ;
    where aval=0 and avisitn not is missing;

    if basegr1 ="N" then ppcent=rowpercent;
    if basegr1="Y";
    tpcent=rowpercent;
run;
/* *********************************************************************************************
* The percentage of subjects with a negative methamphetamine use week in study weeks
* **********************************************************************************************/
data _insertlab;
    %sgtext(label="Negative",   textstyle="italic", textweight="bold",  x1=20,  y1=75)
    %sgtext(label="Positive",textstyle="italic",textweight="bold",x1=20, y1=45)
run;

*ods graphics on /height=8in width =8in;
proc sgplot data=base_weekval  noborder sganno=_insertlab;
    scatter y=ppcent x=avisitn /group=trtp markerattrs=(symbol=circlefilled size=10px) ;
    series y=ppcent x=avisitn /group=trtp  lineattrs=(pattern =4 thickness=2) name="BP";
    scatter y=tpcent x=avisitn /group=trtp markerattrs=(symbol=circlefilled size=10px) ;
    series y=tpcent x=avisitn/group=trtp lineattrs=(pattern =1 thickness=2)  name="BT";
    xaxis label="Study Week" values=(6 to 12 by 1) offsetmin=0.05 offsetmax=0.05;
    yaxis label="Precentage of Subjects with Negative Methamphetamine Use Week" 
            values=(0 to 100 by 10) offsetmin=0.05 offsetmax=0.05;
run;

%cleanLib()
