/* ***********************************************************************************************
     Name  : ADAEtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the ADAE domain Adverse Events Analysis Datasets table
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(ADAM,ADAE)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(adammeta)

data adae(label=&adaesetlabel);
    length &adaelength;
    label &adaelabel;
    keep &adaekeep;
    /*subject in adsl may not in ae, subject in ae may screen failure*/
    merge ae ( in=inae rename= (aestdy = astdy  aeendy = aendy))  
            adsl(in=inad keep= usubjid trt01p trt01pn);
    by usubjid;

    trta = trt01p;
    trtan = trt01pn;
    if not missing(aestdtc) then astdt = input(aestdtc, E8601DA10.-L);
    else astdt=.;
    if not missing(aeendtc) then aendt = input(aeendtc, E8601DA10.-L);
    else aendt=.;
    if inae and inad;
run;
proc print data=adae;
    where usubjid in (&validsubject);
run;
