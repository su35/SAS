/* ************************************************
** FRAUD_TRAIN_SAMP1: 目标变量Y为"TARGET"列
** FRAUD_VALDT_SAMP1: 与FRAUD_TRAIN_SAMP1对应的验证集
** FRAUD_TRAIN_SAMP2: 是另一个样例数据
** ************************************************/
%macro rf_train(tdn, pdn, tn, tsize, obs, pth);
	%if %superq(tdn)= or %superq(pdn)= %then %do;
		%put ERROR: == The train dataset, parameter dataset, and target variable are required. ==;
		%goto exit;
	%end;
	%if %superq(tn)= %then %let tn=1000;
	%if %superq(tsize)= %then %let tsize=50;
	%if %superq(obs)= %then %let obs=0.2;
	%if %superq(pth)= %then %do;
		%if %sysfunc(fileexist(&pdir.rule))=0 %then %do;
			data _null_;
				NewDir=dcreate("rule","&pdir");
			run; 
		%end;
		%let pth=&pdir.rule/;
	%end;

	%local i j;

*	options nonotes;
	%do i=1 %to &tn;
		/*select variables (excluding target variable) randomly for each single tree*/
		proc surveyselect data=&pdn(where=(target ne 1)) 
				out=_tvar sampsize=&tsize noprint;
		quit;

		proc sql noprint;
			select 	case when target=1 then name else '' end,
				case when target=1 then class else '' end
			into :target separated by '', :tlevel separated by ''
			from &pdn;

			select distinct class, count(distinct class)
			into :classlist separated by ' ', :classn
			from _tvar;

			select 
				%do j= 1 %to &classn;
					%let class&j=%scan(&classlist, &j);
					case when class="&&class&j" then name else '' end
					%if &j < &classn %then , ;
				%end;
				into 
				%do j=1 %to &classn;
					:&&class&j separated by ' '
					%if &j < &classn %then , ;
				%end;
			from _tvar;
		quit;

		/*select  obs randomly for each single tree*/
		data step01;
			set &tdn.;
			x=ranuni(0);
			if x<=&obs;
		run;

		/*create decision tree*/
		Proc split data=step01 outleaf=work.leaf  outimportance=work.importance 
					outtree=work.tree outmatrix=work.matrix outseq=work.seq 
			criterion=entropy
			assess=impurity 
			maxbranch=3
			maxdepth=5
			exhaustive=100
			leafsize=30
			splitsize=30
			subtree=assessment;
			code file="&pth.&pname._rule&i..txt";
			describe file="&pth.&pname._ruledescri&i..txt";
			%do j=1 %to &classn;
				%if %superq(&&class&j) ne %then input  &&&&&&class&j/ level=&&class&j; ;
			%end;
			target &target/level=&tlevel;
		run;
	%end;
*	options notes;
%exit:
%mend;

