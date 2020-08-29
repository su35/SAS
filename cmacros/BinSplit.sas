/* *********************************************************************************************/
* macro BinSplit: Discretize the interval variables and collaspsing the levels of 
* the ordinal and nominal variables by proc split;
/* **********************************************************************************************/
%macro BinSplit();
    %if %superq(interval)^= %then %bin_num(&interval, interval);
    %if %superq(ordinal)^= %then %bin_num(&ordinal, ordinal);
    %if %superq(nominal)^= %then %bin_nom(&nominal);

%mend BinSplit;
%macro bin_num(vlist, level);
    %local i;
    %let nvars=%sysfunc(countw(&vlist));
    %do i=1 %to &nvars;
        %let var=%scan(&vlist, &i, %str( ));
        proc split data=&dn(keep=&target &var) outtree=work.bs_tree excludemiss
                    leafsize=&leafsize /*criterion=chisq excludemiss*/;
            input &var/level=interval;
            target &target/level=&t_class;
            score out=work.bs_score(keep=&var);
        run;
        proc sort data=work.bs_tree out=work.bs_tree(keep=y rename=(y=border));
            by y;
           where label="<";
        run;

        %if &level=ordinal %then %do;
            proc sql;
                update work.bs_tree
                set border=(select min(&var) from work.bs_score where &var >border );
            quit;
        %end;

        data work.bs_tree;
            length variable d_var $32 class branch $8 cluster $1000;
            set work.bs_tree end=eof;
            variable="&var";
            class="&level";
            d_var="b_"||substr(variable, 1, 30);
            cluster="";
            bin=.;
            branch="spl";
            if eof then nlevels=_N_+1;
        run;

        proc sql;
            delete from &outdn
            where variable="&var" and branch="spl";
        quit;

        proc append base=work.bv_tree data=work.bs_tree force;
        run;
    %end;
%mend bin_num;
%macro bin_nom(vlist);
    %Local i j total total_pos total_neg vartype  nobs;
    proc sql noprint;
        select sum(case when &target=%if &t_type=num %then &pos;
                                            %else "&pos"; then 1 else 0 end),
                count(&target)
        into :total_pos,  :total
        from &dn (keep=&target);
    quit;
    %let total_neg=%eval(&total-&total_pos);

    %let nvars=%sysfunc(countw(&vlist));
    %do i=1 %to &nvars;
        %let var=%scan(&vlist, &i, %str( ));
        proc sort data=&dn(keep=&target &var) out=work.bs_&dn;
            by &var;
        run;
        ods exclude OneWayFreqs;
        ods output OneWayFreqs=work.bs_freq;
        proc freq data=work.bs_&dn;
            by &var;
            table &target;
        run;
        ods output close;
        /*calculate the woe*/
        proc sql noprint;
            create table work.bs_freq1 as
            select a.*, b.pos, &total_pos as total_pos, &total_neg as total_neg, &total as total
            from (select distinct &var, sum(Frequency) as Freq 
                from work.bs_freq group by &var) as a left join
                 (select &var,frequency as pos from work.bs_freq where &target=
                    %if &t_type=num %then &pos; %else "&pos";) as b 
                on a.&var=b.&var;

            select type
            into :vartype
            from dictionary.columns
            where libname="WORK" and memname="BS_FREQ1" and name="&var";
        quit;
            
        data work.bs_freq1;
            set work.bs_freq1;
            label pos_rate = "Positive Rate(%)";

            if pos=0 then pct_pos=0.5/total_pos;
            else pct_pos=pos/total_pos;
            if pos = freq then pct_neg=0.5/total_neg;
            else pct_neg=(freq-pos)/total_neg;

            pos_rate = pos / freq;
            odds=pct_neg/pct_pos;
            woe = log(odds);
            iv= (pct_neg-pct_pos)*woe;
            format pos_rate 10.4;
        run;

        proc sort data=work.bs_freq1;
            by &var;
        run;

        data work.bs_&dn;
            merge work.bs_&dn work.bs_freq1(keep=&var woe);
            by &var;
        run;

        proc split data=work.bs_&dn criterion=chisq leafsize=&leafsize outtree=work.bs_tree excludemiss;
            input woe/level=interval;
            target &target/level=&t_class;
        run;

        proc sort data=work.bs_tree out=work.bs_tree2(keep=y);
            by y;
            where  label='<';
        run;
        data _null_;
            set work.bs_tree2 nobs=obs; 
            if _N_=1 then call symputx("nobs", obs);
            call symputx("border"||left(_N_), y);
        run;

        data work.bs_bin;
            set work.bs_freq1 (keep=&var woe);
            select;
            %do j=1 %to &nobs;
                when (woe <&&border&j) bin=&j;
            %end;
                otherwise bin=%eval(&nobs+1);
            end;
        run;
        proc sort data=work.bs_bin;
            by bin;
        run;

        data work.bs_bin;
            length variable d_var $32 class branch $8  cluster $1000;
            set work.bs_bin end=eof;
            by bin;
            retain cluster;
            variable="&var";
            class="nominal";
            d_var="c_"||substr(variable, 1, 30);
            if first.bin then cluster=" ";
            cluster=catx(" ", cluster, quote(trim(%if &vartype=num %then left(&var); 
                                                    %else&var; )));
            border=.;
            branch="spl";
            if eof then nlevels=bin;
            if last.bin then output;
            drop &var woe;
        run;

        proc sql;
            delete from &outdn
            where variable="&var" and branch="spl";
        quit;

        proc append base=work.bv_tree data=work.bs_bin force;
        run;

        %let bv_nobs=;
    %end;
%mend bin_nom;
