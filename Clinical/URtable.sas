/* ***********************************************************************************************
     Name  : URtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the custom domain Urinary System Findings table
*    --------------------------------------------------------------------------------------------*
    note:  The urine test is the "endpoint" of this study. According SDTMGI3.2, those data 
              should be included in LB doamin, rather than create custom domain. However, 
              on the urine drug screen form CRF 09, the result in neg/pos only and there is 
              not Creatinine. Even in the same date, the value of creatinine in labs dataset is 
              not match the value in urine dataset. It looks like some information was missed.

              To keep the result match the original, recording urine drug data in a custom 
              domain the new version has include a urin domain.
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;

proc sort data=orilib.urine out=work._urine;
    by usubjid desending coll_dat ;
run;

proc sql ;
    select name, varnum, ifn(type="char", length, .)
        from dictionary.columns
        where libname="WORK" and memname="_URINE";
quit;

proc sql noprint;
    select quote(trim(name))
    into :ur_variable separated by ","
    from dictionary.columns
    where libname="ORILIB" and memname="URINE" and varnum between 8 and 16;
quit;
/*Some info. appeared on CRF but not include in dataset, then hardcode to those info..*/
data work._ur work._urbase(keep=usubjid urorres urblfl urdy urtest);
    merge work._urine random(keep=usubjid randdate);
    by usubjid;
    length  urorres urorresu $ 7 urblfl $1 urdy 8 ;
    keep studyid usubjid urtest urorres urorresu urblfl  visitnum urdy coll_dat ;

    if _N_=1 then call missing(urorres, urorresu, urblfl);
    if coll_dat < 0 then do;
        urdy = coll_dat;
        visitnum =floor(urdy/7) ;
        end;
    else do;
        urdy = coll_dat + 1;    
        visitnum =ceil(urdy/7) ;
        end;
    coll_dat =coll_dat + randdate;
    
    array ch(9) $ amp -- creatin;
    array cvar(9) $ _temporary_ (&ur_variable);
    do i=1 to 9;
        if anyalpha(ch(i))  then call missing(ch(i));
        /*in the urine dataset, the mampconf set to missing if the Methamphetamine negative*/
        if not missing(ch(i)) or upcase(cvar(i))="MAMPCONF" then do;
            urtest = cvar(i); 
            urorres = ch(i); 
            /*unit from CRF*/
            if upcase(cvar(i))="AMPCONF" and not missing(ch(i)) Then  urorresu= "ng/ml"; 
            if upcase(cvar(i))="MAMPCONF" and not missing(ch(i)) Then  urorresu= "ng/ml"; 
            if upcase(cvar(i))="CREATIN" and not missing(ch(i)) Then  urorresu= "mg/dL"; 
            output work._ur;
            if urdy < 0 and urdy >=-14 then do;
                if not missing(ch(i)) then do;
                    urblfl="Y";
                    output work._urbase;
                end;
            end;
        end;
    end;
run;
/*output the real urblfl*/
proc sort data=work._urbase(where=(urblfl not is missing));
    by usubjid urtest desending urdy;
run;
proc sort data=work._urbase out=work._urbase nodupkey;
    by usubjid urtest;
run;

proc sql;
    create table _ur as
    select a.studyid, a.usubjid, coll_dat, a.urorres, a.urorresu, b.urblfl, a.urdy, a.visitnum, a.urtest
    from work._ur as a left join (select * from work._urbase) as b
        on a.usubjid=b.usubjid and a.urdy=b.urdy and a.urtest=b.urtest;
quit;

proc print data=_ur;
    where usubjid in (&validsubject);
run;
/******************************************************************************************************
  Creating the SDTM domain table.
* ****************************************************************************************************/
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(SDTM, UR)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(sdtmmeta)

options varlenchk=nowarn;
data ur(label=&ursetlabel);
    length &urlength;
    label &urlabel;
    set  _ur;
    keep &urkeep;
    
    call missing(urseq); 
    domain = "UR";
    urcat = "URINALYSIS";
    if not missing(urorres) then do;
        urstresu = put(urorresu, unit.);
        urstresn = input(urorres, 8.);
        if urtest="MAMPCONF" then urstresc = put(urstresn, urstresm.);
        else urstresc = put(urstresn, urstresc.);
    end;
    else if urtest="MAMPCONF" then urstresc = put(urstresn, urstresm.);
    urtestcd = put(urtest, urtestcd.);
    urtest = put(urtest, urtest.);
    urdtc = put(coll_dat, E8601DA10.-L);
    visit =  put(visitnum,  visit.);
run;
options varlenchk=warn;

proc print data=ur;
    where usubjid in (&validsubject);
run;

/* **************************************************************************************
  Sorting the dataset according to the keysequence metadata specified sort order 
    for a given dataset.
  If there is a __seq variable in a dataset, then create the __seq value for it
* ***************************************************************************************/
%SortOrder(dataset=UR)
/******************************************************************************************************
  Reduce the size of dataset by reducing the length of char type variables.
* ****************************************************************************************************/
%ReLenStd(SDTM,datasets=UR,minlen=1)

