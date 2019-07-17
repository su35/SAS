/*由外面的%macro()反复调用, 其生成的dataset又作为参数输入，再次拆分。
每次循环时&BMax变大，m&i的数量增多，m&i的值减少。*/
%macro CandSplits(BinDS, Method, NewBins);
	/* 从现有分箱中生成候选分段并选出最优分箱 */
	/* first we sort the dataset OldBins by PDV1 and Bin */
	proc sort data=&BinDS;
		by Bin PDV1;
	run;

	/* within each bin, 拆分数据到候选数据集 */
	%local Bmax i value;

	proc sql noprint;
		select max(bin) into: Bmax from &BinDS;
	/**/
		%do i=1 %to &Bmax;
			%local m&i;
			create table work.Temp_BinC&i as select * from &BinDS where Bin=&i;
			select count(*) into:m&i from work.Temp_BinC&i;
		%end;

		create table work.temp_allVals (BinToSplit num, DatasetName char(80), Value num);
	quit;

	/* for each of these bins,*/
	%do i=1 %to &Bmax;

		%if (&&m&i>1) %then
			%do;
				/* if the bin has more than one category */
				/* 查找最优分割的可能性。如拆分成功，temp_binc&i中的split值
				代表两个新组*/
				%BestSplit(work.Temp_BinC&i, &Method, &i)

				/* 尝试该分割并计算它的值 */
				data work.temp_trysplit&i;
					set work.temp_binC&i;
				/*Split=0的保持原bin, Split=1的赋予新bin*/
					if split=1 then Bin=%eval(&Bmax+1);
				run;

				Data work.temp_main&i;
					set &BinDS;
				/*将本次拆分的bin删除，由经拆分的数据替代（temp_trysplit&i）*/
					if Bin=&i then delete;
				run;

				Data work.Temp_main&i;
					set work.temp_main&i work.temp_trysplit&i;
				run;
				/* Evaluate the value of this split as the next best split 
				给这次拆分估值，作为下次最优拆分的依据 */
				%let value=;
				/*%GValue运行的结果是value的值*/
				%GValue(work.temp_main&i, &Method, Value);

				proc sql noprint;
					insert into work.temp_AllVals values(&i, "temp_main&i", &Value);
				run;
				quit;
			%end; /* end of trying for a bin wih more than one category */
	%end;
/*	proc print data=temp_allVals;
	run;*/

	/*  find the best split and return the new bin dataset
	找到最优切分，并返回一个新数据集 */
	proc sort data=work.temp_allVals;
		by descending value;
	run;

	data _null_;
		set work.temp_AllVals(obs=1);
		call symput("bin", compress(BinToSplit));
	run;

	/*  the return dataset is the best bin Temp_trySplit&bin
	返回经拆分的数据集*/
	Data &NewBins;
		set work.Temp_main&Bin;
		drop split;
	run;

	/* Clean the workspace. 没有指定lib，使用默认的工作lib。
	proc datasets nodetails nolist;
		delete temp_AllVals   Temp_BinC:  temp_TrySplit: temp_Main:;
	quit; */
%mend;
