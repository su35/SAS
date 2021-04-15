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
%let cond=STUDY PARTICIPATION;
proc sort data=ds out=_dsc(keep=usubjid dsdecod dsstdtc rename=(dsdecod=EOSSTT dsstdtc=EOSDTc )) ;
    by usubjid;
    where dsscat="&cond" ;
run;
/******************************************************************************************************
  Since some data are unavailable, simply setting:
    actually received a study treatment =>safety population set
    effecience evaluation started at week 6, so the exposure day over 35 =>full analysis set
    the exposure day over 75 (80% of effecience evaluation window) =>per protocol population set
* ****************************************************************************************************/
%let deffas=%eval(5*7);
%let defppp=%sysevalf(5*7+7*7*0.8);
proc sql;
    create table _pfl as
    select distinct usubjid, max(exendy) as md, "Y" as saffl,
                ifc(calculated md>=&defppp, "Y", "N") as pprotfl,
                ifc(calculated md>=&deffas, "Y", "N") as fasfl
    from ex
    group by usubjid;
quit;
/*add the suppdm data*/
proc sort data= suppdm;
    by usubjid qnam;
run;
proc transpose data =suppdm out= _adsupdm(drop=_name_  _label_
                    rename=(randdate = randdtc    educatyr = educatyrc));
    var qval;
    by usubjid;
    id qnam;
    IDLABEL qlabel;
run;

/*Including the subjects who was randomized only.*/
proc sort data= _adsupdm;
    by usubjid;
    where randdtc not is missing;
run;

options varlenchk=nowarn;
data adsl(label=&adslsetlabel);
    length &adsllength;
    label &adsllabel;
    keep &adslkeep;
    merge  _pfl  dm _adsupdm _dsc;
    by usubjid;
    format randdt trtsdt trtedt E8601DA10.;

    if not missing(randdtc);
        trt01p = arm;
        if armcd = "P" then trt01pn = 0;
        else if armcd = "T" then trt01pn = 1;
        randdt = input(randdtc, E8601DA10.-L);
        trtsdt = input(rfxstdtc,E8601DA10.-L);
        trtedt = input(rfxendtc,E8601DA10.-L);
        educatyr=input(educatyrc, 8.);
run;
options varlenchk=warn;

proc print data=adsl;
    where usubjid in (&validsubject);
run;
