/* ********* ********************* ****************************************
* data_prepare.sas
*   read data from raw file, clean the data, create SDTM datasets,
*   create ADaM datasets, and create analysis dataset
* ***********************************************************************/
/* *************************************************************************************
* Read data from local raw files in orilib, and remove the format, informat, and label
* *************************************************************************************/
%ReadData();
%RemoveAttr(lib=orilib);

/*There is no usubjid in overall original dataset, , create the usubjid for each dataset*/
%SetUsubjid(length=25);

/*since the data de-identification,  the date of randomization = day 0. 
for practice reason, create a random date as a subject's ramdomizqtion date
The createdate() is a customer function*/
data random;
    set orilib.random (keep=studyid usubjid treat);
    length rand_date 8;
    rand_date=createdate('01JUl2016'd);
run;
proc sort data=random;
    by usubjid;
run;

/*select subjects for validation randomly including one completed and one uncompleted
*  for the datasets in which a subject may has multi-recording, such as lb, ur, ae and so on*/
data work._usubjid;
    set orilib.term;
    if not missing(status) then do;
        if status = "1" then status="2";
        else status="1";
    end;
    keep usubjid status;
run;
proc print data=work._usubjid(obs=10);
run;
proc print data=orilib.term(obs=10 keep=usubjid status);
run;
proc sort data=work._usubjid;
    by status;
run;
proc surveyselect data=work._usubjid out=validsubject 
                                seed=1234 method=SRS n=(1 2) noprint;
    strata status;
run;
proc sql noprint;
    select quote(trim(usubjid)) into :validsubject separated by " "
    from validsubject (obs=2);
quit;

/* define the CDISC standard mapping files */
%let sdtmfile=&pdir.sdtm_metadata.xlsm;
%let adamfile=&pdir.adam_metadata.xlsx;

/* ****************************************
* Prepare SDTM dataset
* ****************************************/
/*Basing on CRF and dictionary, prepare the SDTM raw
* data and fill the SDTM metadata file*/
options varlenchk=nowarn;

%LegVal(orilib.dose, t25_1-t25_7 t100_1- t100_7);

proc sort data= orilib.dose (drop=r:  c: a: f: D25_1-D25_7 D100_1-D100_7 ) 
                 out=work._dose;
    by usubjid visid;
run;

data _ex ; 
    length startdate enddate n3 n13 8  valid3 valid13 $120;
    merge work._dose end=eof   random (keep=treat usubjid rand_date) ;
    by usubjid;

    retain exdose exstdy  _dose  startdate  exendy enddate
                n3 n13  valid3 valid13;
    array dos (2,7) t25_1 - t25_7 t100_1-t100_7;
    array datearr(7) date1-date7;
    keep studyid  usubjid exstdy exendy exdose  startdate enddate treat ;

    if _N_=1 then call missing(valid3, valid13);
    if first.usubjid then do;
        call missing(exdose,  exstdy);
    end;

    do i=1 to 7;
        if anyalpha(dos(1,i)) or missing(dos(1,i)) then dos(1,i) ="0" ;
        if anyalpha(dos(2,i))  or missing(dos(2,i)) then dos(2,i) ="0" ;
        _dose= sum(25*input(dos(1,i), 3.), 100*input(dos(2,i), 3.));

        if missing(exstdy)  then do;
            /*For SDTM the first day is day1*/
            if not missing(datearr(i)) then do;
                /*set start date*/
                exstdy = datearr(i) +1;
                startdate =  datearr(i) + rand_date;
                /*initialize enddate to avoid the null date in last week*/
                exendy =  datearr(i) +1;
                enddate = datearr(i)  + rand_date;
            end;
            exdose = _dose; 
        end;/*First dose*/
        else if exdose ne _dose then do;
            output; 
            if not missing(datearr(i)) then do;
                exstdy = datearr(i) +1 ;
                startdate =  datearr(i) + rand_date;
                /*initialize enddate to avoid the null date in last week*/
                exendy =  datearr(i) +1;
                enddate = datearr(i)  + rand_date;
            end;
            exdose = _dose;
        end;/*new dose*/
        else if not missing(datearr(i)) then do;
                exendy =  datearr(i)+1;
                enddate = datearr(i)  + rand_date;
        end;/*update end date*/

        if (last.usubjid or eof) and i=7 and _dose >0 then do;
            exendy =  datearr(i) +1;
            enddate = datearr(i) + rand_date;
            output;
            /*select the usubjid to validate*/
            if visid<4 and n3<2 then do;
                n3+1;
                call symputx(cats("valid3_",n3), usubjid);
            end;
            else if visid=13 and n13<3 then do;
                n13+1;
                call symputx(cats("valid13_",n13), usubjid);
            end;
        end; /*dose no change*/
    end;
run;

/*for easy to compare, print data respectively*/
data _null_;
    do i=1 to 3;
        param=cats('title "EX data"; proc print data=_ex;  where usubjid="&valid13_' 
                ,i,'"; run; title "Dose data"; proc print data=work._dose; where visid>11 
                and usubjid ="&valid13_',i,'"; run;');
        rc=dosubl(param);
    end;
    do i=1 to 2;
        param=cats('title "EX data"; proc print data=_ex;  where usubjid="&valid3_'
                ,i,'"; run; title "Dose data"; proc print data=work._dose; where 
                usubjid="&valid3_',i,'"; run;');
        rc=dosubl(param);
    end;
stop;
run;
title;

/*The major dm data come from enrl set.*/
proc sql;
    create table _dm as
    select e.studyid as studyid, e.usubjid as usubjid, put(e.subjid,8.-L) as subjid,
            startdate as first_t_day, enddate as last_t_day, 
            e.visdate + r.rand_date as infoday, 
           r.rand_date+max( ifn(missing(f.visdate),0,f.visdate),
                                            ifn(missing(f.contdate),0,f.contdate),
                                            ifn(missing(t.visdate),0,t.visdate),  
                                            ifn(missing(e.visdate),0,e.visdate)) as endday,  .  as dthday, 
            case when f.died = "1" or t.deathda ne '' then 'Y' else "" end as Dthfl,
            put(e.siteid,8.-L) as siteid, birthday as age, gender as sex, 
            case when white ="1" then "1"   
                    when  black eq "1" then "2"  
                    when asian ="1" then "3"
                    when hawaiian = "1" then "4" 
                    when  indian= "1" then "5" 
                    else "" end as race, 
            case e.reasdecl when "" then "" else "2" end as decline,
            case e.reasinel when "" then "" else "3" end as illegal,
            coalescec(r.treat, calculated decline, calculated illegal ) as arm,
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
proc print data=_dm (obs=10);
run;

/*finding the illegal values of the variables that would be included in suppdm*/
%LegVal(orilib.enrl, educatyr employ30 maritals eligible);
proc sort data= orilib.enrl(keep=studyid usubjid educatyr maritals employ30  eligible)
                    out=work._enrl;
    by usubjid ;
run;

data _suppdm;
    merge work._enrl   random(keep= usubjid  rand_date);
    by usubjid;
    length  qorig  $ 8 qnam  $ 10 qval $ 30 qlabel $ 27 ;

    if anyalpha(educatyr) then educatyr = "";
    if not missing(educatyr) then do;; 
        qnam = "EDUCATYR"; 
        qlabel = "Years of Formal Education"; 
        qorig ="CRF 01";
        qval=educatyr;
        output;
    end;

    if anyalpha(employ30) then employ30="10";
    if not missing(employ30) then do;
        qnam = "EMPLOY"; 
        qlabel = "Usual Employment Pattern"; 
        qorig ="CRF 01";
        qval=put(employ30, employ.);
        output;
    end;

    if anyalpha(maritals) then maritals='7';  
    if not missing(maritals) then do;
        qnam = "MARITALS"; 
        qlabel = "Marital Status"; 
        qorig ="CRF 01";
        qval=put(maritals,maritals.);
        output;
    end;

    if not missing(rand_date) then do; 
        qnam = "RANDDT"; 
        qlabel = "Date of Randomization"; 
        qorig ="CRF 06";
        qval=put(rand_date,E8601DA10.-L);
        output;
    end;

    if not missing(eligible) then do;
        qnam = "ELIGIBLE"; 
        qlabel = "Subject Eligible"; 
        qorig ="Derived";
        if eligible = "0" then qval="N"; 
        else if eligible in ("1","2") then qval="Y";
        output;
    end;
run;
proc print data=_suppdm (obs=10);
run;

/*instead of in end, the visit number is in middle for the variable names 
* that recording the result. this makes it is difficult to refer them as a group. 
* create a referring list to handle it. 
* another approach is to create a rename list by regular expression to rename 
* those variables by moving the visit number to end,
* as *prxchange("s/(ae)(\d+)(type|sev|sae|rel|act|out)/$1$3$2/i", 1, name)*/
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
/*in aelog, there are some almost empty record except hasing a aenum = 99.*/
proc sort data=orilib.aelog (where=(aenum ne 99)) out=work._aelog;
    by usubjid;
run;
data _ae;
    length aeacn aerel aeout aesev aeser aepresp $ 3 
                aestdy  aeendy sevlist serlist 8;
     
    merge work._aelog  (in=inae) 
                random(keep= usubjid  rand_date); 
    by usubjid;
    drop sevlist serlist;
    array type (48) $ &type ;
    array sev (48) $ &sev ;
    array act (48) $ &act; 
    array rel (48) $ &rel;
    array out (48) $ &out;
    array ser (48) $ &ser ;
    array rdte (3) aerdte1-aerdte3;

    retain sevlist serlist ;
    sevlist = 0;
    serlist = 0;
    /*normalize the value*/
    do i= 1 to 48;
        if sev(i) not in('1','2','3') then sev(i)='';
        else sevlist=max(sevlist, input(sev(i),3.));
        if ser(i) not  in('0','1') then ser(i)='';
        else serlist=max(serlist, input(ser(i),3.));
        if act(i) not  in('1','2','3','4','5','6','') then act(i)='5'; 
        if rel(i) not  in('1','2','3','4','5','6','') then rel(i)='1';
        if out(i) not  in('1','2','3','4','5','6','7','') then out(i)='7';
        else if out(i)='4' then out(i)='3';
        if type(i) not  in('1','2','3','4') then type(i)='';
        else if type(i)='4' then type(i)='3';
    end;

    aesev =cats(sevlist);
    aeser =cats(serlist);

    do i=48 to 1 by -1; 
        if not missing(act(i)) and  (missing(aeacn) or aeacn eq '5' or aeacn eq '6' ) then aeacn=act(i);
        if not missing(rel(i))  and  missing(aerel) then aerel=rel(i);
        if not missing(out(i))  and  missing(aeout) then aeout=out(i);
        if not missing(type(i)) and  type(i) eq '2' then aepresp = '1'; 
    end;

    /*There is AE reported date on CRF, but this date didn't included in dataset. So, using the onsit
    *  date(aeodte) as first AE date. The aerdte is basing on the first AE date*/
    if not missing(aeodte) then do;
        if aeodte < 0 then aestdy = aeodte;
        else aestdy = aeodte + 1;
            do i=3 to 1 by-1; 
            if not missing(rdte(i))  then do;
                if rdte(i) < 0 then  aeendy =rdte(i); 
                else aeendy =aeodte+rdte(i) + 1; 
                continue;
            end;
        end;
    end;

    if inae;
run;
proc print data=_ae (obs=10);
run;

proc sql ;
    select name, varnum, case when type="char" then length else . end as length
        from dictionary.columns
        where libname="ORILIB" and memname="LABS";
quit;

/*The values of variable that name end with x and MM are comment and be set to null, 
*  will be dropped*/
data _null_;
    length he_chvar evalname droplist $1000 urinvar $500;
    retain he_chvar  urinvar evalname droplist;
    set sashelp.vcolumn end=eof;
    where libname="ORILIB" and memname="LABS"
                and varnum between 10 and 115;
    if _N_ <=75 then do;
        if mod(_N_, 3) = 1 then he_chvar=catx(", ",he_chvar, quote(trim(name)));
        if mod(_N_, 3) = 2 then evalname=catx(" ",evalname, name);
    end;
    else if _N_ >=80 then do;
        if mod(_N_,3) = 2 then urinvar=catx(", ",urinvar, quote(trim(name)));
        if mod(_N_, 3) = 0 then evalname=catx(" ",evalname, name);
    end;
    if find(name,"x",-33,"i") or find(name,"mm",-33,"i") then  
                droplist=catx(" ",droplist, name);
    if eof then do;
        call symputx("he_chvar", he_chvar);
        call symputx("urinvar", urinvar);
        call symputx("evalname", evalname);
        call symputx("orilbdrop", droplist);
    end;
run;

proc sort data=orilib.labs(drop=&orilbdrop) out=work._labs;
    by usubjid;
run;
data _lb;
    length lbtestcd lbtest lborres lbstresc $8 lbcat $ 10 lborresu $5 lbnrind $ 3;
    merge work._labs(in=inlab)  random(keep=usubjid rand_date);
    by usubjid;

    if visid = 0 then lbblfL="Y"; 
    visitnum=visid;
    if visdate < 0 then lbdy = visdate;
    else lbdy = visdate + 1;
    if not missing(lbdy) then col_date = sum(rand_date, lbdy);
/* According to the notes of lbnrind in SDTMIG v3.2: "Should not be used to indicate 
    clinical significance".
    The original value "3" of the lbnrind was classed to "2"*/
    array eval (*) $ &evalname;
    do i=1 to dim(eval);
        if eval(i) in ('1','2','3') then do;
            if eval(i) ="3" then eval(i)="2";
        end;
        else eval(i) = '';
    end;
    array  he_ch(25,2) $ wbc--hemgeval;
    array  he_chvar(25) $ _temporary_  (&he_chvar);
    array urin(9,2) $ specgrav -- leukeval;
    array urinvar(9) $ _temporary_ (&urinvar);
    retain he_chvar urinvar;
    do i=1 to 25;
        lbcat =ifc(i<11, "HEMATOLOGY",  "CHEMISTRY");
        if he_ch(i,1) ne "" then do;
            lbtestcd = he_chvar(i);
            lbtest = he_chvar(i);
            lborres = he_ch(i,1);
            lbstresc = he_ch(i,1); 
            if not (prxmatch('/[a-z]/i', he_ch(i,1))) then lbstresn = input(he_ch(i,1), 8.2);
            lbnrind = he_ch(i,2); 
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

    do i=1 to 9;
        lbcat = "URINALYSIS"; 
        call missing(lborresu);
        if urin(i,1) ne "" then do;
            lbtestcd = urinvar(i);
            lbtest = urinvar(i);
            lborres = urin(i,1);
            lbstresc = urin(i,1);
            lbnrind = urin(i,2);
            if lbtestcd in ("PH", "SPECGRAV") and not (prxmatch('/[a-z]/i', urin(i,1)))
                then lbstresn = input(urin(i,1),8.2);
            else call missing(lbstresn);
            output;
        end;
    end;
    call missing(lbstresn, lbnrind);
    if urcolor ne '' then do;
        lbcat = "URINALYSIS";
        lbtestcd = "COLOR"; 
        lbtest = "COLOR"; 
        lborres = urcolor; 
        lbstresc = urcolor; 
        output;
    end;
    if urapp ne '' then do;
        lbcat = "URINALYSIS";
        lbtestcd = "APPEAR"; 
        lbtest = "APPEAR"; 
        lborres = urapp;    
        lbstresc = urapp; 
        output;
    end;

    if  inlab;
run;
proc print data=_lb;
    where usubjid in (&validsubject);
run;

/*The urine test is the "endpoint" of this study. According SDTMGI3.2, 
* should including these data in LB doamin, rather than create custom domain. 
* However, on the urine drug screen form CRF 09, the result in neg/pos only and 
* there is not Creatinine. Even in the same date, the value of creatinine in labs dataset 
* is not match the value in urine dataset. It looks like some information was missed.
* To keep the result match the original, recording urine drug data in a custom domain
* note: the new version has include a urin domain*/
proc sql noprint;
    select quote(trim(name))
    into :ur_variable separated by ","
    from dictionary.columns
    where libname="ORILIB" and memname="URINE" and varnum between 11 and 19;
quit;

proc sort data=orilib.urine out=work._urine;
    by usubjid desending coll_dat ;
run;

data work._ur work._ur1(keep=usubjid urorres urblfl urdy urtest);
    merge work._urine random(keep=usubjid rand_date);
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
    coll_dat =coll_dat + rand_date;
    
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
               if input(ch(i),8.) >0 then urblfl="Y";
               output work._ur1;
            end;
        end;
    end;
run;
/*in the obs that urorres > 0, the urblfl had been set to "Y"*/
proc sort data=work._ur1;
    by usubjid urtest urdy;
run;
/*output the real urblfl*/
data work._ur1;
    set work._ur1;
    by usubjid urtest;
    length urorres_t urblfl_t $8 urdy_t 8;
    retain urorres_t urblfl_t urdy_t;
    drop urorres_t urblfl_t urdy_t;

    if first.urtest then do;
        call missing(urorres_t);
        call missing(urblfl_t);
        call missing(urdy_t);
    end;
    if urblfl="Y" then do;
        urorres_t = urorres;
        urblfl_t = urblfl;
        urdy_t = urdy;
    end;
    if last.urtest then do;
        if missing(urblfl_t) then do;
            urblfl="Y";
            output; 
        end;
        else do;
            urorres=urorres_t;
            urblfl = urblfl_t;
            urdy =urdy_t ;
            output;
        end;
    end;
run;
proc sql;
    create table _ur as
    select a.studyid, a.usubjid, coll_dat, a.urorres, a.urorresu, b.urblfl, a.urdy, a.visitnum, a.urtest
    from work._ur as a left join (select * from work._ur1) as b
        on a.usubjid=b.usubjid and a.urdy=b.urdy and a.urtest=b.urtest;
quit;

proc print data=_ur;
    where usubjid in (&validsubject);
run;

proc sql noprint;
    select quote(trim(name))
    into :vs_variable separated by ","
    from dictionary.columns
    where libname="ORILIB" and memname="VS" and varnum between 10 and 15;
quit;

proc sort data=orilib.vs out=work._vs;
    by usubjid desending visdate;
run;

data _vs (keep=studyid usubjid vstest vsorres vsorresu vsblfl visitnum visdate vsdy);
    merge work._vs(in=invs rename=(visid = visitnum))  
                 random(keep=usubjid rand_date);
    by usubjid;
    length vsorresu $ 12 vsblfl temp resp blds bldd puls weig $1;
    retain temp resp blds bldd puls weig ;

    if first.usubjid then call missing(vsblfl, temp, resp, blds, bldd, puls, weig);
    if not missing(visdate) then do;
        vsdy= visdate +1;
        visdate = rand_date + visdate;
    end;
    
    if first.usubjid then call missing(temp, resp, blds, bldd, puls, weig);
    array vsval(6) $ tempval -- weight;
    array vsvar(6) $ _temporary_ (&vs_variable);
    array vsbase(6) $ temp resp blds bldd puls weig;
    /*The unit marked on CRF*/
    array vsunit (6) $ 12. _temporary_ ("F","breaths/min","mmHg", "mmHg","beats/min","LB");
    do i=1 to 6;
        if not missing(vsval(i)) and not(prxmatch('/[a-z]/i', vsval(i))) then do;
            vstest = vsvar(i); 
            vsorres = vsval(i); 
            vsorresu = vsunit (i);
            if visitnum = 0 and missing(vsbase(i)) then do;
                vsblfl="Y";
                vsbase(i)="1";
            end;
            output;
       end;
    end;
run;
proc print data=_vs ;
    where usubjid in (&validsubject);
run;

proc sort data=orilib.term(keep=usubjid status) out=work._term;
    by usubjid;
run;

%LegVal(work.term, status);

proc sql;
    create table work._dsex as
    select usubjid, max(enddate) as enddate
    from _ex
    group by usubjid
    order by usubjid;
quit;

data _ds;
    length dsterm dsdecod $10 dscat dsscat $20;
    merge random (in=inrand) work._term work._dsex _dm;
    by usubjid;
    keep studyid siteid subjid usubjid dsterm dsdecod dscat dsscat dsdy dsstdy;

    dsterm="0";
    dsdecod="0";
    dscat="3";
    dsdy=rand_date;
    dsstdy=1;
    if inrand then  output;

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
    if inrand then output;
run;
proc print data=_ds (obs=10);
run;
/*creates the labellist, keeplist, lengthlist and orderlist for each SDTM domain.
*  The data are stored in Sdtmmeta .*/
%getCdiscSetMeta(SDTM)
%getSetDef(sdtmmeta)

/* *****************************************************************************************
* When input the original data, there is no data for death and all valus in relatived 
* columns are null. The proc import evluated them as char and couldn't be used here 
* and hardcode the dthdtc  as unll.
* *****************************************************************************************/
data dm;
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
    dthdtc = ""; 
    sex = put(sex,sex.);
    race = put(race, race.);
    actarm=put(arm, actarm.);
    armcd=put(arm, armcd.);
    actarmcd = put(arm, actarmcd.);
    arm = put(arm, arm.);
    
    if not missing(age) then ageu = "YEARS";
    country = "USA";
run;
proc print data=dm (obs=10);
run;

data suppdm;
    length &suppdmlength;
    label &suppdmlabel;
    set  _suppdm;
    keep &suppdmkeep;

    if _N_=1 then call missing(idvar, idvarval, qeval);
    rdomain = "DM";
run;
proc print data=suppdm (obs=10);
run;

data ae;
    length &aelength;
    label &aelabel;
    set  _ae;
    keep &aekeep;

    if _N_=1 then call missing(aehlt, aehltcd, aehlgt,aehlgtcd,
                        aebodsys,aebdsycd, aeseq );
    domain = "AE";
    if not missing(aestdy) then aestdtc = put (rand_date + aestdy, E8601DA10.-L);
    if not missing(aeendy) then aeendtc = put (rand_date + aeendy, E8601DA10.-L);
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
proc print data=ae;
    where usubjid in (&validsubject);
run;

data ex;
    length &exlength;
    label &exlabel;
    set  _ex;
    keep &exkeep;
 
    call missing(exseq); 
    domain="EX";
    exdosu = "mg";
    exdosfrm= "TABLET";
    exstdtc = put(startdate, E8601DA10.-L);
    exendtc = put(enddate, E8601DA10.-L);
    extrt = treat;
run; 
proc print data=ex ;
    where usubjid in (&validsubject);
run;

data lb;
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
proc print data=lb;
    where usubjid in (&validsubject);
run;

data ur;
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
proc print data=ur;
    where usubjid in (&validsubject);
run;

data vs;
    length &vslength;
    label &vslabel;
    set  _vs;
    keep &vskeep;
    
    call missing(vsseq); 
    domain = "VS";
    vsdtc = put(visdate, E8601DA10.-L);
    vstestcd = put(vstest, vstestcd.);
    vstest = put(vstest, vstest.);
    vsstresc = vsorres;
    vsstresn =input(vsorres, 8.);
    vsstresu = put(vsorresu, vsresu.);
    visit=put(visitnum, visit.);
run;
proc print data=vs;
    where usubjid in (&validsubject);
run;

data ds;
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
proc print data=ds (obs=10);
run;
/* **************************************************************************************
* sorting the dataset according to the keysequence metadata specified sort order 
* for a given dataset.
* if there is a __seq variable in a dataset, then create the __seq value for it
* ***************************************************************************************/
 %SortOrder()
%ReLenStd(SDTM,min=1)

/*The macro makeCdiscData will create the define.xml file, output .xpt file, and call 
*  pinnacle21-community to validate the data.
*  There would be a lot of error in the result of the validation. 
*  1. There are only several domains that are created, so the data that should be supplied by other 
*      domains are missing.
*  2. As a result of de-Identification, some data have been set to null
*  3. Instead of annotated CRF, there is CRF only. In the dictionary, the comments are short. 
*      So, it takes a lot of time to track and compare to understand the data and may miss-understand.
*      Because this project is just for the demo, for fun, for a memo..., but not for submission. 
*      So it not worth spending a lot of time correcting it.*/
%makeCdiscData(SDTM)

%Delmvars()
%cleanLib(work)
%cleanLib(&pname)

/* ****************************************
* Prepare ADaM dataset
* ****************************************/
/*creates the labellist, keeplist, lengthlist and orderlist for each ADaM domain.
*  The data are stored in Sdtmmeta .*/
%getCdiscSetMeta(ADAM)
%getSetDef(adammeta)

proc sort data= suppdm;
    by usubjid qnam;
run;
proc transpose data =suppdm out= _adsupdm(drop=_name_  _label_
                    rename=(randdt = randdtc    educatyr = educatyrc));
    var qval;
    by usubjid;
    id qnam;
    IDLABEL qlabel;
run;

data addm;
    length &addmlength;
    label &addmlabel;
    keep &addmkeep;
    merge  dm(in = indm where=(rfxstdtc ne ""))  
            _adsupdm(where=(randdtc ne ""));
    by usubjid;

    randdt = input(randdtc, E8601DA10.-L);
    educatyr = input(educatyrc, $3.);
    trtp = arm;
    if armcd = "P" then trtpn = 0;
    else if armcd = "T" then trtpn = 1;
    else trtpn = .;
    if indm;
run;
proc print data=addm(obs=10);
run;
proc sort data=ds out=_dsc(keep=usubjid dsdecod dsstdtc rename=(dsdecod=EOSSTT dsstdtc=EOSDTc )) ;
    by usubjid;
    where dsscat="STUDY PARTICIPATION" ;
run;
data adsl;
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
proc print data=adsl(obs=10);
run;

data adae;
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
/*the last day recording in ur test does not match the recording in complete status recording
some subjedts were marked dropped, however, after several weeks, their ur test appeared again
Here, using complete status data*/ 
proc sql;
    create table _adur as
        select u.studyid, u.usubjid, d.age as age, d.sex as sex, d.race as race, d.arm as trtp, u.urseq, 
                d.trt01pn as trtpn, urstresn as aval, urstresc as avalc, visit as avisit, (trtedt-trtsdt+1) as aendy,
                visitnum as avisitn, input(urdtc, E8601DA10.-L) as adt ,  urdy as ady, urblfl as ablfl,
                "Week Methamphetamine Use" as crit1,
                case when max(urstresn)<78 then "N" else "Y" end as crit1fl, 
                case when calculated crit1fl = "Y" then 1 else 0 end as crit1fn length=3,
                case when not missing(urblfl) then urstresn else . end as base,urtestcd,
                case when complfl="Y" then 1 else 0 end as cnsr,
                ifc(complfl="N", eosstt, "") as evntdesc, BASEGR1
        from ur as u, adsl as d, (select usubjid, case when urstresn>=78 then "Y" else "N" end as BASEGR1
                                             from ur where urblfl = "Y" and urtestcd = "METHAMPH") as b 
        where u.usubjid = d.usubjid and u.usubjid=b.usubjid
                and  visitnum < 13 and urtestcd = "METHAMPH"
        group by u.usubjid, visitnum;
quit;
/*time to event dataset*/
proc sql;
    create table adtte as 
    select distinct studyid, usubjid,  trtp, trtpn, aendy as aval, cnsr, evntdesc
    from _adur;
quit;
data adtte;
    length &adttelength;
    label &adttelabel;
    keep &adttekeep;
    set adtte ;

    param="Time to Discontinued";
    paramcd="DISCONTD";
run;
proc print data=adtte(obs=10);
run;

/*primary outcome dataset*/
proc sql;
    create table adefp as 
    select distinct studyid, usubjid, trtp, trtpn, avisit, avisitn, sum(crit1fn) as aval, basegr1
    from _adur
    where avisitn between 6 and 12
    group by usubjid, avisitn;
quit;

data adefp;
    length &adefplength;
    label &adefplabel;
    keep &adefpkeep;
    set adefp;

    if aval>=78 then aval=1;
    else aval=0;
    param = "Qualitative Urine Drug Screen for Methamphetamine is Positive";
    paramcd = "URMEAMP" ;
run;
proc sort data=adefp;
    by basegr1;
run;
proc print data=adefp(obs=10);
run;

options varlenchk=warn;
%Delmvars()
%cleanLib(work)
%cleanLib(&pname)


/*General info about the data
%LibInfor;
*/
