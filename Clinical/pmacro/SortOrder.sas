/* *******************************************************************************************
* SortOrder.sas 
* sorting the SDTM dataset according to the KEYSEQUENCE metadata
* specified sort order for a given dataset.
* if there is a __seq variable in a dataset, then create the __seq value for it
*
* MACRO PARAMETERS:
*   metadatafile = the file containing the dataset metadata. 
*       the default is the project folder\SDTM_METADATA.xlsm 
*   dataset = the dataset or domain name, the default is empty which means all dataset
* ********************************************************************************************/
%macro SortOrder(metadatafile, dataset=)/minoperator ;
    %local i dmlist dmnum seqdm;

    %if %superq(metadatafile)= %then 
            %let  metadatafile=&pdir.SDTM_METADATA.xlsm;
    %else %if %index(metadatafile, \)=0 or %index(metadatafile, /) =0 %then 
            %let metadatafile=&pdir.&metadatafile;

    libname templib xlsx "&metadatafile";

    data work.so_temp;
        set templib.VariableLevel (keep=domain variable keysequence);
    run;

    libname templib clear;

    %if %superq(dataset)^=  %then %StrTran(dataset);
    proc sql noprint;
        select distinct domain
            into :dmlist separated " "
            from work.so_temp
            %if %superq(dataset)^= %then where upcase(domain) in (%upcase(&dataset));
            ;
        %let dmnum=&sqlobs;

        select domain
            into : seqdm separated ' '
            from work.so_temp
            where variable like "__SEQ"
            %if %superq(dataset)^= %then and upcase(domain) in (%upcase(&dataset));
            ;
    quit;
    
    %do i = 1 %to &dmnum;
        %let dataset = %scan(&dmlist, &i, ' ' ); 
        proc sort
            data=work.so_temp out=work.so_settemp;
            where not missing(keysequence) and domain=upcase("&dataset");
            by keysequence;
        run;

        /** sorting dataset;*/
        data _null_;
            set work.so_settemp end=eof;
            length domainkeys $ 200;
            retain domainkeys '';

            domainkeys = catx(" ", domainkeys, variable); 

            if eof then  call symputx("SORTSTRING", domainkeys);
        run;
        proc sort data=&dataset;
            by &SORTSTRING;
        run;

        /*add seq value */
        %if &dataset in (&seqdm) %then %do;
            data &dataset;
                set &dataset;
                by usubjid;
                retain seq;
                if first.usubjid then seq = 0 ;
                seq + 1;
                &dataset.seq = seq;
                drop seq;
            run;
        %end;
    %end;
    proc datasets lib=work noprint;
        delete so_: ;
    run;
    quit;

    %put NOTE:  ==The SortOrder executed completed.== ;
%mend SortOrder;
