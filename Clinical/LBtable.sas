/* ***********************************************************************************************
     Name  : LBtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the LB domain Laboratory Test Results table
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;

/*The values of variables that name end with x and MM are comment and would be dropped*/
data _null_;
    length droplist $1000;
    retain droplist; 
    set sashelp.vcolumn end=eof;
    where libname="ORILIB" and memname="LABS";
    if find(name,"x",-33,"i") or find(name,"mm",-33,"i") then  
                droplist=catx(" ",droplist, name);
    if eof then call symputx("orilbdrop", droplist);
run;
proc sort data=orilib.labs(drop=&orilbdrop) out=work._labs;
    by usubjid;
run;

proc sql ;
    select name, varnum, ifn(type="char", length, .)
        from dictionary.columns
        where libname="WORK" and memname="_LABS";
quit;
/******************************************************************************************************
  Data cleaning and SDTM mapping.
* ****************************************************************************************************/
/*Excepting the "urcolor" and "urapp", other lab variables are appear as a pair. 
  One store the test value, another is stored the evaluated result. 
  From variable number 9 to 28, total 10, are hematology assay. 
  From 29 to 58, total 15, are chemistry assay. 
  From 59 to 78, total 11("urcolor" and "urapp" has one variable only), are urinalysis. 
  Storing them in macro variables respectively. */
data _null_;
    length chvarlist evalname $500 singleval $20;
    retain chvarlist evalname singleval;
    set sashelp.vcolumn end=eof;
    where libname="WORK" and memname="_LABS";
    if 8< varnum <=78 then do;
        if varnum=59 or varnum=60 then do;
            singleval=catx(", ",singleval, quote(trim(name)));
        end;
        else do;
            if mod(_N_, 2) = 1 then chvarlist=catx(", ",chvarlist, quote(trim(name)));
            if mod(_N_, 2) = 0 then evalname=catx(" ",evalname, name);
        end;
    end;
    if eof then do;
        call symputx("chvarlist", chvarlist);
        call symputx("evalname", evalname);
        call symputx("singleval", singleval);
    end;
run;
options noquotelenmax;
/*Some info. appeared on CRF but not include in dataset, then hardcode to those info..*/
data _lb;
    length lbtestcd lbtest lborres lbstresc $8 lbcat $ 10 lborresu $5 lbnrind $ 3;
    merge work._labs(in=inlab)  random(keep=usubjid randdate);
    by usubjid;

    if inlab then do;
        if visid = 0 then lbblfL="Y"; /*test in week0 are baseline*/
        visitnum=visid;
        if visdate < 0 then lbdy = visdate;
        else lbdy = visdate + 1;
        if not missing(lbdy) then col_date = sum(randdate, lbdy);
        /* According to the notes of lbnrind in SDTMIG v3.2: "Should not be used to indicate 
            clinical significance".
            The original value "3" of the lbnrind was classed to "2"*/
        array eval (*) $ &evalname;
        do i=1 to dim(eval);
            if eval(i) in ('1','2','3') then do;
                if eval(i) ="3" then eval(i)="2";
            end;
            else call missing(eval(i));
        end;

        /*Grouping the test value and evaluate value by each assay, except the 26th elements 
           in which the variables representing the "urcolor" and "urapp"*/
        array chvars(34,2) $ wbc--hemgeval specgrav--leukeval;
        array varlist(34) $ _temporary_  (&chvarlist);
        array singlevars(2) $ urcolor urapp;
        array singleval(2) $ _temporary_  (&singleval);

        do i=1 to 34;
            if i<11 then lbcat="HEMATOLOGY";
            else if i<26 then lbcat="CHEMISTRY";
            else lbcat="URINALYSIS";

            if not missing(chvars(i,1)) then do;
                lbtestcd = varlist(i);
                lbtest = varlist(i);
                lborres = chvars(i,1);
                lbstresc = chvars(i,1);
                lbnrind = chvars(i,2); 
                if not (prxmatch('/[a-z]/i', chvars(i,1))) then lbstresn = input(chvars(i,1), 8.2);
                else call missing(lbstresn);
                select (lbtestcd);
                    when("HEMATOCR","NEUTROPH","LYMPHOCY","MONOCYTE","EOSINOPH","BASOPHIL","HEMGLBA1") lborresu= "%";
                    when("SODIUM","POTASSIU","CHLORIDE","BICARB") lborresu= "mEq/L";
                    when("HEMOGLOB","ALBUMIN") lborresu= "g/dL";
                    when("BUN","CREATINI","GLUCOSE","TOTBILI","DIRBILI") lborresu= "mg/dL";
                    when("WBC", "PLATELET") lborresu= "K/mm3";
                    when("RBC") lborresu= "M/mm3";
                    when("ALKPHOS") lborresu= "ALP";
                    when("GGT","SGPTALT","SGOTAST") lborresu= "U/L";
                    otherwise lborresu= "";
                end;
                output;
            end;
        end;
        do i=1 to 2;
            lbcat="URINALYSIS";
            lbtestcd = singleval(i);
            lbtest = singleval(i);
            lborres = singlevars(i);
            lbstresc = singlevars(i);
            output;
        end;
    end;
run;
options quotelenmax;
proc print data=_lb;
    where usubjid in (&validsubject);
run;

/******************************************************************************************************
  Creating the SDTM domain table.
* ****************************************************************************************************/
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(SDTM, LB)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(sdtmmeta)
options varlenchk=nowarn;
data lb(label=&lbsetlabel);
    length &lblength;
    label &lblabel;
    set  _lb;
    keep &lbkeep;
 
    call missing(lbseq, lbornrlo, lbornrhi,lbstnrlo,lbstnrhi ); 
    domain = "LB";
    lbtestcd = put(lbtestcd, lbtestcd.);
    lbtest = put(lbtest, lbtest.);
    lbstresu = put(lborresu, unit.);
    lbdtc = put(col_date, E8601DA10.-L);
    visit = put(visitnum,visit.);
    lbnrind = put(lbnrind, lbnrind.); 
    if upcase(lbtestcd) = "COLOR"   then lbstresc = put(lbstresc,  urcolor.);
    else if upcase(lbtestcd) = "APPEAR"  then lbstresc = put(lbstresc,  urapp.);
    else if upcase(lbcat) = "URINALYSIS" and  upcase(lbtestcd) not in ("PH", "SPGRAV")
    then lbstresc = put(lbstresc,  lbstresc.);
run;
options varlenchk=warn;
proc print data=lb;
    where usubjid in (&validsubject);
run;

/* **************************************************************************************
  Sorting the dataset according to the keysequence metadata specified sort order 
    for a given dataset.
  If there is a __seq variable in a dataset, then create the __seq value for it
* ***************************************************************************************/
%SortOrder(dataset=LB)
/******************************************************************************************************
  Reduce the size of dataset by reducing the length of char type variables.
* ****************************************************************************************************/
%ReLenStd(SDTM,datasets=LB,minlen=1)
