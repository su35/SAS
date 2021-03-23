/* ***********************************************************************************************
     Name  : AEtable.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: create the AE domain Adverse Events table
*   *********************************************************************************************/
/*data glancing*/
proc sort data=orilib.aelog out=work._aelog nodupkey;
    by usubjid;
run;
proc print; run;

/*in aelog, there are some almost empty record except hasing a aenum = 99.*/
proc sort data=orilib.aelog (where=(aenum ne 99)) out=work._aelog;
    by usubjid;
run;
/******************************************************************************************************
  Data cleaning and SDTM mapping.
  Instead of at the end, the visit number is at the middle for the variable names. 
  This makes it is difficult to list them as a group.  creating a referring list to handle it.  
  Another approach is to create a rename list by regular expression to rename those variables 
  by moving the visit number to end, 
  ex: pexchange("s/(ae)(\d+)(type|sev|sae|rel|act|out)/$1$3$2/i", 1, name) 
* ****************************************************************************************************/
data _null_;
    length type sev sae rel act out $ 500;
    do i = 1 to 48;
        type=catx(" ", type, "ae"||cats(i)||"type");
        sev=catx(" ", sev, "ae"||cats(i)||"sev");
        sae=catx(" ", sae, "ae"||cats(i)||"sae");
        rel=catx(" ", rel, "ae"||cats(i)||"rel");
        act=catx(" ", act, "ae"||cats(i)||"act");
        out=catx(" ", out, "ae"||cats(i)||"out");
    end;
    call symputx("type", type);
    call symputx("sev", sev);
    call symputx("ser", sae);
    call symputx("rel", rel);
    call symputx("act", act);
    call symputx("out", out);

    stop;
run;
/*get the legal value*/
data work.aeterm;
    set Sponsors_termin (obs=7);
    where dataset="AELOG";
    vars=prxchange('s/AE1([A_Z]*)/$1/', -1, vars);
    legal_value=compress(legal_value,,"p");
    call symputx('vf_'||vars, legal_value);
run;
/******************************************************************************************************
  
* ****************************************************************************************************/
data _ae(drop=errordata) 
        error(keep=usubjid errordata);
    length aeacn aerel aeout aesev aeser $ 3 
                aerdte aestdy  aeendy sevlist serlist 8
                errordata $200 ;
    merge work._aelog  (in=inae) 
                random(keep= usubjid  randdate); 
    by usubjid;
    drop sevlist serlist ;
    array type (48) $ &type ;
    array sev (48) $ &sev ;
    array act (48) $ &act; 
    array rel (48) $ &rel;
    array out (48) $ &out;
    array ser (48) $ &ser ;
    array rdte (3) aerdte1-aerdte3;
    /*sevlist serlist are numeric variable which hold the max value temporarily*/
    retain sevlist serlist (0,0) ;

    /******************************************************************************************************
        According to SDTM Terminology, normalize the value.
     * ****************************************************************************************************/
    do i= 1 to 48;
        if not missing(sev(i)) then do;
            if verify(sev(i), "&vf_sev") then do; 
                /*if the value is illegal, add the value in errordata*/
                errordata=catx(",", errordata, "sev", i, "=", sev(i));
            end;
            /*According to SDTM, the alpha character value should be missing*/
            else if anyalpha(sev(i)) then call missing(sev(i)); 
            else sevlist=max(sevlist, input(sev(i),3.)); /*get the max value*/
        end;
        if not missing(ser(i)) then do;
            if verify(ser(i), "&vf_sae") then do;
                errordata=catx(",", errordata, "ser", i, "=", ser(i));
            end;
            else if anyalpha(ser(i)) then call missing(ser(i));
            else serlist=max(sevlist, input(ser(i),3.));
        end;
        if not missing(act(i)) then do;
            if verify(act(i), "&vf_act") then do;
                errordata=catx(",", errordata, "act", i, "=", act(i));
            end;
            else if anyalpha(act(i)) then do;
                if act(i)="A" then act(i)="6";/*both the 6 and A are refer to the Not Applicable*/
                else act(i)="5";/*unknown is legal term in SDTM terminology*/
            end;
        end;
        if not missing(rel(i)) then do;
            if verify(rel(i), "&vf_rel") then errordata=catx(",", errordata, "rel", i, "=", rel(i));
            else if anyalpha(rel(i)) then rel(i)="1"; 
        end;
        if not missing(out(i)) then do;
            if verify(out(i), "&vf_out") then errordata=catx(",", errordata, "out", i, "=", out(i));
            else do;
                if anyalpha(out(i)) then out(i)='7';
                else if out(i)='4' then out(i)='3';/*both 3 and 4 refer to NOT RESOLVED*/
            end;
        end;
        if not missing(type(i)) and verify(type(i), "&vf_type") then
            errordata=catx(",", errordata, "type", i, "=", type(i));
    end;

    /*get the max value*/
    aesev =cats(sevlist);
    aeser =cats(serlist);

    /*get the last value as the final value*/
    do i=48 to 1 by -1; 
        if not missing(act(i)) and  (missing(aeacn) or aeacn eq '5' or aeacn eq '6' ) then aeacn=act(i);
        if not missing(rel(i))  and  missing(aerel) then aerel=rel(i);
        if not missing(out(i))  and  missing(aeout) then aeout=out(i);
    end;

    /******************************************************************************************************
      There is AE reported date on CRF, but this date didn't included in dataset. So, using the onsit
      date(aeodte) as first AE date.
    * ****************************************************************************************************/
    if not missing(aeodte) then do;
        if aeodte < 0 then aestdy = aeodte;
        else aestdy = aeodte + 1;
            do i=3 to 1 by-1; 
            if not missing(rdte(i))  then do;
                if missing(aerdte) then aerdte=rdte(i);
                if rdte(i) < 0 then  aeendy =rdte(i); 
                else aeendy =aeodte+rdte(i) + 1; 
                continue;
            end;
        end;
    end;

    if inae then output _ae;
    if not missing(errordata) then output error;
run;

/*save the select subjects, for validation, to the macro variable validsubject.*/
data _null_;
    set validsubject;
    call symputx("validsubject", validsubject);
run;

proc print data=_ae(keep=usubjid aeacn aerel aeout aesev aeser aestdy aeendy 
                                  aeodte aestdy aeendy aerdte1 aerdte2 aerdte3);
    where usubjid in (&validsubject);
run;
/******************************************************************************************************
  Creating the SDTM domain table.
* ****************************************************************************************************/
/*fetch the metadata from metadata define file and store them in a dataset*/
%getCdiscSetMeta(SDTM, AE)
/*create the length, label, and keep define value and store them in macro variables*/
%getSetDef(sdtmmeta)

options varlenchk=nowarn;
data ae(label=&aesetlabel);
    length &aelength;
    label &aelabel;
    set  _ae;
    keep &aekeep;

    if _N_=1 then call missing(aehlt, aehltcd, aehlgt,aehlgtcd,
                        aebodsys,aebdsycd, aeseq );
    domain = "AE";
    if not missing(aestdy) then aestdtc = put (randdate + aestdy, E8601DA10.-L);
    if not missing(aeendy) then aeendtc = put (randdate + aeendy, E8601DA10.-L);
    aeterm = ptname;
    aedecod = aeevnt;
    aeptcd = input(ptcode, 8.);
    aesoc = socname;
    aesoccd = input(socode, 8.);
    aellt = lltname;
    aelltcd = input(lltode, 8.);
    aepresp = put(aepresp, ny.);
    aesev = put(aesev, aesev.);
    aeser = put(aeser, ny.);
    aeacn = put(aeacn, acn.);
    aerel = put(aerel, aerel.);
    aeout = put(aeout, aeout.);
run;
options varlenchk=warn;

/* **************************************************************************************
  Sorting the dataset according to the keysequence metadata specified sort order 
    for a given dataset.
  If there is a __seq variable in a dataset, then create the __seq value for it
* ***************************************************************************************/
%SortOrder(dataset=AE)
/******************************************************************************************************
  Reduce the size of dataset by reducing the length of char type variables.
* ****************************************************************************************************/
%ReLenStd(SDTM,datasets=AE,minlen=1)
