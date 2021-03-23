/* ***********************************************************************************************
     Name  : ADDMtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the ADDM domain Demographics table
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(ADAM,ADDM)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(adammeta)

/*add the support data to addm*/
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
proc sort data= _adsupdm;
    by usubjid;
    where randdtc not is missing;
run;

data addm(label=&addmsetlabel);
    length &addmlength;
    label &addmlabel;
    keep &addmkeep;
    merge  dm(in = indm where=(rfxstdtc not is missing))  
            _adsupdm(where=(randdtc not is missing));
    by usubjid;

    /*The format of the variable randdtc that create by function createdate() is date11.*/
    randdt = input(randdtc, E8601DA10.-L);
    educatyr = input(educatyrc, 3.);
    trtp = arm;
    if armcd = "P" then trtpn = 0;
    else if armcd = "T" then trtpn = 1;
    else trtpn = .;
    if indm;
run;
proc print data=addm;
    where usubjid in (&validsubject);
run;
