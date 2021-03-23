/* ***********************************************************************************************
     Name : reSetLabel.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: Get the dataset label and variable's label
*    --------------------------------------------------------------------------------------------*
     Parameters : dname = data set name in the dictionary libref
                         setlabel= the table description in the dictionary
*    -------------------------------------------------------------------------------------------*
     Notes: This macro is basing the specific dictionary, for reusing in this project
*   *********************************************************************************************/
%macro reSetLabel(dname,setlabel);
    %local label keep;
       
    proc sql noprint;
        select table_name_, 
                 catt(table_name_,'="',e,'"') as label
        into :keep separated by " ", 
               :label separated by " "
        from dict.&dname (firstobs=2)
        where c is missing;
    quit;

    data orilib.&dname(label=&setlabel);
        set orilib.&dname(keep=&keep);
        label &label;
    run;
%mend reSetLabel;
