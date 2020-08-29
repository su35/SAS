/*Macro CharValChk: check whether the value of long length char variable is free text
*  dn: the name of the dataset
*  vars: the variable list which would be check
*  nobs: define how may obs would be check 
* method: if=1, then just quickly print the limited value.
*                if=2, then create a subset when num of obs over 50000.
*                if=3, use mpconnect to run code in parallel on the different processors*/
%macro CharValChk(dn, vars, outobs=50, method=1);
    %local i j varn val nobs lib numCPU session code;

    %if %superq(vars) = %then %let vars=_char_;
    %parsevars(&dn, vars)
    %let varn=%sysfunc(countw(&vars));

    %if &method=1 %then %do;
        %do i=1 %to &varn;
            %let val=%scan(&vars, &i);
            title "&val";
            proc print data=&dn (obs=&outobs);
            var &val;
            where &val is not missing;
            run;
        %end;
        title;
        %return;
    %end;
    %else %if &method=2 %then %do;
        data _null_;
            set &dn nobs=obs;
            call symputx("nobs", obs);
            stop;
        run;

        /*randomly subsetting*/
        %if &nobs>50000 %then %do;
            proc surveyselect data=&dn out=work.cvc_dn sampsize=10000 noprint;
            run;
            %let dn=work.cvc_dn; 
        %end;

        /*create the temporary dataset*/
        proc sql ;
            %do i=1 %to &varn;
                %let var=%scan(&vars, &i);
                create table work._&var as
                select distinct (&var)
                from &dn
                where &var is not missing;
            %end;
        quit;

        /*output result*/
        %do i=1 %to &varn;
            %let var=%scan(&vars, &i);
            title1 "The first &outobs.th distinct &var values";
            title2 "The full data stored in work._&var";
   
            proc print data=work._&var (obs=&outobs);
            run;
        %end;
        title1;
        title2;
    %end;
    %else %if &method=3 %then %do;
        %let numCPU = &sysncpu; 
        %let lib=%sysfunc(splitdn(&dn, lib));
        %let rdn=%sysfunc(splitdn(&dn, set));
        %if %superq(lib)= %then %let lib=%getLib;

        /*starts a server session*/
        options sascmd="!sascmd"; 

        %do i=1 %to %sysfunc(min(&numCPU, &varn));
            %let j=0;
            %let code= ;

            /*prepare the code that would be run on the different processors */
            %if &varn>&numCPU %then 
                %do %until(%superq(var)= );
                    %let var=%scan(&vars, %eval(&i+&j*&numCPU), %str( ));
                    %if %superq(var) ne %then %let 
                        code=%str(&code)  %str(create table pwork._&var as
                            select distinct (&var)
                            from &rdn
                            where &var is not missing;);
                    %let j=%eval(&j+1);
                %end;
            %else %do;
                %let var=%scan(&vars, &i, %str( )) ;
                %let code=%str(create table pwork._&var as
                            select distinct (&var)
                            from &dn
                            where &var is not missing;);
            %end;

            signon session&i;  

            %syslput session = &i / remote = session&i;
            %syslput ruser = &lib / remote = session&i;
            %syslput routobs=&outobs / remote = session&i;
            %syslput rcode=%str(&code) / remote = session&i;

            /*submit to the server session*/
            rsubmit session&i wait = no inheritlib = (work = pwork 
                                                %if &lib ne work %then &lib = &lib; ); 
                options user=&ruser;
                proc sql;
                    &rcode
                quit;
            endrsubmit;
        %end;

         waitfor _all_        
             %do i = 1 %to %sysfunc(min(&numCPU, &varn));; 
                session&i 
             %end; 
             ; 
 
        signoff _all_;  

        %do i=1 %to &varn;
            %let var=%scan(&vars, &i);
            title1 "The first &outobs.th distinct &var values";
            title2 "The full data stored in work._&var";
   
            proc print data=work._&var (obs=&outobs);
            run;
        %end;
        title1;
        title2;
    %end;


    proc datasets lib=work noprint;
    delete cvc_: ;
    run;
    quit;
%mend CharValChk;
