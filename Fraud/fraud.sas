/* Loaded data to SAS data set. */
%ReadData(ext=csv)
/*copy data to lib and remove the dup*/
proc sort data=ori.fraud_train_samp1 out=train nodup;
	by _all_;
run;
proc sort data=ori.fraud_valdt_samp1 out=valid nodup;
	by _ALL_;
run;
/*Collecting the characteristic of the variables to create variable define dataset
* for decision tree, the key characteristics is variable class */
ods select none;
ods output NLevels=work.vlevel(rename=(tablevar=variable));
proc freq data=train(drop=csr_id) nlevels;
	table _all_ /missing nocum;
run;
ods output close;
ods select all;
/*using right join to include the csr_id*/
proc sql;
	create table work.vcat as
	select name, nlevels, nmisslevels, nnonmisslevels, type
	from work.vlevel as a right join 
		(select name, type from dictionary.columns 
			where libname="FRAUD" and memname="TRAIN") as b
		on a.variable=b.name;
quit;

/*export the vcat to an excel file and make the define manually.  */
%ToExcel(work.vcat,file=&pdir.vardefine.xlsx, sheet=vcat )
proc import datafile= "&pdir.vardefine.xlsx" out=var_define dbms=excel  replace;
	getnames=yes;
run;
/*set target, exclude and id to numeric*/
data var_define(rename=(targetn=target idn=id));
	set var_define;
	targetn=input(target, 3.);
	idn=input(id,3.);
	drop target id;
run;
/*training*/
%RFTrain(train,pdn=var_define,tn=200)
/*validation, and output a roc-like dataset for model evaluation*/
%RFValid(valid, csr_id, target, tn=200)
/*model evalute*/
proc sql noprint;
	select sum(target)/count(target)
	into :rho1
	from valid;
quit;
%ModelEval(score_val,  rho1=&rho1);
