/* ***********************************************************************************************
     Name  : DMtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose      : Create the DM domain Demographics table
*   *********************************************************************************************/
/*fetch the selected subjects into macro variable*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;

/******************************************************************************************************
  The major dm data come from orilib.enrl. 
  Treatment and Date of first/end study treatment come from _ex
  There are mult-condition of end, the date of end of participation would be the max of 
    registed form completed, follow-up data, end of study status
* ****************************************************************************************************/
proc sql;
    create table _dm as
    select e.studyid as studyid, e.usubjid as usubjid, put(e.subjid,8.-L) as subjid,/*convert num to char*/
             ex.startdate as first_t_day, ex.enddate as last_t_day, 
             (e.visdate + r.randdate) as infoday, /*transform the visdate back to real date*/
             sum(r.randdate, max(f.visdate, f.contdate, t.visdate, e.visdate)) as endday,
             coalescec(t.deathdt, f.dieddate) as dthdtc, 
             put(e.siteid,8.-L) as siteid, e.birthday as age, e.gender as sex, 
             case when white ="1" then "1"   
                     when  black eq "1" then "2"  
                     when asian ="1" then "3"
                     when hawaiian = "1" then "4" 
                     when  indian= "1" then "5" 
                     else "" end as race, 
             coalescec(r.treat, ifc(missing(e.reasdecl), "", "2"), ifc(missing(e.reasinel), "", "3") ) as arm,
             ifn( e.visdate < 0, e.visdate, (e.visdate +1)) as dmdy
    from orilib.enrl as e left join 
            random as r on e.usubjid=r.usubjid left join
            (select distinct treat, usubjid, min(startdate) as startdate,
                max(enddate) as enddate from _ex group by usubjid) as ex 
            on e.usubjid=ex.usubjid left join 
            orilib.term as t on e.usubjid=t.usubjid left join 
            orilib.fup as f on e.usubjid=f.usubjid 
    order by usubjid;
quit;

proc print data=_dm;
    where usubjid in (&validsubject);
run;

/*finding the illegal values of the variables that would be included in suppdm*/
%LegVal(orilib.enrl, educatyr employ30 maritals eligible);

proc sort data= orilib.enrl(keep=studyid usubjid educatyr maritals employ30  eligible)
                    out=work._enrl;
    by usubjid ;
run;

/* *********  declare the libref and refer the dictionaris as the datasets  *******************/
libname dict xlsx "&pdir.documents\CSP1025-Dictionary.xlsx";
libname sdtm xlsx "&pdir.SDTM_METADATA.xlsx";

data _null_;
    length varname varori $ 100 varlabel varlen $ 500; 
    dsid=open('dict.enrl(where=(table_name_ in 
                            ("EDUCATYR", "MARITALS", "EMPLOY30", "ELIGIBLE", "RANDDATE")))');
    do i=1 to 5;
        rc=fetch(dsid);
        varname=catx(" ", varname, quote(trim(getvarc(dsid, 1))));
        varlabel=catx("|", varlabel, getvarc(dsid, 5));
    end;
    rc=close(dsid);

    dsid=open('sdtm.variablelevel(where=(domain="SUPPDM" and
                        variable in ("QNAM", "QLABEL", "QVAL" "QORIG")))');
    do i=1 to 4;
        rc=fetch(dsid);
        varlen=catx(" ", varlen, getvarc(dsid, 3), "$", getvarn(dsid, 5));
        varori=catx("|", varori, getvarc(dsid, 9));
    end;
    rc=close(dsid);

    call symputx("varname", varname);
    call symputx("varlabel", varlabel);
    call symputx("varlen", varlen);
    call symputx("varori", varori);
run;
libname dict clear;
libname sdtm clear;

/*fetch the unique alpha letter value from the dataset that is created by %LegVal()*/
proc sort data=work.lv_freq(where=(anyalpha(value))) out=work._freq nodupkey;
    by value;
run;
proc sql noprint;
    select quote(trim(value))
    into :lvvalue separated by ","
    from work._freq;
quit;

data _suppdm;
    merge work._enrl   random(keep= usubjid  randdate);
    by usubjid;
    length  &varlen ;
    drop i;
    array varname{5} $ _temporary_ (&varname);

    do i=1 to 5;
        qnam=varname[i];
        qlabel=scan("&varlabel", i, "|");
        qorig=scan("&varori", i, "|");
        qval=vvaluex(qnam);

        /*the alpha letter means missing value*/
        if qval in (&lvvalue) Then qval=cats(".",qval);

        /*vvaluex() return the formatted value. if a numeric value is missing, the return value is ". ".*/
        if strip(qval)="." then call missing(qval);

        if qnam="EMPLOY30" then qnam="EMPLOY";
       output;
    end;
run;
proc print data=_suppdm;
    where usubjid in (&validsubject);
run;

/******************************************************************************************************
  Creating the SDTM domain table.
* ****************************************************************************************************/
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(SDTM, DM SUPPDM)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(sdtmmeta)

/* *****************************************************************************************
* When input the original data, there is no data for death and all valus in relatived 
* columns are null. The proc import evluated them as char and couldn't be used here 
* and hardcode the dthdtc  as unll.
* *****************************************************************************************/
options varlenchk=nowarn;
data dm(label=&dmsetlabel);
    length &dmlength;
    label &dmlabel;
    set  _dm;
    keep &dmkeep;

    domain = "DM";
    if missing(first_t_day) then do;
        call missing(rfstdtc,  rfendtc,  rfxstdtc,  rfxendtc,  rficdtc,  rfpendtc); 
    end;
    else do;
        rfstdtc = put(first_t_day, E8601DA10.-L); 
        rfendtc = put(last_t_day, E8601DA10.-L); 
        rfxstdtc = put(first_t_day, E8601DA10.-L); 
        rfxendtc = put(last_t_day, E8601DA10.-L); 
        rficdtc = put(infoday, E8601DA10.-L); 
        rfpendtc = put(endday, E8601DA10.-L); 
    end;
    if missing(dthdtc) then call missing(dthfl); 
    else dthfl="1";
    sex = put(sex,sex.);
    race = put(race, race.);
    actarm=put(arm, actarm.);
    armcd=put(arm, armcd.);
    actarmcd = put(arm, actarmcd.);
    arm = put(arm, arm.);
    
    if not missing(age) then ageu = "YEARS";
    country = "USA";
run;
proc print data=dm;
    where usubjid in (&validsubject);
run;

data suppdm(label=&suppdmsetlabel);
    length &suppdmlength;
    label &suppdmlabel;
    set  _suppdm;
    keep &suppdmkeep;

    if _N_=1 then call missing(idvar, idvarval, qeval);
    rdomain = "DM";
run;
proc print data=suppdm;
    where usubjid in (&validsubject);
run;
options varlenchk=warn;

/* **************************************************************************************
  Sorting the dataset according to the keysequence metadata specified sort order 
    for a given dataset.
  If there is a __seq variable in a dataset, then create the __seq value for it
* ***************************************************************************************/
%SortOrder(dataset=DM SUPPDM)
/******************************************************************************************************
  Reduce the size of dataset by reducing the length of char type variables.
* ****************************************************************************************************/
%ReLenStd(SDTM,datasets=DM SUPPDM,minlen=2)
