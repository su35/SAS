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

/******************************************************************************************************
  The primary outcome assessment was negative "methamphetamine use weeks" during study
   weeks 6–12. 
  The positive samples were methamphetamine quantification of ≥78 ng/ml.
  A positive use week was any week in which ≥1 methamphetamine was positive.
  The basegr1 is the flag that whether the baseline is positive.
* ****************************************************************************************************/
%let assay=METHAMPH;
%let posival=78;
%let begin=6;
%let end=12;
proc sql noprint;
    create table _adefp as
        select u.studyid, u.usubjid, d.arm as trtp, d.trt01pn as trtpn, u.visit as avisit, u.visitnum as avisitn, 
                ifn(u.urstresc="NEGATIVE" or max(u.urstresn)<&posival, 0, 1) as crit1fn length=3, 
                urstresc as avalc, BASEGR1
        from ur as u, adsl as d, (select usubjid, ifc(urstresn>=&posival, "Y", "N") as BASEGR1
                                             from ur where urblfl = "Y" and urtestcd = "&assay") as b 
    where u.usubjid = d.usubjid and u.usubjid=b.usubjid
            and  visitnum <= &end and urtestcd = "&assay" 
            and u.visitnum between &begin and &end 
    group by u.usubjid, visitnum;

    /*fetch the character value*/
    select distinct ifc(crit1fn=0, avalc, ""), ifc(crit1fn>0, avalc, "")
    into :charval0 separated by "", :charval1 separated by ""
    from _adefp;

    /*merge the week value*/
    create table adefp as 
    select distinct studyid, usubjid, trtp, trtpn, avisit, avisitn, max(crit1fn) as aval, basegr1
    from _adefp
    group by usubjid, avisitn;
quit;
/*primary outcome dataset, the aval is the result of whether the Methamphetamine is positive*/
%let param=Qualitative Urine Drug Screen for Methamphetamine is Positive;
%let  paramcd=URMEAMP;

options varlenchk=nowarn;
data adefp(label=&adefpsetlabel);
    length &adefplength;
    label &adefplabel;
    keep &adefpkeep;
    set adefp;

    if aval=0 then avalc="&charval0";
    else avalc="&charval1";
    param = "&param";
    paramcd = "&paramcd" ;
run;
options varlenchk=warn;

proc sort data=adefp;
    by basegr1;
run;

proc print data=_adefp;
    where usubjid in (&validsubject);
run;
