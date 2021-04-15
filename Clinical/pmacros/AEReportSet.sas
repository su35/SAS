/* ***********************************************************************************************
     Name  : AEReportSet.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: Create Adverse Events report dataset for report.
*    --------------------------------------------------------------------------------------------*
     Parameters : indn    = one- or two-level data set name. 
                                            The default is ADAE
                         outdn  = The out put DM report dataset.
                                            The default is dmreport
*   *********************************************************************************************/
%macro AEReportSet(indn, outdn);
    %if %superq(indn)= %then  %let indn=adae;
    %if %superq(outdn)= %then  %let outdn=aereport;
    %if %symglobl(blankno)=0 %then %let blankno=&#160%str(;) ;
    %local i j k group totalsub trtlevel sevlevel1 sevlevel2 sevlevel3 socnum;
    %let group =1;

    proc sql noprint;
        select count(usubjid)
            into : totalsub trimmed
            from adsl;
             
        select count(distinct trtan), min(trtan), max(trtan), count(distinct aesev)
            into  :trtlevel trimmed, :minlev trimmed, :maxlev trimmed, :sevnum
            from &indn;

        /*sevlevel including 3 value: Mild, Moderate, and Severe*/
        select distinct aesev into  :sevlevel1- :sevlevel&sevnum
            from &indn
            order by aesev;

        select distinct aesoc into  :ass_soc1-
            from &indn;
        %let socnum=&sqlobs;

        /*count the total by trt */
        select 
            %do i=&minlev %to &maxlev;
                cats(sum (ifn(trtan= &i, 1, 0 )))
                %if &i ne &maxlev %then %str(,);
            %end;
            into %do i=&minlev %to &maxlev;
                :sub&i %if &i ne &maxlev %then %str(,);
            %end;
            from &indn; 

        %if %sysfunc(exist(&outdn)) %then drop table &outdn; 
    quit;

    /*get statistic data for each aesoc*/
    %do i=1 %to &socnum;
        /*count the aesev group by level and trt*/
        proc sql;
            create table work.aesev as
            select count(usubjid) as tatol, 
            %do j = &minlev %to %eval(&maxlev+1);
                %if &j=&trtlevel %then %do;
                    sum(ifn(aesev= "MILD", 1, 0)) as Mild&j,
                    sum(ifn(aesev= "MODERATE", 1, 0)) as Moderate&j,
                    sum(ifn(aesev= "SEVERE", 1, 0)) as Severe&j /*this is the last line, without ','*/
                %end;
                %else %do;
                    sum(ifn(aesev= "MILD" and trtan = &j, 1, 0)) as Mild&j,
                    sum(ifn(aesev= "MODERATE" and trtan = &j, 1, 0)) as Moderate&j,
                    sum(ifn(aesev= "SEVERE" and trtan = &j, 1, 0)) as Severe&j,
                %end;
            %end;
            from  
                (select usubjid, aesev, trtan 
                    from &indn 
                    where aesoc = "&&ass_soc&i" 
                    group by aesev 
                    having max(aesev));
        quit;

        data work.term;
            length group 3 term $ 85 trtan&minlev-trtan%eval(&maxlev+1) $ 15;
            keep group term trtan&minlev-trtan%eval(&maxlev+1);
            set work.aesev;
            array sub(%eval(&trtlevel+1))  _temporary_ (
                %do j=&minlev %to &maxlev;
                            &&sub&j%str(,)
                %end; &totalsub);
            group=&group;

            %do k=0 %to &sevnum; /*total plus Mild, Moderate and Severe*/
                %if &k=0 %then %do;/*first line is total*/
                    term = "&&ass_soc&i";
                    /*including total, number of  iteration equal to the trtlevel +1*/
                    %do j= &minlev %to %eval(&trtlevel+&minlev); 
                        %let n = %eval(&j+1);
                        temp=sum(mild&j, Moderate&j,Severe&j);
                        if temp=0 then trtan&j = cats(temp);
                        else trtan&j = cats(temp)||' ('|| cats(put(divide(temp*100,sub[1]),5.2),'%)');
                        /*using the || to keep a blank before the (*/
                    %end;
                    output;
                %end;
                %else %do;
                    term = "&blankno"||"&&sevlevel&k";/*sevlevel including Mild, Moderate and Severe*/
                    %do j=&minlev %to %eval(&maxlev+1);  
                        %let n = %eval(&j+1);
                        if &&sevlevel&k&&j=0 then trtan&j = cats(&&sevlevel&k&&j);
                        else trtan&j = cats(&&sevlevel&k&&j)||' ('|| 
                                             cats(put(divide(&&sevlevel&k&&j*100,sub[&n]), 5.2),'%)');;
                    %end;
                    output;
                %end;
            %end; 
        run;
        proc append base=&outdn data=work.term; 
        run;
        %let group=%eval(&group+1);
    %end;
    
    %put NOTE:  ==The dataset &outdn was created.==;
    %put NOTE:  ==The macro AEReportSet executed completed.== ;
%mend AEReportSet;
