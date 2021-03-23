/* ***********************************************************************************************
     Name  : getSetDef.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: create macro variables to hold the variable-length, keep-list, label-value, 
                    and sort list for the CDISC standard domain.
*    --------------------------------------------------------------------------------------------*
     Input    : required: metaset
                   optional: domain
     Output : 4 marco variables for each domain.
*    --------------------------------------------------------------------------------------------*
     Parameters : metaset = one- or two-level data set name in which the metadata 
                                         fetched by %getCdiscSetMeta() stored.
                         domain = The dataset list for which the labellist, lengthlist, keeplist, 
                                         and orderlist would have extracted. 
                                         If not assigned, all domains will be processed
*   *********************************************************************************************/
%macro getSetDef(metaset, domain)/ des="Reading attributelist, keeplist and orderlist for each 
CDISC standard dataset and store those data into macro variables.";
    %if %superq(metaset) = %then %do;
        %put ERROR: == The dataset in which metadata stored is not assigned ==;
        %return;
    %end;

    data _null_;
        set &metaset;
        %if %superq(domain) ne %then %do;
            %strtran(domain)
            where upcase(domain) in (%upcase(&domain))%str(;);
        %end;
        length label len keep order dmlabel $16;
        label=cats(domain, "label");
        len=cats(domain, "length");
        keep=cats(domain, "keep");
        order=cats(domain, "order");
        dmlabel=cats(domain, "setlabel");
        /*declear the global variable*/
        re=dosubl(catx(' ', '%global', label, keep, order, len, dmlabel, ';'));
        call symputx(label, labellist);
        call symputx(keep, keeplist);
        call symputx(order, orderlist);
        call symputx(len, lengthlist);
        call symputx(dmlabel, quote(trim(setlabel)));
    run;
%mend;
