/*Macro CharValChk: check the value of long length char variable is free text
*  dn: the name of the dataset
*  vars: the variable list which would be check
*  nobs: define how may obs would be check 
*  speed: if=0, then create a subset when num of obs over 50000.
*              if=1, then just quickly print the limited value.
*              if=2, use mpconnect to run code in parallel on the different processors*/
%macro CharValChk(dn, vars, outobs=50, speed=0);
    %local i j varn val nobs lib numCPU session code;

    %let varn=%sysfunc(countw(&vars));
    %if &speed=1 %then %do;
        %do i=1 %to &varn;
            %let val=%scan(&vars, &i);
            proc print data=&dn (obs=&outobs);
            var &val;
            where &val is not missing;
            run;
        %end;
        %return;
    %end;

    %if &speed=2 %then %do;
        %let numCPU = &sysncpu; 
        %let lib=%sysfunc(splitdn(&dn, lib));
        %let rdn=%sysfunc(splitdn(&dn, set));
        %if %superq(lib)= %then %let lib=%sysfunc(getoption(user));

        options sascmd="!sascmd"; 

        %do i=1 %to &numCPU;
            %let j=0;
            %let code= ;
            %if &varn>&numCPU %then 
                %do %until(%superq(var)= );
                    %let var=%scan(&vars, %eval(&i+&j*&numCPU), %str( ));
                    %if %superq(var) ne %then %let 
                        code=%str(&code)  %str(title "The first &outobs.th distinct &var values";
                            select distinct (&var)
                            from &rdn
                            where &var is not missing;);
                    %let j=%eval(&j+1);
                %end;
            %else %do;
                %let var=%scan(&vars, &i, %str( )) ;
                %let code=%str(title "The first &outobs.th distinct &var values";
                            select distinct (&var)
                            from &dn
                            where &var is not missing;);
            %end;
            signon session&i;  

            %syslput session = &i / remote = session&i;
            %syslput ruser = &lib / remote = session&i;
            %syslput routobs=&outobs / remote = session&i;
            %syslput rcode=%str(&code) / remote = session&i;

            rsubmit session&i wait = no inheritlib = (work = pwork 
                                                %if &lib ne work %then &lib = &lib; ); 
                options user=&ruser;
                proc sql outobs=&routobs;
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
    %end;
    %else %do;
        data _null_;
            set &dn nobs=obs;
            call symputx("nobs", obs);
            stop;
        run;
        %if &nobs>50000 %then %do;
            proc surveyselect data=&dn out=work.cvc_dn sampsize=10000 noprint;
            run;
            %let dn=work.cvc_dn; 
        %end;

          proc sql outobs=&outobs;
             %do i=1 %to &varn;
                %let var=%scan(&vars, &i);
                title "The first &outobs.th distinct &var values";
                select distinct (&var)
                from &dn
                where &var is not missing;
             %end;
          quit;
          title;
    %end;

    proc datasets lib=work noprint;
    delete cvc_: ;
    run;
    quit;
%mend CharValChk;
