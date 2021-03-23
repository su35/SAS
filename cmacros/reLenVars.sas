/* ***********************************************************************************************
     Name : reLenVars.sas
     Author: Jun Fang  March, 2017
*    --------------------------------------------------------------------------------------------*
     Purpose: reduce the length of the char type variables to real requirement.
                    When read data from PC files, espacilly form access file, the the lenght of 
                    char type variable may too long. This macro re-lenght those variables
*    --------------------------------------------------------------------------------------------*
     Parameters : lib           = The libref in which the length of the variables will be reduce. 
                                           The default is orilib of the project.
                         datasets  = The list of datasets, separated by blank,  in which the length of 
                                            the variables will be reduce. The default is all datasets.
                         minlen     = The minimum length. The variables would be excluded 
                                            if length of the variables<=minlen
*   *********************************************************************************************/
%macro reLenVars(lib, datasets, minlen);
    %local reallen;

    /* ** set the defualt value of the required params if the value is null ***/
    %if %superq(lib) = %then %let lib=%getlib();

    %if %superq(datasets) ne %then %strtran(datasets);

    /*****  fetch the dataset names, variable names, and variable length  ***/
    proc sql;
        create table work.rlv_len as
        select memname, name, length
        from dictionary.columns
        where libname=upcase("&lib") and type="char" 
            %if %superq(datasets) ne %then and memname in (%upcase(&datasets));
            %if %superq(minlen) ne %then and length>&minlen;
        order by memname;
    quit;

    /*** Get the real max length by dosuble() function and modify by call execute() routine ***/
    data _null_;
        set work.rlv_len ;
        by memname;
        length modifyList compList $32767;
        retain modifyList compList;

        /*using dosubl() function to get the real length*/
        rc=dosubl('proc sql noprint; select max(lengthn('||name||')) into :reallen from &lib..'||memname||'; quit;');    
        realLen=input(symget("reallen"), 8.);

        /*Initialization for each dataset*/
        if first.memname then call missing(modifylist, compList);

         /*If the length needs to be reduced, create the modify code*/
        if length>realLen then do;
            modifylist=catx(",", modifylist, catx(" ", name, cats("char(", realLen, ")")));
            complist=catx(" ", complist, name);
        end;

        /*if a domain needs to be modified, call %mdVarLen() by by call execute() routine to modify*/
        if last.memname and not missing(modifylist) then do;
            /*Since there are ',' in the modifylist, it couldn't be passed as a parameter in most condition*/
            modifylist=cats("'",modifylist,"'");
            modifylist=catx(", ", "&lib", memname, modifylist, complist);
            modifylist=cats('%mdVarLen(', modifylist, ')');
            call execute(modifylist);
        end;
    run;
    %put  === Macro reLenVars executed ===;
%mend reLenVars;

