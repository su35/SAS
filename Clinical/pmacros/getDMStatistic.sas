/* ***********************************************************************************************
     Name  : getDMStatistic.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: get the statistic data for a variable and out put the data to a temp dataset.
*    --------------------------------------------------------------------------------------------*
     Program type : subroutine     
*    --------------------------------------------------------------------------------------------*
     Parameters : indn       = one- or two-level data set name
                                             The default is ADSL.
                         variable  = The analysis variable
                         class       = The class variable in the statistic proc, usually be trt01pn/trtpn;
                                             The default is trt01pn.
                         pval        = The normal test pvalue.
                         stalist     = Required statistic data specified for the numeric variables;
                                            The default is n mean median min max.
                         outdn    = The out put DM report dataset.
                                            The default is dmreport
                         group    = The group number.
*   *********************************************************************************************/
%macro getDMStatistic(indn, variable, class, pval, stalist, outdn, group);
    %local i method cellmin;
    %if %superq(pval) ne %then %do; /*numeric variable*/
        %if  %eval(&pval>=0.05) %then %do; /*normal numeric variable, using ttest*/
            ods output equality=work.dms_ppvalue ttests=work.dms_pvalue;
            proc ttest data=&indn;
                class &class;
                var &variable;
            run;
            ods output close;

            /*According to the pvalue of the tests for equality of variance, 
            fetch the t-test pvalue and stored in macro variable pval.*/
            data _null_;
                set work.dms_ppvalue;
                call execute('data _null_; set work.dms_pvalue; where  upcase(method)=');
                if probf < 0.05 then call execute('"SATTERTHWAITE";');
                else call execute('"POOLED"; ');
                call execute('call symputx("pval", probt); run;');
            run;
        %end;
        %else %if  %eval(&pval<0.05) %then %do; /*abnormal numeric variable, using nopara analysis */
            proc npar1way  data = &indn   wilcoxon   noprint;
                class &class;
                var &variable;
                output out = work.dms_pvalue wilcoxon;
            run;

            /*fetch the nopara analysis pvalue and stored in macro variable pval.*/
            data _null_;
                set work.dms_pvalue;
                call symputx("pval", P2_wil);
            run;        
         %end;   

         /*get the statistic data for each term in stalist*/
          proc sort data=work.dms_&indn; 
                by &class;
          run;

          proc univariate data=work.dms_&indn noprint; 
                by &class;
                var &variable;
                output out=work.dms_&indn.temp &stalist;
          run;

          proc transpose data=work.dms_&indn.temp name = term 
                            out=work.dms_&indn.temp(drop=_LABEL_) prefix=ori; 
                id &class;
          run;

        data work.dms_label;
            length term $ 50 pvalue $ 8;
            term = "&variable";
            pvalue =put (&pval, d5.3-R);
        run;

        data &outdn;
            length  group 3 term $ 50 &class.0-&class.&trtlevel $20 ;
            /*The first obs read form dms_label*/
            set work.dms_label  work.dms_&indn.temp;
            array ori(*)  ori0-ori&trtlevel;
            array tar(*) $ &class.0-&class.&trtlevel;
            label pvalue= "P_value" term="Term";
            group =&group;
            if _n_ >1 then do; 
                if lowcase(term)="min" then term=cats("&blankno", "Minimum");
                else if lowcase(term)="max" then term=cats("&blankno", "Maximum");
                else term= cats("&blankno", propcase(term));
                do i=1 to dim(ori);
                    if index(put(ori0,best.),".") then tar[i]=put(ori[i], 8.1-L);
                    else tar[i]=put(ori[i], 8.-L);
                end;
            end;
            keep term group &class.0-&class.&trtlevel pvalue;
        run;
    %end;
    %else %do; /*char variable*/
        /*get pvalue */
        proc freq data=&indn noprint;
            where &class not is missing and &variable not is missing;
            table &variable*&class /chisq outpct nowarn out=work.dms_ptemp; /*Itls the option outpct，not the statement output*/
            output out= work.dms_pvalue pchi;
        run;
        proc sql noprint;
            select min(count) into : cellmin
                from work.dms_ptemp;
        quit;
        %if &cellmin < 5 %then %do;
            /*there are some counts less than 5, get fisher pvalue */
            proc freq data=&indn noprint;
                where &class not is missing and &variable not is missing;
                table &variable*&class /exact nowarn;
                output out= work.dms_pvalue exact;
            run;
            data _null_;
                set work.dms_pvalue;
                call symputx("pval", xp2_fish);
            run;
        %end;
        %else %do;
            data _null_;
                set work.dms_pvalue;
                call symputx("pval", P_PCHI);
            run;
        %end;

        /*Inferential statistics */
        proc freq data=work.dms_&indn noprint;
            where &class not is missing;
            table &class*&variable / missing outpct out=work.dms_&indn.temp; 
        run;

        /* Save the names that would be generated by following proc transpose into the macro variables 
        for variable order controlling.*/
        data work.dms_&indn.temp;
            set work.dms_&indn.temp;
            by &class;
            where &variable ne "";
            length value $ 20; /*those values will store in trtpn0 - trtpnN*/
            if count=0 then value="0";
            else  value=cats(count,'(', put(pct_row,5.1-L),'%)');
        run;

        proc sort data=work.dms_&indn.temp; 
            by &variable;
        run;
        proc transpose data=work.dms_&indn.temp 
                            out=work.dms_&indn.temp(drop=_name_) prefix=&class;
            var value;
            by &variable;
            id &class;
        run;
        data work.dms_label;
            length term $ 50 pvalue $ 8;
            term = "&variable";
            pvalue =put(&pval, d5.3-R);
        run;

        data &outdn; 
            length  group 3  term $ 50 &class.0-&class.&trtlevel $ 20; /*define the variable order in the dataset*/
            set work.dms_label work.dms_&indn.temp;
            label pvalue= "P_value" term="Term";
            group =&group;
            keep term &class.0-&class.&trtlevel pvalue group;
            /*add the indentation for report*/
            if _n_ >1 then term = "&blankno"||&variable;
        run;
    %end;
%mend getDMStatistic;
