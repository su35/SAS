/* ********************************************************************************************
* macro CheckMissing.sas: Ckeck are there missing values in SDTM required varailbles
* metadatafile: the file containing the dataset metadata. 
*       the default is the project folder\SDTM_METADATA.xlsx 
* dataset:  the dataset or domain name. the default is empty which means all dataset
* random: dataset that include the usubjid which had been assinged treatment only
* complete: dataset that include the usubjid which have completed only
* exclu: variable list that would be ignored.
* ********************************************************************************************/
%macro CheckMissing(metadatafile=,dataset=, random=, complete=, exclu=);
    %if %superq(metadatafile)= %then %let metadatafile=&pdir.sdtm_metadata.xlsx;
    %if %superq(random)= %then %let random=random;
    %if %superq(complete)= %then %let complete=complete;
    %if %sysfunc(libref(sdtmfile)) ne 0 %then  
            libname sdtmfile "&metadatafile";;
    %if %superq(dataset)^=  %then %StrTran(dataset);
    %if %superq(exclu)^=  %then %StrTran(exclu);

    options nonotes;
/*    proc sql;*/
/*        create table work.cm_missing*/
/*          (*/
/*           domain char(6),*/
/*           variable char(32),*/
/*           frequency num,*/
/*           percent num,*/
/*           rand_miss num,*/
/*           compl_miss num*/
/*          );*/
/*    quit;*/

    /*get the required varailbles list grouping by domain*/
    proc sort data=sdtmfile."VARIABLE_METADATA$"n 
                    (keep=domain variable label mandatory) 
                    out=work.cm_mandatory;
        by domain;
        where upcase(mandatory) in ("YES", "Y")
            %if %superq(dataset)^= %then and upcase(domain) in (%upcase(&dataset));
            %if %superq(exclu) ne %then and upcase(variable) not in (%upcase(&exclu));
            ;
    run;

    %local dnum i j;

    data _null_;
        set work.cm_mandatory end=eof;
        by domain;
        length vlist $1000;
        retain n 1  vlist;
        
        vlist=catx(" ", vlist, variable);
        if last.domain then do;
            call symputx("cm_dm"||left(n), domain);
            call symputx("cm_vlist"||left(n), vlist);
            vlist="";
            n+1;
        end;
        if eof then call symputx("dnum", n-1);
    run;

    /*Check the missing.*/
    proc format;
         value $cmisscnt    " "   = "CMissing"
                            other = "Nonmissing";
        value   nmisscnt     .="NMissing"
                            other="Nonmissing";
    run;

    %do i=1 %to &dnum;
        proc sql;
            create table work.cm_tset as
            select a.*, case when b.usubjid then 1 else . end as random, 
                    case when c.usubjid then 1 else . end as complete
            from &&cm_dm&i as a left join  (select usubjid from &random) as b 
                on a.usubjid=b.usubjid left join
                (select usubjid from &complete) as c
                on a.usubjid=c.usubjid;
        quit;

        ods exclude onewayfreqs;
        ods output OneWayFreqs=work.cm_freq1 ;
        proc freq data=work.cm_tset;
            table &&cm_vlist&i /missing;
            format _character_   $cmisscnt. _numeric_ nmisscnt. ;
       run;

        ods exclude onewayfreqs;
        ods output OneWayFreqs=work.cm_freq2 ;
        proc freq data=work.cm_tset;
            table &&cm_vlist&i /missing;
            where random=1;
            format _character_   $cmisscnt. _numeric_ nmisscnt. ;
        run;

        ods exclude onewayfreqs;
        ods output OneWayFreqs=work.cm_freq3 ;
        proc freq data=work.cm_tset;
            table &&cm_vlist&i /missing;
            where complete=1;
            format _character_   $cmisscnt. _numeric_ nmisscnt. ;
        run;
        ods output close;
        %CombFreq(work.cm_freq1)
        %CombFreq(work.cm_freq2)
        %CombFreq(work.cm_freq3)

        data work.cm_freq2(index=(variable));
            set work.cm_freq2;
            rename frequency=rand_miss percent=rand_pect;
            where value in("NMissing","CMissing");
            drop missing;
        run;

        data work.cm_freq3(index=(variable));
            set work.cm_freq3;
            rename frequency=compl_miss percent=compl_pect;
            where value in("NMissing","CMissing");
            drop missing;
        run;

        data work.cm_freq;
            length domain $ 6 variable $ 32;
            domain="&&cm_dm&i";
            set work.cm_freq1(drop=missing);
            where value in("NMissing","CMissing");
            call missing(rand_miss, rand_pect, compl_miss, compl_pect);
           set work.cm_freq2 key=variable;
            set work.cm_freq3 key=variable;
            drop value;
            _error_=0;
        run;

        proc sort data=work.cm_freq %if  &i=1 %then out=work.cm_missing; ;
            by percent;
        run;

        %if &i ne 1 %then %do; 
            proc append base=work.cm_missing data=work.cm_freq force;
            run;
        %end;

    %end;

    title "The missing of required variables";
    proc print data = work.cm_missing;
    run;
    title;

    proc datasets lib=work noprint;
        delete cm_: ;
    run;
    quit;

    options notes ;

%mend CheckMissing;

