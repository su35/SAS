/* ***********************************************************************************************
     Name  : DStable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the DS domain Disposition table
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;

/*Get the end status*/
proc sort data=orilib.term(keep=usubjid status) out=work._term;
    by usubjid;
run;
/*find the illegal value*/
%LegVal(work._term, status);
/*Get the last day of exposure*/
proc sql;
    create table work._dsex as
    select usubjid, max(enddate) as enddate
    from _ex
    group by usubjid
    order by usubjid;
quit;

/* SDTM mapping. */
data _ds;
    length dsterm dsdecod $10 dscat dsscat $20;
    merge random (in=inrand) work._term work._dsex _dm;
    by usubjid;
    keep studyid siteid subjid usubjid dsterm dsdecod dscat dsscat dsdy dsstdy;

    if inrand;
    /*output the random*/
    dsterm="0";
    dsdecod="0";
    dscat="3";
    dsdy=randdate;
    dsstdy=1;
    output;

    /*output the final status*/
    dsterm=status;
    select (status);
        when("1") dsdecod=status;
        when("4","7") dsdecod="2";
        when("5","6") dsdecod="3";
        when("2","3") dsdecod="4";
        when("9") dsdecod="5";
        when("12") dsdecod="6";
        when("10") dsdecod="7";
        when("13") dsdecod="8";
        when("8","11") dsdecod="9";
        otherwise dsdecod="";
    end;
    
    dscat="1";
    dsscat="1";
    dsdy=enddate ;
    if not missing(first_t_day) then dsstdy=last_t_day - first_t_day +1;
    output;
run;
proc print data=_ds;
    where usubjid in (&validsubject);
run;

/******************************************************************************************************
  Creating the SDTM domain table.
* ****************************************************************************************************/
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(SDTM, DS)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(sdtmmeta)

options varlenchk=nowarn;
data ds(label=&dssetlabel);
    length &dslength;
    label &dslabel;
    set  _ds;
    keep &dskeep;
    
    call missing(dsseq); 
    domain = "DS";
    if dsterm="0" then dsdecod=put(dsdecod, protmlst.);
    else dsdecod=put(dsdecod, ncomplt.);
    dsterm=put(dsterm, status.);
    dscat=put(dscat, dscat.);
    if not missing(dsscat) then dsscat=put(dsscat, dsscat.);
    dsstdtc=put(dsdy, E8601DA10.-L);
run;
options varlenchk=warn;

proc print data=ds;
    where usubjid in (&validsubject);
run;

/* **************************************************************************************
  Sorting the dataset according to the keysequence metadata specified sort order 
    for a given dataset.
  If there is a __seq variable in a dataset, then create the __seq value for it
* ***************************************************************************************/
%SortOrder(dataset=DS)
/******************************************************************************************************
  Reduce the size of dataset by reducing the length of char type variables.
* ****************************************************************************************************/
%ReLenStd(SDTM,datasets=DS,minlen=1)
