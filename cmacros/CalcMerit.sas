/*call by %CalcMerit()*/
%macro CalcMerit(BinDS, ix, method, M_Value);
    /* 使用评估函数计算候选分段的当前位置。所有节点在这或上面都合并到一起，最后分箱会变大起来 */
    /*  利用SQL查找列联表的频数  */
    %local n_11 n_12 n_21 n_22 n_1s n_2s n_s1 n_s2;

    proc sql noprint;
        select sum(Ni1) into :n_11 from &BinDS where i<=&ix;
        select sum(Ni1) into :n_21 from &BinDS where i> &ix;
        select sum(Ni2) into : n_12 from &BinDS where i<=&ix;
        select sum(Ni2) into : n_22 from &binDS where i> &ix;
        select sum(total) into :n_1s from &BinDS where i<=&ix;
        select sum(total) into :n_2s from &BinDS where i> &ix;
        select sum(Ni1) into :n_s1 from &BinDS;
        select sum(Ni2) into :n_s2 from &BinDS;
    quit;

    /* 根据类型计算评估函数 */
    /* The case of Gini */
    %if (&method=1) %then
        %do;
            %local N G1 G2 G Gr;
            %let N=%eval(&n_1s+&n_2s);
            %let G1=%sysevalf(1-(&n_11*&n_11+&n_12*&n_12)/(&n_1s*&n_1s));
            %let G2=%sysevalf(1-(&n_21*&n_21+&n_22*&n_22)/(&n_2s*&n_2s));
            %let G =%sysevalf(1-(&n_s1*&n_s1+&n_s2*&n_s2)/(&N*&N));
            %let GR=%sysevalf(1-(&n_1s*&G1+&n_2s*&G2)/(&N*&G));
            %let &M_value=&Gr;

            %return;
        %end;

    /* The case of Entropy */
    %if (&method=2) %then
        %do;
            %local N E1 E2 E Er;
            %let N=%eval(&n_1s+&n_2s);
            %let E1=%sysevalf(-( (&n_11/&n_1s)*%sysfunc(log(%sysevalf(&n_11/&n_1s))) + 
                (&n_12/&n_1s)*%sysfunc(log(%sysevalf(&n_12/&n_1s)))) / %sysfunc(log(2)) );
            %let E2=%sysevalf(-( (&n_21/&n_2s)*%sysfunc(log(%sysevalf(&n_21/&n_2s))) + 
                (&n_22/&n_2s)*%sysfunc(log(%sysevalf(&n_22/&n_2s)))) / %sysfunc(log(2)) );
            %let E =%sysevalf(-( (&n_s1/&n  )*%sysfunc(log(%sysevalf(&n_s1/&n   ))) + 
                (&n_s2/&n  )*%sysfunc(log(%sysevalf(&n_s2/&n   )))) / %sysfunc(log(2)) );
            %let Er=%sysevalf(1-(&n_1s*&E1+&n_2s*&E2)/(&N*&E));
            %let &M_value=&Er;

            %return;
        %end;

    /* The case of X2 pearson statistic */
    %if (&method=3) %then
        %do;
            %local m_11 m_12 m_21 m_22 X2 N i j;
            %let N=%eval(&n_1s+&n_2s);
            %let X2=0;

            %do i=1 %to 2;
                %do j=1 %to 2;
                    %let m_&i.&j=%sysevalf(&&n_&i.s * &&n_s&j/&N);
                    %let X2=%sysevalf(&X2 + (&&n_&i.&j-&&m_&i.&j)*(&&n_&i.&j-&&m_&i.&j)/&&m_&i.&j  );
                %end;
            %end;

            %let &M_value=&X2;

            %return;
        %end;

    /* The case of the information value */
    %if (&method=4) %then
        %do;
            %local IV;
            %let IV=%sysevalf( ((&n_11/&n_s1)-(&n_12/&n_s2))*%sysfunc(log(%sysevalf((&n_11*&n_s2)/(&n_12*&n_s1)))) 
                +((&n_21/&n_s1)-(&n_22/&n_s2))*%sysfunc(log(%sysevalf((&n_21*&n_s2)/(&n_22*&n_s1)))) );
            %let &M_Value=&IV;

            %return;
        %end;
%mend;
