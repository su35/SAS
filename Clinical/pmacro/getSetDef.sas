/*************************************************************
retreat the attributelist,  keeplist and orderlist from the dataset 
that created by macro getCdiscSetMeta()
metaset: the dataset created by getCDISCmeta()
dn: the dataset list for which the attributelist, keeplist  and orderlist
would be retreated
*************************************************************/
%macro getSetDef(metaset, domain=);
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
        length label len keep order $16;
        label=cats(domain, "label");
        len=cats(domain, "length");
        keep=cats(domain, "keep");
        order=cats(domain, "order");
        /*declear the global variable*/
        re=dosubl(catx(' ', '%global', label, keep, order, len, ';'));
        call symputx(label, labellist);
        call symputx(keep, keeplist);
        call symputx(order, orderlist);
        call symputx(len, lengthlist);
    run;
%mend;
