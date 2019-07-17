/*input data define in user lib and data in ori lib*/
proc import datafile= "&pdir.data\vardefine.csv" 
	out=var_define dbms=csv replace;
	guessingrows=max;
	getnames=yes;
run;
/*checking the variable name*/
data var_define;
	set var_define;
	length nid 8;
	variable=prxchange('s![^a-z_0-9]!_!i', -1, trim(variable));
 	variable=prxchange('s![_]{2,}!_!i', -1, trim(variable));
	nid=id;
	drop id;
	rename nid=id;
run;

/*input data*/
%ReadData(oriname=bank-additional-full.csv, delm=;);
/*check if there is continual "_" in the name of variables*/
proc sql;
	select memname, name
	from dictionary.columns
	where libname="ORI" and prxmatch("/[_]{2,}/", name);
quit;
/*remove the dup and copy to project lib*/
proc sort data=ori.bank_additional_full out=bank_camp nodup;
	by _ALL_;
run;
/*recoding the char variables to numeric variables*/
%ReCode(var_define)
data bank_camp;
	set bank_camp;
	%include "&pout.bank_camp_ReCode.txt";
run;
/*checke the positive rate*/
proc freq data=bank_camp;
	table y;
run;
/*split dataset to training set and vaildation set. Basing on the rate of y(1/0) is 1:8,
	the train dataset will be oversampling on rate 1:4*/
proc sort data=bank_camp;
	by y;
run;

proc surveyselect data=bank_camp out=bank_camp_sampl outall 
		seed=1234 method=SRS rate=0.80 noprint;
	strata y;
run;

data train valid;
	set bank_camp_sampl;
	drop selected SelectionProb SamplingWeight;
	if selected = 1 then output train;
	else output valid;
run;
proc surveyselect data=train out=train1(drop=SelectionProb SamplingWeight) 
		seed=1234 method=SRS rate=(0.5, 1) noprint;
	strata y;
run;

/*Create vars data set to collecte the attributes and characteristic of the variables */
%VarExplor(train1, vardefine=var_define);
proc sql;
	select *
	from freq
	where percent >=90;
quit;
proc sql;
	update vars set class="ordinal", normal=. 
	where variable ="pdays";
quit;

data _null_;
	set train1 nobs=obs;
	leafsize=ceil(obs*0.05);
	call symputx("leafsize", leafsize);
	put leafsize=;
	stop;
run;
/*Discretize the numeric variables and collaspsing the levels of the char variables*/	
%BinVars(train1, leafsize=&leafsize, type=num)
%BinVars(train1, leafsize=2500, varlist=age cons_conf_idx cons_price_ idx euribor3m, type=num)
%BinVars(train1, leafsize=&leafsize, type=nom)
/*modify the bin result of the numeric variables manually */
%ToExcel(bin_interval)
%BinUpdate(bin_interval,type=border)
/*create discretized code datasets and code files*/
%BinMap(bin_interval,type=num)
%BinMap(bin_nominal,type=nom)

data train2;
	set train1;
	%include "&pout.bin_code_num.txt";
	%include "&pout.bin_code_nom.txt";
run;
/*calculate the woe*/
/**********************************************/
%WoeIv(train2) /*create woe_iv and iv dataset*/
proc sql noprint;
	select quote(trim(variable)) into :plotlist separated by " "
	from vars
	where excluded ^=1 and class in ("interval","ordinal");
quit;
/*monotonicity checking*/
%plot(woe_iv, variable, bin, woe, &plotlist)
/*if the manual adjustment of the bin is required,
output the woe data to a xlxs file, and update the bin manually*/
%ToExcel(woe_iv)
%BinUpdate(woe_iv) /*output BinUpdate.txt*/
data train2;
	set train2;
	%include "&pout.BinUpdate.txt";
run;
/*re-calculate the woe*/
%WoeIv(train2)
proc sql noprint;
	select quote(trim(variable)) into :plotlist separated by " "
	from vars
	where excluded ^=1 and class in ("interval","ordinal");
quit;
%plot(woe_iv, variable, bin, woe, &plotlist)
/*apply woe, create w_ variables*/
%WoeMap(train2) /*create woe_code.txt*/
data train2;
	set train2;
	%include "&pout.woe_code.txt";
run;
/*check if any value in valid, but not in train. if there is a such value, modify the bin_*.txt file*/
proc sql noprint;
	create table work.tmp as
	select distinct variable 
	from (select distinct variable from bin_nominal) union
			(select distinct variable from BinUpdate where substr(variable, 1, 2) not in ("b_", "c_"));
	select variable into :f_list separated by " "
	from work.tmp;
quit;
ods output OneWayFreqs=work._freq;
proc freq data=valid  (drop=duration); 
	table &f_list  /missing nocum /*plots=freqplot*/;
run;
ods output close;
%CombFreq(work._freq, work._freq2)
title "The following variables, if any,  has value that exist in validation dataset only";
proc sql;
	select * 
	from (select variable, value from work._freq2) except (select variable, value from freq);
quit;
title;
/* update valid set, add id for model selection*/
data valid1;
	set valid;
	id=_N_;
	%include "&pout.bin_code_num.txt";
	%include "&pout.bin_code_nom.txt";
	%include "&pout.BinUpdate.txt";
	%include "&pout.woe_code.txt";
run;
/*variable cluster and select the variable candidate*/
%vclus(train2) /*create varclusters dataset*/
proc sql;
	create table varselect as
	select a.*, c.iv, c.binlevel, c.ks
	from (select * from varclusters) as a left join (select variable, ori_woe from vars) as b
	on a.variable=b.variable left join 
		(select * from iv) as c 
		on b.ori_woe=c.variable;
quit;
proc sort data=varselect;
	by clus_n descending iv rsquareratio binlevel;
run;
data _null_;
	set varselect end=eof;
	by clus_n;
	length selection $1000;
	retain selection;
	if first.clus_n then selection=catx(" ", selection, variable);
	if eof then call symputx("iv_select", selection);
run;
proc sort data=varselect;
	by clus_n rsquareratio descending iv;
run;
data _null_;
	set varselect end=eof;
	by clus_n;
	length selection $1000;
	retain selection;
	if first.clus_n then selection=catx(" ", selection, variable);
	if eof then call symputx("rs_select", selection);
run;

/*Multicollinearity verification by Variance Inflation Factor. Checking if there is vif>5*/
proc reg data=train2 ;
	model y=&iv_select / vif;
	model y=&rs_select / vif;
run;quit;
