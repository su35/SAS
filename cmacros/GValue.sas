/*call by %BinOpt*/
%macro GValue(BinDS, Method, M_Value);
    /* 计算当前拆分的值 */
    /* 提取频率表中的值 */
    proc sql noprint;
        /* Count the number of obs and categories of X and Y */
        %local i j R N; /* C=2, R=Bmax+1 */
        select max(bin) into : R from &BinDS;
        select sum(total) into : N from &BinDS;

        /* extract n_i_j , Ni_star*/
        %do i=1 %to &R;
            %local N_&i._1 N_&i._2 N_&i._s N_s_1 N_s_2;
            Select sum(Ni1) into :N_&i._1 from &BinDS where Bin =&i;
            Select sum(Ni2) into :N_&i._2 from &BinDS where Bin =&i;
            Select sum(Total) into :N_&i._s from &BinDS where Bin =&i;
            Select sum(Ni1) into :N_s_1 from &BinDS;
            Select sum(Ni2) into :N_s_2 from &BinDS;
        %end;
    quit;

    %if (&method=1) %then
        %do;
            /* Gini */
            /* substitute in the equations for Gi, G */
            %do i=1 %to &r;
                %local G_&i;
                %let G_&i=0;

                %do j=1 %to 2;
                    %let G_&i = %sysevalf(&&G_&i + &&N_&i._&j * &&N_&i._&j);
                %end;

                %let G_&i = %sysevalf(1-&&G_&i/(&&N_&i._s * &&N_&i._s));
            %end;

            %local G;
            %let G=0;

            %do j=1 %to 2;
                %let G=%sysevalf(&G + &&N_s_&j * &&N_s_&j);
            %end;

            %let G=%sysevalf(1 - &G / (&N * &N));

            /* finally, the Gini ratio Gr */
            %local Gr;
            %let Gr=0;

            %do i=1 %to &r;
                %let Gr=%sysevalf(&Gr+ &&N_&i._s * &&G_&i / &N);
            %end;

            %let &M_Value=%sysevalf(1 - &Gr/&G);

            %return;
        %end;

    %if (&Method=2) %then
        %do;
            /* Entropy */
            /* Check on zero counts or missings */
            %do i=1 %to &R;
                %do j=1 %to 2;
                    %local N_&i._&j;

                    %if (&&N_&i._&j=.) or (&&N_&i._&j=0) %then
                        %do ; /* return a missing value */
                            %let &M_Value=.;

                            %return;
                        %end;
                %end;
            %end;

            /* substitute in the equations for Ei, E */
            %do i=1 %to &r;
                %local E_&i;
                %let E_&i=0;

                %do j=1 %to 2;
                    %let E_&i = %sysevalf(&&E_&i - (&&N_&i._&j/&&N_&i._s)*%sysfunc(log(%sysevalf(&&N_&i._&j/&&N_&i._s))) );
                %end;

                %let E_&i = %sysevalf(&&E_&i/%sysfunc(log(2)));
            %end;

            %local E;
            %let E=0;

            %do j=1 %to 2;
                %let E=%sysevalf(&E - (&&N_s_&j/&N)*%sysfunc(log(&&N_s_&j/&N)) );
            %end;

            %let E=%sysevalf(&E / %sysfunc(log(2)));

            /* finally, the Entropy ratio Er */
            %local Er;
            %let Er=0;

            %do i=1 %to &r;
                %let Er=%sysevalf(&Er+ &&N_&i._s * &&E_&i / &N);
            %end;

            %let &M_Value=%sysevalf(1 - &Er/&E);

            %return;
        %end;

    %if (&Method=3) %then
        %do;
            /* The Pearson's X2 statistic */
            %local X2;
            %let N=%eval(&n_s_1+&n_s_2);
            %let X2=0;

            %do i=1 %to &r;
                %do j=1 %to 2;
                    %local m_&i._&j;
                    %let m_&i._&j=%sysevalf(&&n_&i._s * &&n_s_&j/&N);
                    %let X2=%sysevalf(&X2 + (&&n_&i._&j-&&m_&i._&j)*(&&n_&i._&j-&&m_&i._&j)/&&m_&i._&j  );
                %end;
            %end;

            %let &M_value=&X2;

            %return;

        %end; /* end of X2 */

    %if (&Method=4) %then
        %do;
            /* Information value */
            /* substitute in the equation for IV */
            %local IV;
            %let IV=0;

            /* first, check on the values of the N#s */
            %do i=1 %to &r;
                %if (&&N_&i._1=.) or (&&N_&i._1=0) or 
                    (&&N_&i._2=.) or (&&N_&i._2=0) or
                    (&N_s_1=) or (&N_s_1=0)    or  
                    (&N_s_2=) or (&N_s_2=0) %then
                    %do ; /* return a missing value */
                        %let &M_Value=.;

                        %return;
                    %end;
            %end;

            %do i=1 %to &r;
                %let IV = %sysevalf(&IV + (&&N_&i._1/&N_s_1 - &&N_&i._2/&N_s_2)*%sysfunc(log(%sysevalf(&&N_&i._1*&N_s_2/(&&N_&i._2*&N_s_1)))) );
            %end;

            %let &M_Value=&IV;
        %end;
%mend;

