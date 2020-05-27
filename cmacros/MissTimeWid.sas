/* check the number of the month between the start point 
*  and the time point that the nonmissing happen
*  paras: 
*  dn: the name of the dataset
*  vars: the variable list that would be checked
*  timevar: the varible that hold the start point and time point and its format would
*           datetime or date class.
*   speed: if speed set to a non-zero, 
                then use mpconnect to run code in parallel on the different processors
*   numCPU: if speed set to a non-zero, specify how many CPU would be used. 
*                       if the numCPU not be set, then all the CPU would be used*/
%macro MissTimeWid(dn, vars, timevar, speed=0, numCPU=);
    %if %superq(dn)= or %superq(vars)= %then %do;
        %put ERROR: == The dataset name or the variable list is missing ==;
        %return;
    %end;
    
    %local varn i var start fm;
    %let varn=%sysfunc(countw(&vars));
    options nonotes;
    proc sql noprint;
        select min(&timevar)  into :start
        from &dn;

        select format into :fm
        from dictionary.columns
        where libname=upcase("&pname") and memname=upcase("&dn")
                and name="&timevar";
    quit;
    %if &speed=0 %then 
        %do;
            proc sql;
                create table work.misswid as
                %do i=1 %to &varn;
                    %let var=%scan(&vars, &i);
                    select "&var" as variable, min(&timevar) as timepoint 
                        from &dn 
                        where &var is not missing %if &i^=&varn %then union;
                                            %else %str(;);
                %end;
            quit;
        %end;
    %else %do;
        %if %superq(numCPU)= %then %let numCPU = &sysncpu; 
        %let lib=%sysfunc(splitdn(&dn, lib));
        %let rdn=%sysfunc(splitdn(&dn, set));
        %if %superq(lib)= %then %let lib=%sysfunc(getoption(user));

        options sascmd="!sascmd"; 
        %do i=1 %to &numCPU;
            %let j=0;
            %let code=create table pwork.mtw_misswid&i as ;
            %if &varn>&numCPU %then 
                %do %until(%superq(var)= );
                    %let var=%scan(&vars, %eval(&i+&j*&numCPU), %str( ));
                    %if %superq(var) ne %then %do;
                        %if &j ne 0 %then %let code=%str(&code)   union;
                        %let  code=%str(&code)   %str(select "&var" as variable, min(&timevar) as timepoint 
                            from &rdn 
                            where &var is not missing);
                    %end;
                    %else %let code=%str(&code ;) ;
                    %let j=%eval(&j+1);
                %end;
            %else %do;
                %let var=%scan(&vars, &i, %str( )) ;
                %let code=%str(&code) %str(select "&var" as variable, min(&timevar) as timepoint 
                        from &rdn 
                        where &var is not missing;);
            %end;
            signon session&i;  

            %syslput session = &i / remote = session&i;
            %syslput ruser = &lib / remote = session&i;
            %syslput rcode=%str(&code) / remote = session&i;

            rsubmit session&i wait = no inheritlib = (work = pwork 
                                                %if &lib ne work %then &lib = &lib; ); 
                options user=&ruser;
                proc sql;
                    &rcode
                quit;
            endrsubmit;
        %end;

         waitfor _all_        
             %do i = 1 %to &numCPU; 
                session&i 
             %end; 
             ; 
 
        signoff _all_;  

        data misswid;
            set %do i= 1 %to &numCPU;
                     work.mtw_misswid&i
                  %end;
                    ;
        run;

        proc datasets lib=work noprint;
        delete mtw_: ;
        run;
        quit;
    %end;

    data misswid;
        set misswid;
        start=&start;
        %if &fm=DATETIME. %then %do;
            start=datepart(start);
            timepoint=datepart(timepoint);
        %end;
        format timepoint start date9.;
        label timepoint="First Nomissing";
        monthinterval= intck ('MONTH', start, timepoint);
    run;

    proc sort data=misswid;
        by monthinterval variable;
    run;
    options notes;
    %put NOTE: == The macro MissTimeWid executed completed. ==;
    %put NOTE: == The result was stored in misswid. ==;
%mend MissTimeWid;
