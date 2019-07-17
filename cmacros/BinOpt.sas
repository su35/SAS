/* ********************************************************************************
* macro BinOpt: Optimal binning of continuous variables.
* dn: dataset name of which will be access
* pdn: dataset name of which store the variables description info.
* target: target variable;
* varlist: The list of variables which will be discretized 
* MMax: Maximum number of bins
* code_pth: group code output path. The default is outfiles folder under the project folder;
* Acc: the accuracy level definition of the bin. The value is between 0 and 1.The smaller the 
		Acc value, the longer it takes, but the higher the accuracy of the result.
* method:  1=Gini  2=Entory  3=Pearson's Chi2  4=Information Value 
* ***************************************************************************************/
%macro BinOpt(dn, pdn=vars, target=, varlist=, Method=4, MMax=10, Acc=0.05,
		code_pth=)/minoperator;
	/* find the maximum and minimum values */
	options nonotes;

	%if %superq(dn)= %then %do;
		%put ERROR: The analysis dataset is missing ;
		%return;
	%end;
	%if %superq(code_pth)=  %then %let code_pth=&pout;
	%if %superq(varList)^= %then %StrTran(varlist);
	proc sql noprint;
		select name into :bo_var1-:bo_var999
		from &pdn
		%if %superq(varList)= %then where lowcase(class)="interval" and target ne 1%str(;);
		%else where upcase(name) in (%upcase(&varlist))%str(;);
		%let bo_nvars=&sqlobs;

 		%if %superq(target)= %then
		select name into :target from &pdn where target =1%str(;) ;

		%if %sysfunc(exist(BinOptim)) %then drop table BinOptim;%str(;) ;
	quit;  

	%local i j VarMax VarMin Mbins MinBinSize;
	%do i=1 %to &bo_nvars;
		proc sql noprint;
			select floor(min(&&bo_var&i)), ceil(max(&&bo_var&i)) into :VarMin, :VarMax from &dn;
		quit;

		/* 根据Acc等距分箱 */
		%let Mbins=%sysfunc(int(%sysevalf(1.0/&Acc)));
		%let MinBinSize=%sysevalf((&VarMax-&VarMin)/&Mbins);

		/* 计算最大及最小值之间的分箱界限 */
		%do j=1 %to %eval(&Mbins);
			%local Lower_&j Upper_&j;
			%let Upper_&j = %sysevalf(&VarMin + &j * &MinBinSize);
			%let Lower_&j = %sysevalf(&VarMin + (&j-1)*&MinBinSize);
		%end;

		/* 拆分bins */
		data work.tmp_DS;
			set &dn;
			%do j=1 %to %eval(&Mbins-1);
				if &&bo_var&i>=&&Lower_&j and &&bo_var&i < &&Upper_&j Then
					Bin=&j;
			%end;
			if &&bo_var&i>=&&Lower_&Mbins and &&bo_var&i <= &&Upper_&MBins Then
				Bin=&MBins;
			keep &&bo_var&i &target Bin;
		run;

		/* 生成每个箱的上下限的数据集 */
		data work.tmp_blimits;
			%do j=1 %to %Eval(&Mbins-1);
				Bin_LowerLimit=&&Lower_&j;
				Bin_UpperLimit=&&Upper_&j;
				Bin=&j;
				output;
			%end;
			Bin_LowerLimit=&&Lower_&Mbins;
			Bin_UpperLimit=&&Upper_&Mbins;
			Bin=&Mbins;
			output;
		run;

		proc sort data=work.tmp_blimits;
			by Bin;
		run;

		/* 计算目标变量的频率 */
		proc freq data=work.tmp_DS noprint;
			table Bin*&target /out=work.tmp_cross;  /* 输出变量Bin、&target、Count、Percent */
			table Bin /out=work.tmp_BinTot; /* 输出变量Bin、Count、Percent */
		run;

		/* 根据分组排序 */
		proc sort data=work.tmp_cross;
			by Bin;
		run;

		proc sort data= work.tmp_BinTot;
			by Bin;
		run;

		data work.tmp_cont; /* contingency table 列联表 */
			merge work.tmp_cross(rename=(count=Ni2) ) work.tmp_BinTot(rename=(count=total)) work.tmp_blimits;
			by Bin;
			Ni1=total-Ni2;
			PDV1=bin; /* 原始分箱段号 just for conformity with the case of nominal IV */
			label  Ni2= total=;

			/* 只输出&target=1及bin下只有&target=0的 
				如果Ni1=0,说明该bin中只有一种情况：要么都是&target=1，要么都是&target=0
				_cross表及_BinTot表里仅包括bin里有数据的，所以merge后的表里的
				没有数据的bin的Ni1和target都是missing value, 也就过滤了*/
			if Ni1=0 then output;
			else if &target=1 then output;
			drop percent &target;
		run;

		data work.tmp_contold;
			set work.tmp_cont;
		run;

		/* 合并所有 Ni1 =0 的bin。work.tmp_cont表里不存在 Ni2，total为0的数据*/
		proc sql noprint;
			select quote(trim(put(bin,8.-L))) into :bins separated by " "
				from work.tmp_cont;

			%do j=1 %to &Mbins;
				%if "&j" in (&bins) %then %do;
					select Ni1, Ni2, total, bin_lowerlimit, bin_upperlimit into 
						:Ni1,:Ni2,:total, :bin_lower, :bin_upper 
					from work.tmp_cont where Bin=&j;

					/* 为空的向后合并，如果是最后一个，则向前合并，并更新上下界限，再删除原bin。
					i1记录的是目标bin*/
					%if (&j=&Mbins) %then 	%do;
						select max(bin) into :j1 from work.tmp_cont where Bin<&Mbins;
					%end;
					%else %do;
						select min(bin) into :j1 from work.tmp_cont where Bin>&j;
					%end;

					%if &Ni1=0 %then %do;
						update work.tmp_cont set 
							Ni2=Ni2+&Ni2 , 
							total=total+&Total 
						where bin=&j1;

						%if (&j<&Mbins) %then %do;
							update work.tmp_cont set Bin_lowerlimit = &Bin_lower where bin=&j1;
						%end;
						%else %do;
							update work.tmp_cont set Bin_upperlimit = &Bin_upper where bin=&j1;
						%end;

						delete from work.tmp_cont where bin=&j;
					%end;
				%end;
			%end;
		quit;

		proc sort data=work.tmp_cont;
			by pdv1;
		run;

		%local m;

		/* 把所有分类放到一个节点中作为一个字符点？（string point） */
		data work.tmp_cont;
			set work.tmp_cont;
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

		%do %while (&Nbins <&splitbin);
			/*%candsplite()每次拆分的结果由data步更新 work.tmp_cont, 下一步的%candsplits()
			拆分的是更新的_cont*/
			%CandSplits(work.tmp_cont, &method, work.tmp_Splits); /* 候选分类 */
			Data work.tmp_Cont;
				set work.tmp_Splits;
			run;
			%let NBins=%eval(&NBins+1);
		%end; /* end of the WHILE splitting loop  */

		/* 建立输出映射 */
		data work.tmp_Map1;
			set work.tmp_cont(Rename=Var=OldBin);
			drop Ni2 PDV1 Ni1 i;
		run;
		proc sort data=work.tmp_Map1;
			by Bin OldBin;
		run;

		/* 合并分箱并计算分解 */
		data work.tmp_Map2;
			length var $32;
			set work.tmp_Map1;
			by Bin OldBin;
			var="&&bo_var&i";
			d_var="b_"||substr(var, 1, 30);
			rename Bin_upperLimit=border;

			if last.bin then output;

			drop Bin_lowerLimit  Bin OldBin total;
		run;

		proc sort data=work.tmp_map2 out=work.tmp_map3;
			by border;
		run;

		data work.tmp_map3;
			set work.tmp_map3 end=eof;
			bin=_N_;
			if eof then nlevels=bin;
		run;

		proc append base=BinOptim data=work.tmp_map3;
		run;
/*		data work.tmp_cde;
			set work.tmp_map3 end=eof;
			length code $5000 var d_var $32;
			retain code var d_var;
			var="&&bo_var&i";
			d_var="bin_"||substr(var, 1, 28);

			if work.tmp_N_=1 then code=catx(" ","if &&bo_var&i<=",ul," then "||trim(d_var)||"=",_N_,";");
			else code=catx(" ",code,"else if &&bo_var&i<=",ul,"then "||trim(d_var)||"=",_N_,";");
			if eof then do;
				code=catx(" ",code,"else "||trim(d_var)||"=",_N_+1,";");	
				bin=_N_;
				output;
			end;
			keep var d_var code bin;
		run;

		proc append base=bin_code_opt data=work.tmp_cde;
		run;*/

/*		data  Map_&&bo_var&i;
		set work.tmp_map3;
		Bin=_N_;
		run;*/
	%end;
/*	%if %sysfunc(exist(bin_code_opt)) %then %do;
		filename code "&code_pth.bin_code_opt.txt";
		data _null_;
	 		set bin_code_opt;
			rc=fdelete("code");
			file code lrecl=32767;
			put code;
	 	run;

		proc sql noprint;
			update &pdn set excluded=1 where name in (
				select distinct name from bin_code_opt);

			%if not %existsVar(dn=&pdn, var=ori_bin) %then
			alter table &pdn add ori_bin char(32)%str(;);

			create table work.tmp_vars as
			select distinct d_var as name,  "num" as type length=4,  "ordinal" as class length=8, 
				bin as nlevels length=8, 1 as derive_var length=3, var as ori_bin
			from bin_code_opt;
		quit;
	%end;*/
	options notes;
	%put NOTE:  ==== Macro BinOpt running complete ====;
%mend BinOpt;
