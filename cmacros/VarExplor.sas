/* *********************************************************************
* macro VarExplor: 
* Create vars data set to collecte the characteristic of the variables
* dn: The data set used to analyse or modeling. It is required.
* outdn: The created data set
* vardefine: dataset that recording the variables define.
* if the vardefine is not available, the following params may need.
*   target: The target variable for modeling. If the vardefine is unavailable, the target is required
*   exclu: The list of variables which are not included in analysis or modeling
*   interval: list of interval variables
*   ordinal: list of ordinal variables
*   id: the id variable
* *********************************************************************/
%macro VarExplor(dn, lib=&pname, outdn=vars, vardefine=, id=, target=, exclu=,interval=,ordinal= )/minoperator;
    %if %superq(dn)=  %then %do;
        %put ERROR: ======= The input dataset is missing ======;
        %return;
    %end;
    %local  vd_freqlist i vd_size vd_excp_class pctoutl pctoutu fclist keeplist mlen;
    /*to void a unnecessary out put, close the notes, html, and listing */
    options nonotes  varlenchk=nowarn;

    /*if the variable define dataset is available, get the required params that were not assinged*/
    %if %superq(vardefine)^= %then %do;
        proc sql noprint;
            %if %superq(target)= %then %do;
                select distinct variable into :target trimmed
                from &vardefine where target not is missing;
            %end;
            %if %superq(id)= %then %do;
                select distinct variable into :id trimmed
                from &vardefine where id not is missing;
            %end;

            select distinct variable into :keeplist  separated by " "
            from &vardefine 
            where exclude is missing and variable not in (
                                        %if %superq(exclu) ^= %then %strtran(exclu) &exclu;
                                        %if %superq(id) ^= %then "&id";
                    );

            %if %superq(interval)= %then %do;
                select distinct variable into :interval  separated by " "
                from &vardefine 
                where class="interval" and variable ^="&target" and exclude is missing;
            %end;
            %if %superq(ordinal)= %then %do;
                select distinct variable into :ordinal  separated by " "
                from &vardefine 
                where class="ordinal" and variable ^="&target" and exclude is missing;
            %end;

            %if %sysfunc(exist(&outdn)) %then drop table &outdn; ;
        quit;
        
        proc sort data=&vardefine out=work.ve_&vardefine;
            by vid;
        run;

        data work.ve_&vardefine;
            set work.ve_&vardefine;
            by vid;
            if first.vid then output;
        run;
    %end;
    %else %if %superq(interval)= %then %do;
        proc sql noprint;
            select name into :interval  separated by " "
            from dictionary.columns
            where libname="%upcase(&lib)" and memname="%upcase(&dn)" and type="num" 
            and upcase(name) not in (
            %if %superq(ordinal)^= %then 
                %StrTran(ordinal) %upcase(&ordinal); %StrTran(ordinal)
            %if %superq(exclu)^= %then 
                %StrTran(exclu) %upcase(&exclu); %StrTran(exclu)
            %if %superq(target)^= %then "%upcase(&target)"; 
            %if %superq(id)^= %then "%upcase(&id)"; 
            );
        quit;
    %end;

    %if %superq(interval)^=  %then %interval_stat();
    %nominal_stat()
    /*get the mode. the mode may has more than one value*/
    proc sql;
        create table work.ve_tmp as
        select distinct variable, value , frequency 
        from freq where value not is missing and value  ^="." 
        group by variable 
        having frequency=max(frequency)
        order by variable;
    quit;

    data work.ve_tmp;
        set work.ve_tmp;
        by variable;
        length mode $200;
        retain mode;
        if first.variable then mode=" ";
        mode=catx(",",mode,value);
        if last.variable then output;
    run;

    /*Create the output dataset*/
    proc sql noprint;
        select max(lengthn(mode)) into :mlen
        from work.ve_tmp;

        alter table work.ve_tmp modify mode char(&mlen);

        create table &outdn as
            select a.name as variable, a.type label="Type", 
            %if %superq(vardefine)^= %then  e.class, e.description, ;
            %else "" as class, ;
            b.n, b.nlevels, mode, d.frequency as mode_n,
            ifn(missing(c.nmissing), 0, c.nmissing) as nmissing, 
            ifn(missing(c.pctmissing), 0.00, c.pctmissing) as pctmissing 
            from 
            (select distinct name, type from dictionary.columns
                where libname=upcase("&lib") and memname=upcase("&dn")
                %if %superq(vardefine)^= %then and name in (select variable from &vardefine);
                ) as a left join
                (select distinct variable, sum(ifn(missing=0, frequency, 0)) as n, nLevels
                from freq group by variable) as b on a.name=b.variable left join
                (select distinct variable, frequency  as nmissing, round(percent, 2) as pctmissing
                from freq where missing=1) as c on b.variable=c.variable left join
                (select variable, mode, frequency from work.ve_tmp) as d on d.variable=a.name
                %if %superq(vardefine)^= %then left join (select distinct variable, class, description
                from work.ve_&vardefine) as e on e.variable=a.name ;
            ;
    quit;
    %if %superq(interval)^=  %then %do; 
        proc sort data=&outdn ;
            by variable;
        run;
        proc sort data=work.ve_utable;
            by variable;
        run;
    /*comput the percent of outlier*/

        proc sql noprint;
            select variable, outlow, outup, n
            into :vd_vname1-:vd_vname999, :vd_low1-:vd_low999, :vd_up1-:vd_up999, :vd_n1-:vd_n999
            from work.ve_utable
            where not missing(outlow) or not missing(outup);
        
            %if &sqlobs>0 %then %do;
                %let vd_size=&sqlobs;
                create table work.ve_pctout 
                    (variable char(32), pctoutl num(8), pctoutu num(8));
                %do i=1 %to &vd_size;
                    %if "&&vd_low&i" ne "." %then %do;
                        select round(count(&&vd_vname&i)/&&vd_n&i*100,0.01) 
                        into :pctoutl
                        from &dn
                        where &&vd_vname&i<&&vd_low&i;
                    %end;
                    %else %let pctoutl=.;
                    %if "&&vd_up&i" ne "." %then %do;
                        select round(count(&&vd_vname&i)/&&vd_n&i*100,0.01) 
                        into :pctoutu
                        from &dn
                        where &&vd_vname&i>&&vd_up&i;
                    %end;
                    %else %let pctoutu=.;
                    insert into work.ve_pctout
                    set variable="&&vd_vname&i", pctoutl=&pctoutl, pctoutu=&pctoutu; 
                %end;
            %end;
        quit;
        %if %sysfunc(exist(work.ve_pctout)) %then %do;
            proc sort data=work.ve_pctout;
                by variable;
            run;
            data work.ve_utable;
                length variable $ 32;
                merge work.ve_utable work.ve_pctout;
                by variable;
            run;
        %end;
    %end;
    options noquotelenmax;
    data  &outdn;
        retain variable type class normal n nlevels nmissing pctmissing derive_var exclude target id mode description;
        length variable $ 32 class $8 derive_var exclude target id 8;
        %if %superq(interval)^= %then %do;
            merge &outdn work.ve_utable;
            by variable;
        %end;
        %else set  &outdn  %str(;); 
        /*if the vardefine is not available, add class value*/
        %if %superq(vardefine)= %then %do;
            if nlevels=2 then class="binary";
            %if %superq(ordinal)^= or %superq(interval)^= %then %do;
                %if %superq(ordinal)^= %then %do;
                    %StrTran(ordinal)
                    else if upcase(variable) in (%upcase(&ordinal)) then class="ordinal";
                %end;
                %if %superq(interval)^= %then %do;
                    %StrTran(interval)
                    else if upcase(variable) in (%upcase(&interval)) then class="interval";
                %end;
                    else class="nominal";
            %end;
            %else %do;
                else if type="char" then class="nominal";
                 else class="";
            %end;
        %end;
        if nmissing >0 and missing(nlevels)=0 then nlevels=nlevels-1;

        %if %superq(target) ne %then %do;
            if upcase(variable)=upcase("&target") then do; 
                target=1; 
                exclude=1;
            end;
            else do;
                call missing (target, exclude);
            end;
        %end;
        %if %superq(id) ne %then %do;
            if upcase(variable)=upcase("&id") then do; 
                id=1; 
                exclude=1;
            end;
            else do;
                call missing (id, exclude);
            end;
        %end;

        /*nelevels=0 means there is missing only.
           if nelevels=1and missing <5, then missing value couldn't be conside as one class*/
        if nlevels<1 or (nlevels=1 and pctmissing<5) then exclude=1;
    run;

    proc sql;
        update &outdn set exclude=1
        where variable in (select variable from 
                (select distinct variable, max(percent) as maxperc 
                from freq
                group by variable having maxperc>95));
    quit;

    proc sort data=&outdn;
        by type class;
    run;

    options quotelenmax;

    proc sql ;
        title1 "The value level of the following continual variables, if any, is less then 10.";
        select quote(trim(variable)) into :vd_excp_class separated by " "
        from &outdn
        where class="interval" and nlevels<=10 and exclude is missing;

        %if %superq(vd_excp_class)^= %then %do;
        title1 "The 'CLASS' of the following variables may need to set ORDINAL.";
        title2 "The names of those variable were storaged in Macro variable excp_class";
            %global excp_class;
            %let excp_class=&vd_excp_class;
            select * from freq where variable in (&vd_excp_class);
        %end;
        title1;
        title2;
    quit;

    proc datasets lib=work noprint;
       delete ve_: tmp;
    run;
    quit;
    options varlenchk=warn;
    options notes;
    %put  NOTE:  ==The dataset vars, Freq and outlier were created.==;
    %put  NOTE:  ==The macro VarExplor executed completed. ==;
%mend VarExplor;    

%macro interval_stat();
    %local is_nobs;
    data _null_;
        set &dn nobs=obs;
        call symputx("is_nobs", obs);
        stop;
    run;
    
    proc univariate data=&dn (
            %if %superq(keeplist) ne %then keep=&keeplist;
            %else %do;
                drop=
                %if %superq(exclu)  ne  %then &exclu;
                %if %superq(id)  ne  %then &id; 
            %end;
            )
        normal noprint outtable=work.ve_utable (keep=_var_  _q1_  _q3_  _qrange_ _min_ _mean_ 
                    _median_ _max_ _nobs_  _nmiss_ 
            rename=(_var_=variable  _q1_=q1 _q3_=q3 _qrange_=qrange _min_=min _max_=max
                    _mean_=mean _median_=median  _nobs_=n  _nmiss_ =nmissing) );
        var &interval;
        histogram &interval / normal;
    run;

    data work.ve_utable;
        set work.ve_utable;
        type="num";
        pctmissing=round((nmissing/&is_nobs)*100, 0.01);
        if q1-1.5*qrange > min then outlow=q1-1.5*qrange;
        if q3+1.5*qrange <max then outup=q3+1.5*qrange;
        else normal=.;
    run;
%mend interval_stat;

%macro nominal_stat();
    ods select none;
    ods output OneWayFreqs=work.ve_freq NLevels=work.ve_level(rename=(tablevar=variable));
    proc freq data=&dn (
            %if %superq(keeplist) ne %then keep=&keeplist;
            %else %do;
                drop=
                %if %superq(exclu)  ne  %then &exclu;
                %if %superq(id)  ne  %then &id; 
            %end;
                ) nlevels;
        table _all_  /missing nocum /*plots=freqplot*/;
    run;
    ods output close;
    ods select all;

    %CombFreq(work.ve_freq)

    proc sort data=work.ve_freq;
        by variable;
    run;
    proc sort data=work.ve_level;
        by variable;
    run;
    data freq;
        length variable $ 32 missing 8;
        merge work.ve_freq work.ve_level;
        by variable;
    run;
%mend nominal_stat;
