/* ********************************************************************************
* macro BinOpt: Optimal discretize the interval variables and collaspsing the levels of 
* the ordinal variables.
* ***************************************************************************************/
%macro BinOpt()/minoperator;
	/* find the maximum and minimum values */
	%if %superq(acc)= %then %let acc=0.05;
	%if %superq(nbins)= %then %let nbins=10;
	%if %superq(method)= %then %let method=4;

	%if %superq(interval)= and %superq(ordinal)= %then %do;
		optoins notes;
		%put NOTE: ==  No variable can be binned ==;
		%return;
	%end;
	%else %do;
		%let vlist=&interval &ordinal;
		%let int=&interval;
	%end;

	%local i j int ord VarMax VarMin Mbins MinBinSize vclass;

	%strtran(int)
	%let nvars=%sysfunc(countw(&vlist));

	%do i=1 %to &nvars;
		%let var=%scan(&vlist, &i, %str( ));
		%if %superq(interval)^=  %then %do;
			%if &var in (&int) %then %let vclass=interval;
			%else %let vclass=ordinal;
		%end;
		%else %let vclass=ordinal;
		proc sql noprint;
			select floor(min(&var)), ceil(max(&var)) 
			into :VarMin, :VarMax 
			from &dn;
		quit;

		/* 根据Acc等距分箱 */
		%let Mbins=%sysfunc(int(%sysevalf(1.0/&Acc)));
		%let MinBinSize=%sysevalf((&VarMax-&VarMin)/&Mbins);
		%if &var in (&ordinal) %then %let MinBinSize=%sysfunc(int(&MinBinSize));

		/* 拆分bins */
		data work.bo_DS;
			set &dn;
			select;
			%do j=1 %to %eval(&Mbins-1);
				when (&var<%sysevalf(&VarMin + &j * &MinBinSize)) Bin=&j;
			%end;
				otherwise bin=&j;
				end;
			keep &var &target Bin;
		run;

		data work.bo_blimits;
			%do j=1 %to %Eval(&Mbins-1);
				BinUpBorder=%sysevalf(&VarMin + &j * &MinBinSize);
				Bin=&j;
				output;
			%end;
		run;

		/* 计算目标变量的频率 */
		proc freq data=work.bo_DS noprint;
			table Bin*&target /out=work.bo_cross;  /* 输出变量Bin、&target、Count、Percent */
			table Bin /out=work.bo_BinTot; /* 输出变量Bin、Count、Percent */
		run;
		/* 根据分组排序 */
		proc transpose data=work.bo_cross out=work.bo_cross;
			by bin;
			var count;
			id &target;
		run;
		proc sql;
		create table work.bo_cont as
			select a.*, binupborder, pos, neg, a.bin as oribin
			from (select bin, count as total, percent from work.bo_bintot) as a left join
					(select * from work.bo_blimits) as b on a.bin=b.bin left join
					(select bin, _0 as neg, _1 as pos from work.bo_cross) as c on a.bin=c.bin
				;
		quit;

		data work.bo_contold;
			set work.bo_cont;
		run;

		/*combine the bins which percent is lower than 5% */
		data work.bo_cont;
			set work.bo_cont end=eof;
			retain kbin kpos kneg ktot kpert 0;
			if kbin ne 0 then do;
				percent=sum(percent, kpert);
				bin=kbin;
				pos=sum(pos, kpos);
				neg=sum(neg, kneg);
				total=sum(total, ktot);
			end;
			if percent<5 then do;
				kbin=bin; 	ktot=total; kpos=pos; kneg=neg; kpert=percent;
			end;
			else do;
				output;
				kbin=0; ktot=0; kpos=0; kneg=0; kpert=0;
			end;
			if eof then output;
			drop k:;
		run;
		 proc sort data=work.bo_cont;
		 	by descending bin;
		run;
		data work.bo_cont;
			set work.bo_cont;
			retain kpos kneg ktot kpert 0;
			oribin=bin;
			if _n_=1 and percent<5 then do;
				ktot=total;
				kpos=pos;
				kneg=neg;
				kpert=percent;
			end;
			if _N_=2 and kpos ne 0 then do;
				percent=sum(percent, kpert);
				pos=sum(pos, kpos);
				neg=sum(neg, kneg);
				total=sum(total, ktot);
			end;
			if percent>=5 then output;
			drop  percent k:;
		run;

		proc sort data=work.bo_cont;
			by OriBin;
		run;

		%local m;

		/* 把所有分类放到一个节点中作为一个字符点？（string point） */
		data work.bo_cont;
			set work.bo_cont;
			i=_N_;
			Var=bin;
			Bin=1;
			call symput("m", compress(_N_)); /* m=分类序号 */
		run;

		/* 循环变量所有节点 */
		%local NBin;
		%let NBin=1; /* 当前分箱的值 */

		/* 原代码使用nbins( 最大分箱数)控制循环。如果原等距分箱的结果中分箱数小于
			最大分箱数， 后面的循环中没有可拆分的bin时log窗口会报错。*/
		%let splitbin=%sysfunc(min(&m,&nbins));

		%do %while (&NBin <&splitbin);
			/*%candsplite()每次拆分的结果由data步更新 work.bo_cont, 
			下一步的%candsplits() 拆分的是更新的_cont*/
			%CandSplits(work.bo_cont, &method, work.bo_Splits); /* 候选分类 */
			Data work.bo_Cont;
				set work.bo_Splits;
			run;
			%let NBin=%eval(&NBin+1);
		%end; /* end of the WHILE splitting loop  */

		/* 建立输出映射 */
		data work.bo_Map1;
			set work.bo_cont(Rename=Var=OldBin);
			drop pos OriBin neg i;
		run;
		proc sort data=work.bo_Map1;
			by Bin BinUpBorder;
		run;

		/* 合并分箱并计算分解 */
		data work.bo_bin;
			length variable d_var $32 class branch $8  cluster $1000;
			set work.bo_Map1;
			by Bin BinUpBorder;
			variable="&var";
			class="&vclass";
			d_var="b_"||substr(variable, 1, 30);
			rename BinUpBorder=border;
			cluster=" ";
			bin=.;
			branch="opt";
			if last.bin then output;

			drop OldBin total;
		run;

		proc sort data=work.bo_bin;
			by border;
		run;

		data work.bo_bin;
			set work.bo_bin end=eof ;
			if eof =0;
		run;
		data work.bo_bin;
			set work.bo_bin end=eof ;
			if eof then nlevels=_N_+1;
		run;

		proc sql;
			delete from &outdn
			where variable="&var" and branch="opt";
		quit;

		proc append base=work.bv_tree data=work.bo_bin force;
		run;
	%end;
%mend;

/*由外面的%macro()反复调用, 其生成的dataset又作为参数输入，再次拆分。
每次循环时&BMax变大，m&i的数量增多，m&i的值减少。*/
%macro CandSplits(BinDS, Method, NewBins);
	/* 从现有分箱中生成候选分段并选出最优分箱 */
	/* first we sort the dataset OldBins by OriBin and Bin */

	proc sort data=&BinDS;
		by Bin OriBin;
	run;

	/* within each bin, 拆分数据到候选数据集 */
	%local Bmax i value;

	proc sql noprint;
		select max(bin) into: Bmax from &BinDS;
	/**/
		%do i=1 %to &Bmax;
			%local m&i;
			create table work.cs_BinC&i as select * from &BinDS where Bin=&i;
			select count(*) into:m&i from work.cs_BinC&i;
		%end;

		create table work.cs_allVals (BinToSplit num, DatasetName char(80), Value num);
	quit;

	/* for each of these bins,*/
	%do i=1 %to &Bmax;

		%if (&&m&i>1) %then
			%do;
				/* if the bin has more than one category */
				/* 查找最优分割的可能性。如拆分成功，work.cs_binc&i中的split值
				代表两个新组*/
				%BestSplit(work.cs_BinC&i, &Method, &i)

				/* 尝试该分割并计算它的值 */
				data work.cs_trysplit&i;
					set work.cs_binC&i;
				/*Split=0的保持原bin, Split=1的赋予新bin*/
					if split=1 then Bin=%eval(&Bmax+1);
				run;

				Data work.cs_main&i;
					set &BinDS;
				/*将本次拆分的bin删除，由经拆分的数据替代（work.cs_trysplit&i）*/
					if Bin=&i then delete;
				run;

				Data work.cs_main&i;
					set work.cs_main&i work.cs_trysplit&i;
				run;
				/* Evaluate the value of this split as the next best split 
				给这次拆分估值，作为下次最优拆分的依据 */
				%let value=;
				/*%GValue运行的结果是value的值*/
				%GValue(work.cs_main&i, &Method, Value);

				proc sql noprint;
					insert into work.cs_AllVals values(&i, "work.cs_main&i", &Value);
				run;
				quit;
			%end; /* end of trying for a bin wih more than one category */
	%end;
/*	proc print data=work.cs_allVals;
	run;*/

	/*  find the best split and return the new bin dataset
	找到最优切分，并返回一个新数据集 */
	proc sort data=work.cs_allVals;
		by descending value;
	run;

	data _null_;
		set work.cs_AllVals(obs=1);
		call symput("bin", compress(BinToSplit));
	run;

	/*  the return dataset is the best bin work.cs_trySplit&bin
	返回经拆分的数据集*/
	Data &NewBins;
		set work.cs_main&Bin;
		drop split;
	run;

	/* Clean the workspace. 没有指定lib，使用默认的工作lib。*/
	proc datasets lib=work nodetails nolist;
		delete cs_AllVals   cs_BinC:  cs_TrySplit: cs_Main:;
	quit; 
%mend;

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

%macro CalcMerit(BinDS, ix, method, M_Value);
	/* 使用评估函数计算候选分段的当前位置。所有节点在这或上面都合并到一起，最后分箱会变大起来 */
	/*  利用SQL查找列联表的频数  */
	%local n_11 n_12 n_21 n_22 n_1s n_2s n_s1 n_s2;

	proc sql noprint;
		select sum(neg) into :n_11 from &BinDS where i<=&ix;
		select sum(neg) into :n_21 from &BinDS where i> &ix;
		select sum(pos) into : n_12 from &BinDS where i<=&ix;
		select sum(pos) into : n_22 from &binDS where i> &ix;
		select sum(total) into :n_1s from &BinDS where i<=&ix;
		select sum(total) into :n_2s from &BinDS where i> &ix;
		select sum(neg) into :n_s1 from &BinDS;
		select sum(pos) into :n_s2 from &BinDS;
	quit;

	/* 根据类型计算评估函数 */
	/* The case of Gini */
	%if (&method=1) %then
		%do;
			%local N G1 G2 G Gr;
			%let N=%eval(&n_1s+&n_2s);
			%let G1=%sysevalf(1-(&n_11*&n_11+&n_12*&n_12)/(&n_1s*&n_1s));
			%let G2=%sysevalf(1-(&n_21*&n_21+&n_22*&n_22)/(&n_2s*&n_2s));
			%let G =%sysevalf(1-(&n_s1*&n_s1+&n_s2*&n_s2)/(&N*&N));
			%let GR=%sysevalf(1-(&n_1s*&G1+&n_2s*&G2)/(&N*&G));
			%let &M_value=&Gr;

			%return;
		%end;

	/* The case of Entropy */
	%if (&method=2) %then
		%do;
			%local N E1 E2 E Er;
			%let N=%eval(&n_1s+&n_2s);
			%let E1=%sysevalf(-( (&n_11/&n_1s)*%sysfunc(log(%sysevalf(&n_11/&n_1s))) + 
				(&n_12/&n_1s)*%sysfunc(log(%sysevalf(&n_12/&n_1s)))) / %sysfunc(log(2)) );
			%let E2=%sysevalf(-( (&n_21/&n_2s)*%sysfunc(log(%sysevalf(&n_21/&n_2s))) + 
				(&n_22/&n_2s)*%sysfunc(log(%sysevalf(&n_22/&n_2s)))) / %sysfunc(log(2)) );
			%let E =%sysevalf(-( (&n_s1/&n  )*%sysfunc(log(%sysevalf(&n_s1/&n   ))) + 
				(&n_s2/&n  )*%sysfunc(log(%sysevalf(&n_s2/&n   )))) / %sysfunc(log(2)) );
			%let Er=%sysevalf(1-(&n_1s*&E1+&n_2s*&E2)/(&N*&E));
			%let &M_value=&Er;

			%return;
		%end;

	/* The case of X2 pearson statistic */
	%if (&method=3) %then
		%do;
			%local m_11 m_12 m_21 m_22 X2 N i j;
			%let N=%eval(&n_1s+&n_2s);
			%let X2=0;

			%do i=1 %to 2;
				%do j=1 %to 2;
					%let m_&i.&j=%sysevalf(&&n_&i.s * &&n_s&j/&N);
					%let X2=%sysevalf(&X2 + (&&n_&i.&j-&&m_&i.&j)*(&&n_&i.&j-&&m_&i.&j)/&&m_&i.&j  );
				%end;
			%end;

			%let &M_value=&X2;

			%return;
		%end;

	/* The case of the information value */
	%if (&method=4) %then
		%do;
			%local IV;
			%let IV=%sysevalf( ((&n_11/&n_s1)-(&n_12/&n_s2))*%sysfunc(log(%sysevalf((&n_11*&n_s2)/(&n_12*&n_s1)))) 
				+((&n_21/&n_s1)-(&n_22/&n_s2))*%sysfunc(log(%sysevalf((&n_21*&n_s2)/(&n_22*&n_s1)))) );
			%let &M_Value=&IV;

			%return;
		%end;
%mend;

%macro GValue(BinDS, Method, M_Value);
	/* 计算当前拆分的值 */
	/* 提取频率表中的值 */
	proc sql noprint;
		/* Count the number of obs and categories of X and Y */
		%local i j R N; /* C=2, R=Bmax+1 */
		select max(bin) into : R from &BinDS;
		select sum(total) into : N from &BinDS;

		/* extract n_i_j , Ni_star*/
		%do i=1 %to &R;
			%local N_&i._1 N_&i._2 N_&i._s N_s_1 N_s_2;
			Select sum(neg) into :N_&i._1 from &BinDS where Bin =&i;
			Select sum(pos) into :N_&i._2 from &BinDS where Bin =&i;
			Select sum(Total) into :N_&i._s from &BinDS where Bin =&i;
			Select sum(neg) into :N_s_1 from &BinDS;
			Select sum(pos) into :N_s_2 from &BinDS;
		%end;
	quit;

	%if (&method=1) %then
		%do;
			/* Gini */
			/* substitute in the equations for Gi, G */
			%do i=1 %to &r;
				%local G_&i;
				%let G_&i=0;

				%do j=1 %to 2;
					%let G_&i = %sysevalf(&&G_&i + &&N_&i._&j * &&N_&i._&j);
				%end;

				%let G_&i = %sysevalf(1-&&G_&i/(&&N_&i._s * &&N_&i._s));
			%end;

			%local G;
			%let G=0;

			%do j=1 %to 2;
				%let G=%sysevalf(&G + &&N_s_&j * &&N_s_&j);
			%end;

			%let G=%sysevalf(1 - &G / (&N * &N));

			/* finally, the Gini ratio Gr */
			%local Gr;
			%let Gr=0;

			%do i=1 %to &r;
				%let Gr=%sysevalf(&Gr+ &&N_&i._s * &&G_&i / &N);
			%end;

			%let &M_Value=%sysevalf(1 - &Gr/&G);

			%return;
		%end;

	%if (&Method=2) %then
		%do;
			/* Entropy */
			/* Check on zero counts or missings */
			%do i=1 %to &R;
				%do j=1 %to 2;
					%local N_&i._&j;

					%if (&&N_&i._&j=.) or (&&N_&i._&j=0) %then
						%do ; /* return a missing value */
							%let &M_Value=.;

							%return;
						%end;
				%end;
			%end;

			/* substitute in the equations for Ei, E */
			%do i=1 %to &r;
				%local E_&i;
				%let E_&i=0;

				%do j=1 %to 2;
					%let E_&i = %sysevalf(&&E_&i - (&&N_&i._&j/&&N_&i._s)*%sysfunc(log(%sysevalf(&&N_&i._&j/&&N_&i._s))) );
				%end;

				%let E_&i = %sysevalf(&&E_&i/%sysfunc(log(2)));
			%end;

			%local E;
			%let E=0;

			%do j=1 %to 2;
				%let E=%sysevalf(&E - (&&N_s_&j/&N)*%sysfunc(log(&&N_s_&j/&N)) );
			%end;

			%let E=%sysevalf(&E / %sysfunc(log(2)));

			/* finally, the Entropy ratio Er */
			%local Er;
			%let Er=0;

			%do i=1 %to &r;
				%let Er=%sysevalf(&Er+ &&N_&i._s * &&E_&i / &N);
			%end;

			%let &M_Value=%sysevalf(1 - &Er/&E);

			%return;
		%end;

	%if (&Method=3) %then
		%do;
			/* The Pearson's X2 statistic */
			%local X2;
			%let N=%eval(&n_s_1+&n_s_2);
			%let X2=0;

			%do i=1 %to &r;
				%do j=1 %to 2;
					%local m_&i._&j;
					%let m_&i._&j=%sysevalf(&&n_&i._s * &&n_s_&j/&N);
					%let X2=%sysevalf(&X2 + (&&n_&i._&j-&&m_&i._&j)*(&&n_&i._&j-&&m_&i._&j)/&&m_&i._&j  );
				%end;
			%end;

			%let &M_value=&X2;

			%return;

		%end; /* end of X2 */

	%if (&Method=4) %then
		%do;
			/* Information value */
			/* substitute in the equation for IV */
			%local IV;
			%let IV=0;

			/* first, check on the values of the N#s */
			%do i=1 %to &r;
				%if (&&N_&i._1=.) or (&&N_&i._1=0) or 
					(&&N_&i._2=.) or (&&N_&i._2=0) or
					(&N_s_1=) or (&N_s_1=0)    or  
					(&N_s_2=) or (&N_s_2=0) %then
					%do ; /* return a missing value */
						%let &M_Value=.;

						%return;
					%end;
			%end;

			%do i=1 %to &r;
				%let IV = %sysevalf(&IV + (&&N_&i._1/&N_s_1 - &&N_&i._2/&N_s_2)*%sysfunc(log(%sysevalf(&&N_&i._1*&N_s_2/(&&N_&i._2*&N_s_1)))) );
			%end;

			%let &M_Value=&IV;
		%end;
%mend;

