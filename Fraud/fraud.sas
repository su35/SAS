/* Loaded data to SAS data set. */
%readdata()
/*copy data to lib and remove the dup*/
proc sort data=ori.fraud_train_samp1_sheet1 out=train nodup;
	by _ALL_;
run;
proc sort data=ori.fraud_valdt_samp1_sheet1 out=valid nodup;
	by _ALL_;
run;
/*Create vars data set to collecte the characteristic of the variables */
ods output Summary=_n_summary;
proc means data=train n nmiss mean min max ;
	var _numeric_;
run;
ods output OneWayFreqs=_c_freq NLevels=_c_level(rename=(tablevar=name));
proc freq data=train nlevels;
	table _char_ /missing;
run;
ods output close;
%let para=n nmiss;
%comb_summ(_n_summary, _summary, &para)
%comb_freq(_c_freq, _c_freq)

proc sql noprint;
	create table vars_c as
	select a.name,  a.nlevels, c.n, case when b.frequency then b.frequency else 0 end as nmiss
	from(select name, nlevels from _c_level) as a left join 
		(select name,frequency from _c_freq where value="missing") as b on a.name=b.name left join 
		(select name, sum(frequency) as n from _c_freq where value ne "missing"
		group by name) as c on a.name=c.name
	order by 1;

	select 'count(distinct '||name||') as '||name, name 
	into :qlist separated by ",", :tranvars separated by " "
	from _summary;

	create table vars_n as
	select &qlist
	from train;
quit;

data vars_c;
	set vars_c;
	length class $8;
	type="char";
	if nlevels=2 then class="binary";
	else class="nominal";
run;
proc transpose data=vars_n out=_temp name=name;
	var &tranvars;
run;
proc sort data= _temp(rename=(col1=nlevels)) out=vars_n;
	by name;
run;
proc sort data=_summary;
	by name;
run;
data vars;
	label name="name"	;
	length type $4. class $8.;
	merge vars_n  _summary (in=num) vars_c;
	by name;
	if name="target" then target=1;
	if num then do;
		type="num";
		if nlevels<2 then class="binary";
		else class="interval";
	end;
	label miss="missing (%)";
	if nmiss ne 0 then miss=round(nmiss/(n+nmiss)*100);
	else miss=0;
	drop nmiss;
	if name not in('csr_id', 'close_dt');
run;	
/*Since the data is got from the internet, the meaning of the variables is unknown. 
  I simply define the continuous variable whose value levels less than 40 as ordinal */
data vars;
	set vars end=eof;
	if _N_=1 then call execute('proc freq data=train;	table');
	if class="interval" and  nlevels <40 then do;
		call execute(' '||trim(name));
		class="ordinal";
	end;
	if eof then call execute(';run;');	
run;

%rf_train(train,vars);
%rf_score(valid);
proc sort data=score out=_fttmp;
	by  descending pr;
run;

data _fttmp;
	set _fttmp nobs=obs;
	retain base;
	if _N_=1 then base=obs/100;
	bin=int((_N_-1)/base);
run;
proc sql noprint;
	select sum(target) 
	into  :fraud
	from _fttmp;

	create table fit as
	select distinct bin, count(target) as total, sum(target) as fraud, 
		round(mean(pr)*100) as pred, round(calculated fraud/calculated total*100) as actual
	from _fttmp
	group by bin;
quit;

data fit (drop=cum_t cum_f);
	set fit;
	retain cum_t cum_f;
	cum_t + total;
	cum_f + fraud;
	afpr=round(cum_t/cum_f);
	adr=round(cum_f/&fraud*100);
run;

proc sgplot data=fit;
	step y=adr x=afpr ;
	xaxis label='AFPR' values=(0 to 20 by 1);
	yaxis label='ADR' values=(0 to 100 by 10);
run;

/*check if a char variable is a numeric variable actually*/
proc sql;
	select name, value
	from _c_freq
	where prxmatch('/[^\d.\s-]/',value)>0 and value ne "missing";
quit;

