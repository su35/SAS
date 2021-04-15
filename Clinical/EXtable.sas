/* ***********************************************************************************************
     Name  : EXtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the EX domain Exposure table
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;
/*data glancing*/
proc print data=orilib.dose;
    where usubjid in(&validsubject);
run;
/*find the illegal value*/
%LegVal(orilib.dose, t25_1-t25_7 t100_1- t100_7);

/*drop the unrelated variables*/
proc sort data= orilib.dose (drop=r:  c: a: f: D25_1-D25_7 D100_1-D100_7 ) 
                 out=work._dose;
    by usubjid visid;
run;
/* Data cleaning and SDTM mapping. */
data _ex ; 
    merge work._dose end=eof   random (keep=treat usubjid randdate) ;
    by usubjid;

    retain exdose exstdy  _dose  startdate  exendy enddate;
    array dos (2,7) t25_1 - t25_7 t100_1-t100_7;
    array datearr(7) date1-date7;
    keep studyid  usubjid exstdy exendy exdose  startdate enddate treat ;

    if _N_=1 then call missing(valid3, valid13);
    if first.usubjid then do;
        call missing(exdose,  exstdy);
    end;

    do i=1 to 7;
        /*sum the 25mg and 100mg tablet as total.
        * set the missing value to 0 to make the code easy to understand*/
        if anyalpha(dos(1,i)) or missing(dos(1,i)) then dos(1,i) ="0" ;
        if anyalpha(dos(2,i))  or missing(dos(2,i)) then dos(2,i) ="0" ;
        /*get total dose per day*/
        _dose= sum(25*input(dos(1,i), 3.), 100*input(dos(2,i), 3.));

        if missing(exstdy)  then do; /*find the first Exposure day */
            /*For SDTM the first day is day1*/
            if not missing(datearr(i)) then do;
                /*set start date*/
                exstdy = datearr(i) +1;
                startdate =  datearr(i) + randdate;
                /*initialize enddate to avoid the null date in last week*/
                exendy =  datearr(i) +1;
                enddate = datearr(i)  + randdate;
            end;
            exdose = _dose; 
        end;
        else if exdose ne _dose then do;/*dose changed*/
            output; 
            if not missing(datearr(i)) then do;
                exstdy = datearr(i) +1 ;
                startdate =  datearr(i) + randdate;
                /*initialize enddate for dose changing*/
                exendy =  datearr(i) +1;
                enddate = datearr(i)  + randdate;
            end;
            exdose = _dose;
        end;
        else if not missing(datearr(i)) then do;/*update end date*/
                exendy =  datearr(i)+1;
                enddate = datearr(i)  + randdate;
        end;

        /*is the last value but dose no change*/
        if (last.usubjid or eof) and i=7 and _dose >0 then do;
            exendy =  datearr(i) +1;
            enddate = datearr(i) + randdate;
            output;
        end; 
    end;
run;

title "EX data"; 
proc print data=_ex;  
    where usubjid in (&validsubject);
run;
title "Dose data"; 
proc print data=work._dose; 
    where usubjid in (&validsubject);
run;
title;

/******************************************************************************************************
  Creating the SDTM domain table.
* ****************************************************************************************************/
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(SDTM, EX)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(sdtmmeta)

%let unit=mg;
%let form=TABLET;
options varlenchk=nowarn;
data ex(label=&exsetlabel);
    length &exlength;
    label &exlabel;
    set  _ex;
    keep &exkeep;
 
    call missing(exseq); 
    /*hardcord for the variables that have not value in dataset*/
    domain="EX";
    exdosu = "&unit";
    exdosfrm= "&form";
    exstdtc = put(startdate, E8601DA10.-L);
    exendtc = put(enddate, E8601DA10.-L);
    extrt = treat;
run; 
options varlenchk=warn;

proc print data=ex ;
    where usubjid in (&validsubject);
run;

/* **************************************************************************************
  Sorting the dataset according to the keysequence metadata specified sort order 
    for a given dataset.
  If there is a __seq variable in a dataset, then create the __seq value for it
* ***************************************************************************************/
%SortOrder(dataset=EX)
/******************************************************************************************************
  Reduce the size of dataset by reducing the length of char type variables.
* ****************************************************************************************************/
%ReLenStd(SDTM,datasets=EX,minlen=1)
