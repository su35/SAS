/* ***********************************************************************************************
     Name  : ADSLtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the ADSL domain Subject Level Analysis Dataset table
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(ADAM,ADSL)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(adammeta)

/*fetch the final status*/
proc sort data=ds out=_dsc(keep=usubjid dsdecod dsstdtc rename=(dsdecod=EOSSTT dsstdtc=EOSDTc )) ;
    by usubjid;
    where dsscat="STUDY PARTICIPATION" ;
run;

data adsl(label=&adslsetlabel);
    length &adsllength;
    label &adsllabel;
    keep &adslkeep;
    merge  _dsc  dm _adsupdm;
    by usubjid;

    if _N_=1 then call missing(ittfl,complfl);

    if randdtc ne "" then do;
        trt01p = arm;
        if armcd = "P" then trt01pn = 0;
        else if armcd = "T" then trt01pn = 1;
        randdt = input(randdtc, E8601DA10.-L);
        trtsdt = input(rfxstdtc,E8601DA10.-L);
        trtedt = input(rfxendtc,E8601DA10.-L);
        if eosstt="COMPLETED" then complfl ="Y";
        else do;
            eosstt="DISCONTINUED";
            complfl ="N";
        end;
        output;
    end;
run;
proc print data=adsl;
    where usubjid in (&validsubject);
run;
