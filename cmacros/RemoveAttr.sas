/* ***************************************************** 
* macro RemoveAttr: remove the specified attribute
* parameters
* lib: the name of the library
* sets: the names of the datasets that would be modified
* attrib: format, informat, label. if not sepcify, remove all
 ********************************************************/
%macro RemoveAttr(lib=, sets=, attrib=);
    %local i j setnum;
    %if %superq(lib)=  %then %do;
        %if %sysfunc(libref(&pname)) = 0 %then %let lib=&pname;
        %else lib=WORK;
    %end;
    options nonotes;
    %if %superq(sets)= %then %do;
        proc sql noprint;
            select memname, count(distinct memname) 
                into :sets separated by ' ', :setnum
                from dictionary.tables
                where libname="%upcase(&lib)";
        quit;
    %end;
    
    %let i=1;
    %let setname = %scan(&sets, &i, %str( ));
    %do %until (&setname= );
        %let j=1;
        proc datasets lib=&lib memtype=data noprint;
            modify &setname;
            %if &attrib= %then %do;
                attrib _all_ label=' '%str(;)
                attrib _all_ format=%str(;)
                attrib _all_ informat=%str(;)
            %end;
            %else %do;
                %let att=%scan(&attrib, &j, %str( ));
                %do %until(&att= );
                    %if &att=format %then attrib _all_ format=%str(;);
                    %else %if &att=informat %then attrib _all_ informat=%str(;);
                    %else %if &att=label %then attrib _all_  label=""%str(;);
                    %else %put ERROR: The attrib error, attrib=&att;
                     %let j=%eval(&j+1);
                    %let att=%scan(&attrib, &j, %str( ));
               %end;
            %end;
        run;
        quit;
        %let i=%eval(&i+1);
        %let setname = %scan(&sets, &i, %str( ));
    %end;
    options notes;
    %put NOTE: == Macro RemoveAttr runing completed. ==;
%mend RemoveAttr;
