/* ***********************************************************************************************
     Name : spTermin.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: Get the sponsors terminology from dictionary of the raw data files 
                    for data cleaning
*    --------------------------------------------------------------------------------------------*
     Parameters : dname = data set name in the dictionary libref
*    -------------------------------------------------------------------------------------------*
     Notes: This macro is basing the specific dictionary, for reusing in this project
*   *********************************************************************************************/
%macro spTermin(dname);
    %local sid vlength opts;

    %let opts=%getops(notes mprint mlogic symbolgen);
    options nonotes nomprint nomlogic nosymbolgen;

    proc sql noprint;
        select max(length)
        into :vlength
        from (select length from dictionary.columns
                                      where libname="DICT" and name="F");
    quit;

    data work.vv_temp;
        length dataset vars $32 legal_value $&vlength;
        retain dataset ("&dname");
        drop dsid rc msg;

        dsid=open("dict.&dname(where=(c is missing and f is not missing and
                                                     Table_Name_ not in ('STUDYID','FORMNUM','SIGNATUR')))");
        if dsid then do while(not fetch(dsid));
                vars=getvarc(dsid, 1);
                legal_value= getvarc(dsid, 6);
                output;
        end;
        else do;
            msg=sysmsg();
            put msg;
        end;
        rc=close(dsid);
        stop;
    run;

    proc append base=sponsors_termin data=work.vv_temp;
    run;
    options &opts;
    %put The sponsors terminology was stored in work.sp_termin;
%mend spTermin;
