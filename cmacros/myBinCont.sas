/* ********************************************************************************
使用二元因变量DVVar和Method对连续变量IVVar的最优分箱。MMax 最大分箱数。
输出数据集DSVarMap为变量映射关系。	Acc是分箱的精确度等级定义，
值介于0到1之间. Acc=0.01 讲计算分箱精确度限制在变量值总区间1%。
Acc值越小, 分箱所需时间越长, 但结果精确度越高。

参数method控制使用的分箱标准如下:
1=Gini 基尼 2=Entory 熵 3=Pearson's Chi2 皮尔逊卡方 4=Information Value 信息值
* ***************************************************************************************/
%macro myBinCont(DSin, DVVar, VarList, Method, MMax, Acc, DSVarMap)/minoperator;
	/* find the maximum and minimum values */
	options nonotes;
	%local VarMax VarMin d;
	%let d = 1;
	%do %while(%scan(&varlist,&d, %str( ))^= );
		%let IVVar=%scan(&varlist,&d,%str( ) );
		proc sql noprint;
			select floor(min(&IVVar)), ceil(max(&IVVar)) into :VarMin, :VarMax from &DSin;
		quit;

		/* 根据Acc等距分箱 */
		%local Mbins i MinBinSize;
		%let Mbins=%sysfunc(int(%sysevalf(1.0/&Acc)));
		%let MinBinSize=%sysevalf((&VarMax-&VarMin)/&Mbins);

		/* 计算最大及最小值之间的分箱界限 */
		%do i=1 %to %eval(&Mbins);
			%local Lower_&i Upper_&i;
			%let Upper_&i = %sysevalf(&VarMin + &i * &MinBinSize);
			%let Lower_&i = %sysevalf(&VarMin + (&i-1)*&MinBinSize);
		%end;

		/*	%let Lower_1 = %sysevalf(&VarMin-0.0001);  /* 确保去尾 */
		/*	%let Upper_&Mbins=%sysevalf(&VarMax+0.0001);*/
		/* 拆分bins */
		data Temp_DS;
			set &DSin;

			%do i=1 %to %eval(&Mbins-1);
				if &IVVar>=&&Lower_&i and &IVVar < &&Upper_&i Then
					Bin=&i;
			%end;

			if &IVVar>=&&Lower_&Mbins and &IVVar <= &&Upper_&MBins Then
				Bin=&MBins;
			keep &IVVar &DVVar Bin;
		run;

		/* 生成每个箱的上下限的数据集 */
		data temp_blimits;
			%do i=1 %to %Eval(&Mbins-1);
				Bin_LowerLimit=&&Lower_&i;
				Bin_UpperLimit=&&Upper_&i;
				Bin=&i;
				output;
			%end;

			Bin_LowerLimit=&&Lower_&Mbins;
			Bin_UpperLimit=&&Upper_&Mbins;
			Bin=&Mbins;
			output;
		run;

		proc sort data=temp_blimits;
			by Bin;
		run;

		/* 计算目标变量的频率 */
		proc freq data=Temp_DS noprint;
			table Bin*&DVvar /out=Temp_cross;  /* 输出变量Bin、&DVvar、Count、Percent */

				table Bin /out=Temp_binTot; /* 输出变量Bin、Count、Percent */
		run;

		/* 根据分组排序 */
		proc sort data=temp_cross;
			by Bin;
		run;

		proc sort data= temp_BinTot;
			by Bin;
		run;

		data temp_cont; /* contingency table 列联表 */
			merge Temp_cross(rename=count=Ni2 ) temp_BinTot(rename=Count=total) temp_BLimits;
			by Bin;
			Ni1=total-Ni2;
			PDV1=bin; /* 原始分箱段号 just for conformity with the case of nominal IV */
			label  Ni2= total=;

			/* 只输出&DVVar=1及bin下只有&DVVar=0的 
				如果Ni1=0,说明该bin中只有一种情况：要么都是&DVVar=1，要么都是&DVVar=0
				Temp_cross表及temp_BinTot表里仅包括bin里有数据的，所以merge后的表里的
				没有数据的bin的Ni1和DVVar都是missing value, 也就过滤了*/
			if Ni1=0 then
				output;
			else if &DVVar=1 then
				output;
			drop percent &DVVar;
		run;

		data temp_contold;
			set temp_cont;
		run;

		/* 合并所有 Ni1 =0 的bin。temp_cont表里不存在 Ni2，total为0的数据*/
		proc sql noprint;
			select quote(trim(put(bin,8.-L))) into :bins separated by " "
				from temp_cont;

			%do i=1 %to &Mbins;
				%if "&i" in (&bins) %then
					%do;
						select Ni1, Ni2, total, bin_lowerlimit, bin_upperlimit into 
							:Ni1,:Ni2,:total, :bin_lower, :bin_upper 
						from temp_cont where Bin=&i;

						/* 为空的向后合并，如果是最后一个，则向前合并，并更新上下界限，再删除原bin。
						i1记录的是目标bin*/
						%if (&i=&Mbins) %then
							%do;
								select max(bin) into :i1 from temp_cont where Bin<&Mbins;
							%end;
						%else
							%do;
								select min(bin) into :i1 from temp_cont where Bin>&i;
							%end;

						%if &Ni1=0 %then
							%do;
								update temp_cont set 
									Ni2=Ni2+&Ni2 , 
									total=total+&Total 
								where bin=&i1;

								%if (&i<&Mbins) %then
									%do;
										update temp_cont set Bin_lowerlimit = &Bin_lower where bin=&i1;
									%end;
								%else
									%do;
										update temp_cont set Bin_upperlimit = &Bin_upper where bin=&i1;
									%end;

								delete from temp_cont where bin=&i;
							%end;
					%end;
			%end;
		quit;

		proc sort data=temp_cont;
			by pdv1;
		run;

		%local m;

		/* 把所有分类放到一个节点中作为一个字符点？（string point） */
		data temp_cont;
			set temp_cont;
			i=_N_;
			Var=bin;
			Bin=1;
			call symput("m", compress(_N_)); /* m=分类序号 */
		run;

		/* 循环变量所有节点 */
		%local Nbins;
		%let Nbins=1; /* 当前分箱的值 */

		/* 原代码使用MMax( 最大分箱数)控制循环。如果原等距分箱的结果中分箱数小于
			最大分箱数， 后面的循环中没有可拆分的bin时log窗口会报错。*/
		%let splitbin=%sysfunc(min(&m,&mmax));

		%DO %WHILE (&Nbins <&splitbin);

			/*%candsplite()每次拆分的结果由data步更新 temp_cont, 下一步的%candsplits()
			拆分的是更新的temp_cont*/
			%CandSplits(temp_cont, &method, Temp_Splits); /* 候选分类 */
			Data Temp_Cont;
				set Temp_Splits;
			run;

			%let NBins=%eval(&NBins+1);

		%end; /* end of the WHILE splitting loop  */

		/* 建立输出映射 */
		data temp_Map1;
			set temp_cont(Rename=Var=OldBin);
			drop Ni2 PDV1 Ni1 i;
		run;

		proc sort data=temp_Map1;
			by Bin OldBin;
		run;

		/* 合并分箱并计算分解 */
		data temp_Map2;
			retain  LL 0 UL 0 BinTotal 0;
				set temp_Map1;
				by Bin OldBin;
				Bintotal=BinTotal+Total;

				if first.bin then
					do;
						LL=Bin_LowerLimit;
						BinTotal=Total;
					End;

				if last.bin then
					do;
						UL=Bin_UpperLimit;
						output;
					end;

				drop Bin_lowerLimit Bin_upperLimit Bin OldBin total;
		run;

		proc sort data=temp_map2;
			by LL;
		run;

		data %if %superq(DSVarMap)= %then Map_&IVVar;
		%else &DSVarMap;
		;
		set temp_map2;
		Bin=_N_;
		run;

		/* Clean the workspace */
		proc datasets nodetails nolist;
			delete temp_bintot temp_blimits temp_cont temp_contold temp_cross temp_ds temp_map1
				temp_map2 temp_splits;
		run;
		quit;
		%let d=%eval(&d+1);
	%end;
	options notes;
%mend mybincont;
