/*input data define in user lib and data in ori lib*/
proc import datafile= "&pdir.vardefine.csv" 
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
/*input structure*/
data _null_;
	set var_define end=eof;
	length struc $1000;
	retain struc;
	if variable ne lag(variable) then do;
		struc=catx(" ", struc, variable);
		If type="char" then struc=catx(" ", struc, "$");
	end;
	if eof then call symputx("struc", struc);
run;

%ReadData(oriname=german.data, struc=&struc )
/*%ReadData(oriname=german_credit.csv)*/
/* create data set in user lib*/
proc sort data=ori.german nodup out=german_credit;
	by fault;
run;

/*transfer a char value to num value according to the variable define*/
%ReCode(var_define)
data credit;
	set german_credit;
	%include "&pout.ReCode.txt";
run;

/*split the data set to train set and valid set*/
proc sort data=credit;
	by fault;
run;
proc surveyselect data=credit out=work.credit_sampl outall 
		seed=1234 method=SRS rate=0.65 noprint;
	strata fault;
run;

data train valid;
	set work.credit_sampl;
	drop selected SelectionProb SamplingWeight;
	if selected = 1 then output train;
	else output valid;
run;

/*create vars data set to collect the general info. of variables*/
%VarExplor(train, vardefine=var_define)

proc sql;
	update vars set class="ordinal", normal=. 
	where variable in (&excp_class);
quit;
/*Discretize the numeric variables and collaspsing the levels of the char variables*/	
data _null_;
	set train nobs=obs;
	leafsize=ceil(obs*0.05);
	call symputx("leafsize", leafsize);
	put leafsize=;
	stop;
run;

%BinVars(train, leafsize=&leafsize, type=num)
%BinVars(train, leafsize=90, varlist= age, type=num)
%BinVars(train, leafsize=&leafsize,  type=nom)
/*modify the bin result of the numeric variables manually */
%ToExcel(bin_interval)
%BinUpdate(bin_interval,type=border)
/*create discretized code datasets and code files*/
%BinMap(bin_interval,type=num)
%BinMap(bin_nominal,type=nom)

data train1;
	set train;
	%include "&pout.bin_code_num.txt";
	%include "&pout.bin_code_nom.txt";
run;
/*calculate the woe*/
%WoeIv(train1) /*create woe_iv and iv dataset*/
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
data train1;
	set train1;
	%include "&pout.BinUpdate.txt";
run;
/*re-calculate the woe*/
%WoeIv(train1)
proc sql noprint;
	select quote(trim(variable)) into :plotlist separated by " "
	from vars
	where excluded ^=1 and class in ("interval","ordinal");
quit;
%plot(woe_iv, variable, bin, woe, &plotlist)

/*apply woe, create w_ variables*/
%WoeMap(train1) /*create woe_code.txt*/
data train1;
	set train1;
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
proc freq data=valid; 
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

/*update valid set*/
data valid1;
	set valid;
	%include "&pout.bin_code_num.txt";
	%include "&pout.bin_code_nom.txt";
	%include "&pout.BinUpdate.txt";
	%include "&pout.woe_code.txt";
run;

/*variable cluster and select the variable candidate*/
%vclus(train1) /*create varclusters dataset*/
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

/*Multicollinearity verification by Variance Inflation Factor(vif<5)*/
proc reg data=train1 ;
	model fault=&iv_select / vif;
	model fault=&rs_select / vif;
run;quit;
