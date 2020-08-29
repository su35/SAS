/*  **********************************************************************************
**  macro reLenVars: relenght the length of the char type variables.
**      When read data from PC files, espacilly form access file, the the lenght of 
**      char type variable may too long. This macro relenght those variables
**  para:
**      lib: the libref. default is ori
**      datasets: specify which datasets will be relength. if empty, relength all.
**      min: the variables would be excluded if length<=min
**  *********************************************************************************/
%macro reLenVars(lib, datasets=, min=8);
    %local i j SetNum setname orilen reallen varnum varlist err mlist orilen vatlist complist;
    %if %superq(lib) = %then %let lib=%getLib;
    %if %superq(datasets) = %then %do;
        proc sql noprint;
            select trim(memname)
            into :datasets separated by " "
            from dictionary.tables
            where libname=%upcase("&lib");
        quit;
    %end;

    /*relength variables dataset by dataset*/
    %let setnum=%sysfunc(countw(&datasets));
    %do i=1 %to &setnum;
        %let setname=%scan(&datasets, &i, %str( ));
        /*create the code to get real length*/
        proc sql noprint;
            select 'max(lengthn('||trim(name)||'))', length, trim(name)
            into :mlist separated by ",", :orilen separated by " ", :varlist separated by " "
            from dictionary.columns
            where libname=%upcase("&lib") and memname=%upcase("&setname") and
                    type="char" and length >&min;
        quit;
        %let varnum=&sqlobs;

        /*get real length and stored into macro variables*/
        %if &varnum >0 %then %do;
            proc sql noprint;
                select &mlist
                into %do j=1 %to &varnum;
                            :rlv_reallen&j
                            %if &j ne &varnum %then , ;
                        %end; 
                from &lib..&setname;
            quit;

            /*reset mlist and complist*/
            %let mlist= ;
            %let complist= ;

            %do j=1 %to &varnum;
                /*create the modify code*/
                %if %scan(&orilen, &j, %str( )) >&&rlv_reallen&j %then %do;
                    %let rlv_reallen&j=%sysfunc(cats(&&rlv_reallen&j));
                    %if %superq(mlist)= %then
                        %let mlist=&mlist.%scan(&varlist, &j, %str( )) char(&&rlv_reallen&j);
                    %else %let mlist=&mlist.,%scan(&varlist, &j, %str( )) char(&&rlv_reallen&j);
                    %let complist=&complist %scan(&varlist, &j, %str( ));
                %end;
            %end;

            %if %superq(mlist) ne %then %do;
                /*create a copy for validation*/
                proc copy in=&lib out=work memtype=data;
                    select &setname;
                run;

                /*relength*/
                proc sql;
                    alter table &lib..&setname
                    modify &mlist;
                quit;

                /*Only the Value Comparison will be print when the values are different*/
                ods exclude CompareDatasets CompareSummary CompareVariables;
                proc compare base=&lib..&setname comp=work.&setname
                            out=work.rlv_comp outnoequal;
                        var &complist;    
                run;

                proc sql noprint;
                    select count(*) 
                    into :err
                    from work.rlv_comp;
                quit;

                /*if no error, then delete the copy*/
                %if &err=0 %then %do;
                    proc datasets lib=work noprint;
                       delete &setname ;
                    run;
                    quit;
                %end;
                %else %put WARNNING: A error occure when re-length variable in &setname;
            %end;
        %end;
    %end;

    proc datasets lib=work noprint;
       delete rlv_: ;
    run;
    quit;

    %put === Macro reLenVars executed ===;
%mend reLenVars;


