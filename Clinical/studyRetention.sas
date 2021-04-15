/* ***********************************************************************************************
     Name  : studyRetention
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: Report the study retention
*   *********************************************************************************************/
/*survival analysis*/
ods select none;
ods output ProductLimitEstimates = _survivalist  HomTests=_survpval;
proc lifetest   data = adtte;
    time aval * cnsr(1);
    strata trtp; /*trtp can be used as refer name*/
run;
ods output close;
ods select all;

/* **********************************************************************
* Image for Study retention for the topiramate and placebo groups
* ***********************************************************************/
data _survivalist;
    set _survivalist;
    if upcase(trtp)="PLACEBO" then linecolor="red";
    else linecolor="#000";
run;
data _null_; /*get pvalue for image*/
    set _survpval;
    pvalue=put(probchisq, 4.2);
    if test="Log-Rank" then call symputx('survplr', pvalue );
    else if test="Wilcoxon" then call symputx('survpwc', pvalue);
run;

%SGANNO

/*use annotation, the %SGANNO had been declared on top*/
data _insertlab;
    %sgtext(label="p = &survplr",   textcolor= "red",   textstyle="italic",     textweight="bold",
        x1=60,      y1=70);
run;

%SetGcolor(black red)

ods html style=style.gchangecolor;

ods proclabel"Study retention for the topiramate and placebo groups";
proc sgplot data=_survivalist noautolegend sganno=_insertlab;
    title "Study retention for the topiramate and placebo groups";
    step y=survival x=aval / group=trtp lineattrs=(pattern=4 thickness=2 ) name="R";
    xaxis label="Study Week" values=(1 to 84 by 7) 
        valuesdisplay=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12") offsetmin=0.05 offsetmax=0.05;
    yaxis label="Retention Rate" values=(0.5 to 1 by 0.1)
        valuesdisplay=("50" "60" "70" "80" "90" "100") offsetmin=0.05 offsetmax=0.05;
    keylegend  'R' / title='Treatment Group' location=inside position=topright;
*   inset ("p ="="&survplr") / noborder position=bottom textattrs=(color=red weight=bold);
run;
