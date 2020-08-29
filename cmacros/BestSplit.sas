/*call by %CandSplits()*/
%macro BestSplit(BinDs, Method, BinNo);
    /* 在一个数据集中查找最优拆分 */
    /* the bin size=mb */
    %local mb i value BestValue BestI;

    proc sql noprint;
        select count(*) into: mb from &BinDs where Bin=&BinNo;
    quit;

    /* find the location of the split on this list */
    %let BestValue=0;
    %let BestI=1;
    /*循环调用%CalcMerit，根据选定方法计算在不同分割点（&i）的value。最后确定
    最优分割点(BestI)及其Value值(BestValue)*/
    %do i=1 %to %eval(&mb-1);
        %let value=;
        %CalcMerit(&BinDS, &i, &method, Value);
        %if %sysevalf(&BestValue<&value) %then
            %do;
                %let BestValue=&Value;
                %let BestI=&i;
            %end;
    %end;

    /* Number the bins from 1->BestI =BinNo, and from BestI+1->mb =NewBinNo */
    /* split the BinNo into two bins */
    /*以最优分割点将数据分割成两个Split*/
    data &BinDS;
        set &BinDS;

        if i<=&BestI then
            Split=1;
        else Split=0;
        drop i;
    run;

    proc sort data=&BinDS;
        by Split;
    run;

    /* reorder i within each bin */
    /*产生每个Split中的序号（i）*/
    data &BinDS;
        retain i 0;
        set &BinDs;
        by Split;

        if first.split then
            i=1;
        else i=i+1;
    run;

%mend;
