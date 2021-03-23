/* ***********************************************************************************************
     Name  : ADEFPtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the ADEFP Efficacy Analysis Dataset table
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(ADAM,ADEFP)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(adammeta)

/*primary outcome dataset*/
proc sql;
    create table adefp as 
    select distinct studyid, usubjid, trtp, trtpn, avisit, avisitn, sum(crit1fn) as aval, basegr1
    from _adur
    where avisitn between 6 and 12
    group by usubjid, avisitn;
quit;

data adefp(label=&adefpsetlabel);
    length &adefplength;
    label &adefplabel;
    keep &adefpkeep;
    set adefp;

    if aval>=78 then aval=1;
    else aval=0;
    param = "Qualitative Urine Drug Screen for Methamphetamine is Positive";
    paramcd = "URMEAMP" ;
run;
proc sort data=adefp;
    by basegr1;
run;
proc print data=adefp(obs=10);
run;
