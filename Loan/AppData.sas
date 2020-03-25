/* == create risk modeling dataset, the target variable is loan_status  == */
proc freq data=accepted_n;
	table loan_status/nocum;
run;
/* keep the obs that the loan status is charged off or full paid.*/
data riskmodel;
	set accepted_n;
	where  loan_status in (0, 1);
run;

proc sgplot data=riskmodel;
	density issue_d / group=term type=kernel;
run;

proc sql;
	select *
	from misswid
	where variable in (select variable from vardict where apply not is missing);
quit;
/* ==== Check missing value ==== */
%MissChk(riskmodel)
/* ==== create train and valid dataset ==== */
/*select the Sept. 2015-Nov. 2015 as model window. 
** the data from Dec. 2015 as validation data*/

proc sql noprint;
	select quote(trim(variable))
	into :dlist separated by " "
	from misswid
	where timepoint>='01OCT2015'd;

	create table vardictApp as 
		select *
		from vardict 
		where variable not in (&dlist) and apply not is missing and exclude is missing;

	select variable
	into :keeplist separated by " "
	from vardictApp;
quit;

/*drop the variables that was added after March 2012*/
data trainApp validApp;
	set riskmodel (keep= &keeplist);
	where '01SEP2015'd<= issue_d <'01JAN2016'd;
	if issue_d <'01DEC2015'd then output trainApp;
	else output validApp;
run;
/*get the population of loan_status, and compute offset*/
ods output OneWayFreqs=_freqt;
proc freq data=trainApp;
	table loan_status/nocum;
run;
ods output OneWayFreqs=_freqv;
proc freq data=validApp;
	table loan_status/nocum;
run;
ods output close;
proc sort data=trainApp;
	by loan_status;
run;
/*undersampling*/
proc surveyselect data=trainApp out=trainApp_samp(drop=SelectionProb SamplingWeight) 
		seed=1234 method=SRS rate=(0.3, 1) noprint;
	strata loan_status;
run;

ods output OneWayFreqs=_freqs;
proc freq data=trainApp_samp;
	table loan_status/nocum;
run;
ods output close;
/*computing the population ratio */
proc sql;
	create table loan_popu as
	select "loan_status" as variable, pi1, pi2, rho1, log(((1-pi1)*rho1)/(pi1*(1-rho1))) as off
	from (select table, percent/100 as pi1 from _freqt where loan_status=1) as a inner join 
	(select table, percent/100 as pi2 from _freqv where loan_status=1) as b on a.table=b.table inner join
	(select table, percent/100 as rho1 from _freqs where loan_status=1) as c on a.table=c.table;
	drop table _freqt, _freqv, _freqs;
quit; 

/*Transform the date value to the interval between that day and the issue day*/
/* The absolute value of some variables are not very meaningful as a single value, 
*   I will derive variables by transforming this value to the ratio value*/
proc sql noprint;
	select trim(variable)||"=intck('month', issue_d, "||trim(variable)||")",trim(variable)
	into :clist separated by ";", :flist separated by " "	
	from vardict
	where exclude is missing and variable ne "issue_d" and apply not is missing and
			variable in ( select name
							from dictionary.columns
							where libname="LOAN" and memname="TRAINAPP"
								and format="DATE9.") ;
quit;

data trainApp_1;
	set trainApp_samp;
	&clist;
	format &flist BEST12.;
	if missing(loan_amnt)=0 and loan_amnt ne 0 then inc_loan=annual_inc/loan_amnt;
	if missing(annual_inc)=0 and annual_inc ne 0 then install_inc=installment/annual_inc*12*100;
run;

options noquotelenmax;
data mapcode;
	code="&clist;
	format &flist BEST12.;";
	output;
	code= 'if missing(loan_amnt)=0 and loan_amnt ne 0 then inc_loan=annual_inc/loan_amnt;';
	output;
	code= 'if missing(annual_inc)=0 and annual_inc ne 0 then install_inc=installment/annual_inc*12*100;';
	output;
run;
options quotelenmax;
/*change the variable type to num for the variables that map to numeric type*/
proc sql noprint;
	select distinct quote(trim(variable))
	into : maplist separated by " "
	from charmap
	where variable in (select variable from  vardict where apply not is missing);
quit;

data vardictApp;
	set vardictApp end=eof;
	vid=_N_;
	if class="date" then do;
		if variable = "issue_d" then  exclude=1;
		else class="interval";
	end;
	if variable in (&maplist) then type="num";
	if variable="loan_status" then do;
		target=1;
		exclude=1;
		class="binary";
	end;
	if missing(id)=0 then exclude=1;
	output;
	if eof then do;
		vid+1;
		variable ="inc_loan";
		type="num";
		class="interval";
		description="The ratio of annual income to loan amount";
		output;
		vid+1;
		variable ="install_inc";
		type="num";
		class="interval";
		description="The percent of monthly payment owed to monthly income";
		output;
	end;
	drop apply;
run;
/*create vars data set to collect the general info. of variables*/
%VarExplor(trainApp_1, vardefine=vardictApp)
proc sql;
	select a.variable, type, class, n, nlevels, maxpercent, nmissing, exclude,pctmissing
	from (select distinct variable, max(percent) as maxpercent
			from freq
			group by variable 
			having maxpercent>95) as a left join vars as b on a.variable=b.variable;
quit;

/*==== Missing value Imputation ====*/
data MissCode;
	set vars;
	where exclude^=1 and nmissing>0;
run;
proc print data=misscode;
	where pctmissing<=20;
run; 

/*out put the misscode*/
filename misscode "&pout.misscode.txt";
data MissCode;
	set MissCode;
	length code $500;
	keep variable class nmissing pctmissing median mode code;
	if variable='bc_open_to_buy' 
		then code='if missing(bc_open_to_buy) then bc_open_to_buy='||median||';';
	if variable='bc_util' 
		then code='if missing(bc_util) then bc_util='||median||';';
	if variable='dti' 
		then code='if missing(dti) then dti='||mode||';';
	if variable='install_inc' 
		then code='if missing(install_inc) then install_inc='||max||';';
	if variable='mo_sin_old_il_acct' 
		then code='if missing(mo_sin_old_il_acct) then mo_sin_old_il_acct='||mode||';';
	if variable='mths_since_recent_bc' 
		then code='if missing(mths_since_recent_bc) then mths_since_recent_bc='||mode||';';
	if variable='mths_since_recent_inq' 
		then code='if missing(mths_since_recent_inq) then mths_since_recent_inq='||mode||';';
	if variable='num_tl_120dpd_2m' 
		then code='if missing(num_tl_120dpd_2m) then num_tl_120dpd_2m='||mode||';';
	if variable='percent_bc_gt_75' 
		then code='if missing(percent_bc_gt_75) then percent_bc_gt_75='||mode||';';
	if variable='revol_util' 
		then code='if missing(revol_util) then revol_util='||median||';';

	rc=fdelete(misscode);
	file misscode lrecl=2000;
	if not missing(code) then put code;
run;

data trainApp_1;
	set trainApp_1;
	%include "&pout.misscode.txt";
run;

filename mapcode "&pout.mapcode.txt";
data _null_;
	set mapcode;
	rc=fdelete("mapcode");
	file mapcode lrecl=32767;
	put code;
run;

/*== Discretize the numeric variables and collaspsing the levels of the char variables ==*/	
data _null_;
	set trainApp_1 nobs=obs;
	leafsize=ceil(obs*0.05);
	call symputx("leafsize", leafsize);
	put leafsize=;
	stop;
run;

/*Call macro BinVars to bin the variables by 4 methods. */
%BinVars(trainApp_1, leafsize=&leafsize)
dm 'odsresult; clear;';

/* == == Create discretized code datasets and code files == == */
%BinMap(bin)

/* == The following 3 macro is an interactive process which can be repeated if necessary. ==*/
%BinData(trainApp_1)
/*Output the woe data to a xlxs file,  the default open=y make the out file open automatically
*  unless setting the open to another value.
* Modify the bin if necessary .
* Since the update code using select (), when modify the bin the newbin should be include
* the whole bin set of the variable*/
%ToExcel(woe)
/*update dataset bin and bin_code. call macro binmap() to create discretized code*/
%BinUpdate(woe) 

/*== the last time run BinUpdate, and update the vars dataset  ==*/
%BinUpdate(woe, update=1) 

/*Modify the border of bin result of the numeric variables manually.
*  For example, change the age border from 20.5 to 20 or balance border 
*  from 1001 to 1000 which would make the result more clear business sense.
*  If the modification made, call macro BinUpdate(dataset_name,type=border) 
*  to update the dataset.*/
%ToCSV(bin, vlist=variable border description)
%BinUpdate(bin,type=border,file=csv)

filename code "&pout.bin_code.txt";
data _null_;
 	set bin_code;
	rc=fdelete("code");
	file code lrecl=32767;
	put code;
 run;
 data trainApp_woe;
 	set trainApp_1;
	%include "&pout.bin_code.txt";
run;
/*compute the woe value*/
%WoeIv(trainApp_woe)
/*create woe_code.txt, apply woe, create w_ variables in vars*/
%WoeMap(trainApp_woe)

data trainApp_woe;
	set trainApp_woe;
	%include "&pout.woe_code.txt";
run;
/*create the validation data set*/
data validApp1;
	set validApp;
	%include "&pout.misscode.txt";
	%include "&pout.mapcode.txt";
run;
/*exclude the two obs that annual income is 0*/
data validApp_woe;
	set validApp1;
	%include "&pout.bin_code.txt";
	%include "&pout.woe_code.txt";
run;

/* == variable cluster and calculate the variable's population stability index (PSI) ==*/
proc sql noprint;
	select variable, ori_woe
	into :vlist separated by " ", :psilist separated by " "
	from vars
	where ori_woe not is missing;
quit;
%PSI(trainApp_woe, validApp_woe, &psilist, outdn=VarPSI_woe)

/*create varclusters dataset, The default g=1 make the output of the graph 
*  unless setting the g to another value. The graphs show if the relation between logit(target)
*  and other variables are linear(or monotonous)*/
%vclus(trainApp_woe, vlist=&vlist) 
proc sql;
	create table work.varselect as
	select a.*, c.iv, c.binlevel, psi, c.ks, ifc(missing(ori_bin), ori_woe, ori_bin) as ori_var
	from (select * from varclusters) as a left join (select variable, ori_woe from vars) as b
	on a.variable=b.variable left join 
	(select * from iv) as c on b.ori_woe=c.variable left join
	(select variable, ori_bin from vars where ori_bin not is missing) as d
	on b.ori_woe=d.variable left join
	(select variable, psi from varpsi_woe) as e on b.ori_woe=e.variable;

	create table varselect_woe as
	select clus_n, a.variable, owncluster, nextclosest, rsquareratio, iv, binlevel, psi, ks, ori_var, 
			nmissing, pctmissing, description
	from work.varselect as a left join (select variable, nmissing, pctmissing, description from vars) as b
		on a.ori_var=b.variable;
quit;
proc sort data=varselect_woe;
	by clus_n descending iv  rsquareratio binlevel;
run;
proc print data=varselect_woe;
run;
