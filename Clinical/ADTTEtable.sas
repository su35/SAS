/* ***********************************************************************************************
     Name  : ADTTEtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the ADTTE Study Retention Analysis Dataset table
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(ADAM,ADTTE)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(adammeta)

/*the last day recording in ur test does not match the recording in complete status recording
some subjedts were marked dropped, however, after several weeks, their ur test appeared again
Here, using complete status data*/ 
proc sql;
    create table _adur as
        select u.studyid, u.usubjid, d.age as age, d.sex as sex, d.race as race, d.arm as trtp, u.urseq, 
                d.trt01pn as trtpn, urstresn as aval, urstresc as avalc, visit as avisit, (trtedt-trtsdt+1) as aendy,
                visitnum as avisitn, input(urdtc, E8601DA10.-L) as adt ,  urdy as ady, urblfl as ablfl,
                "Week Methamphetamine Use" as crit1,
                case when max(urstresn)<78 then "N" else "Y" end as crit1fl, 
                case when calculated crit1fl = "Y" then 1 else 0 end as crit1fn length=3,
                case when not missing(urblfl) then urstresn else . end as base,urtestcd,
                case when complfl="Y" then 1 else 0 end as cnsr,
                ifc(complfl="N", eosstt, "") as evntdesc, BASEGR1
        from ur as u, adsl as d, (select usubjid, case when urstresn>=78 then "Y" else "N" end as BASEGR1
                                             from ur where urblfl = "Y" and urtestcd = "METHAMPH") as b 
        where u.usubjid = d.usubjid and u.usubjid=b.usubjid
                and  visitnum < 13 and urtestcd = "METHAMPH"
        group by u.usubjid, visitnum;
quit;
/*time to event dataset*/
proc sql;
    create table adtte as 
    select distinct studyid, usubjid,  trtp, trtpn, aendy as aval, cnsr, evntdesc
    from _adur;
quit;
data adtte(label=&adttesetlabel);
    length &adttelength;
    label &adttelabel;
    keep &adttekeep;
    set adtte ;

    param="Time to Discontinued";
    paramcd="DISCONTD";
run;
proc print data=adtte;
    where usubjid in (&validsubject);
run;
