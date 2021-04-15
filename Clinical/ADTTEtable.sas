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

/*filter out the subjects that were randomized, but no exposure*/
proc sort data=adsl out=_adsl;
    by usubjid;
    where saffl="Y";
run;

/*fetch the final status*/
%let cond=STUDY PARTICIPATION;
proc sort data=ds out=_dsc(keep=usubjid dsdecod) ;
    by usubjid;
    where dsscat="&cond" ;
run;

/*time to event dataset*/
data adtte(label=&adttesetlabel);
    length &adttelength;
    label &adttelabel;
    keep &adttekeep;
    merge _adsl(rename=(arm=trtp  trt01pn = trtpn)) _dsc ;
    by usubjid;

    aval=(trtedt-trtsdt+1);
    cnsr=ifn(dsdecod="COMPLETED", 1, 0);
    if dsdecod="COMPLETED" then call missing(evntdesc);
    else evntdesc=dsdecod;
    param="Time to Discontinued";
    paramcd="DISCONTD";
run;
proc print data=adtte;
    where usubjid in (&validsubject);
run;
