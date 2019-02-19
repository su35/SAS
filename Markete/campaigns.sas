/*input data*/
%readdata(oriname=bank-additional-full.csv, delm=;);
/*remove the dup*/
proc sort data=ori.bank_additional_full out=bank_camp nodup;
	by _ALL_;
run;
/*According to the description, discard the variable duration*/
proc sql noprint;
	alter table bank_camp
		drop duration;
quit;
/*split dataset to training set and vaildation set. Basing on the rate of y(1/0) is 1:8,
	the train dataset will be oversampling*/
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

/*recoding the char variables to numeric variables*/
%recode(train1,recode)
data train1;
	set train1;
	%include re_code /source2;
run;

/*Create vars data set to collecte the characteristic of the variables */
ods output Summary=_n_summary;
proc means data=train1 n nmiss mean min max median q1 q3 qrange maxdec=2;
	var _numeric_;
run;
ods output close;
%let para=n nmiss;
%comb_summ(_n_summary, _summary, &para)

/**Create dataset vars to record the attributes of variables.**/
proc sql noprint;
	select 'count(distinct '||name||') as '||name, name 
	into :qlist separated by ",", :tranvars separated by " "
	from _summary;

	create table vars_n as
	select &qlist
	from train1;
quit;
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
	length class $8.;
	merge vars_n  _summary;
	by name;
	if nlevels=2 or index(name,"_n") then class="nomi";
	else class="cont";
	label miss="missing (%)";
	if nmiss ne 0 then miss=round(nmiss/(n+nmiss), 0.01);
	else miss=0;
	exclude=0;
	drop nmiss;
run;	
/*This dataset is prepared well. Althouth there is no missing value. If there ars missing value,
using the folloing code to handle them. 
data _null_;
	set vars end=eof;
	where miss>0;
	if _N_=1 then call execute('data train1; set train1;');
	call execute('miss_'||name||'=missing('||trim(name)||');');
	if eof then call execute('run;');
run;
/* replacing the missing value.  
proc sql noprint;
	select name into :mn separated by " "
	from vars
	where miss >0 and name ne "y_n";
quit;
proc stdize data=train1 reponly method=median 
				out=train2 outstat=inp_miss;
   var &mn;
run;*/


/*detect the distribution. check the histogram to comfire the distribution 
and modify it if necessary*/
proc sql noprint;
	select  name
		into :cont_list separated by " "
	from vars
	where name ne "y_n" and class="cont";
quit;

proc univariate data=train1 normal noprint
	outtable=_utable (keep=_var_ _min_ _max_ _q1_  _q3_  _qrange_   _probn_
		rename=(_var_=name _min_=min  _max_=max  _q1_=q1 _q3_=q3 
					_qrange_=qrange  _probn_ =pvalue));
	var &cont_list;
	histogram  / normal (noprint);
run;

proc sort data=_utable;
	by name;
run;
proc sort data=vars;
	by name;
run;
data vars;
	merge vars _utable;
	by name;
	lowout=q1-1.5*qrange;
	if lowout <= min then lowout=.;
	upout=q3+1.5*qrange;
	if upout =>max then upout=.;
	if not missing(pvalue) then do;
		if round(pvalue, .00001)>0.05 then normal=1;
		else normal=0;
	end;
	drop pvalue;
run;

/*correlation analysis*/
%b_corr(train1,y_n, vars,exclude )

/*Reduce redundancy, numeric variables cluste*/
proc sql noprint;
	select trim(name)
	into : candlist separated by " "
	from vars
	where exclude ne 1 and name ne "y_n";
quit;

ods output clusterquality=_varclusnum    rsquare=_varclusters;
proc varclus data=train1 maxeigen=.7 short ;
   var &candlist;
run;
ods output close;

data _null_;
   set _varclusnum;
   call symputx('ncl',numberofclusters);
run;

data _varclusters (drop=c2 numberofclusters controlvar) ;
	set _varclusters;
	retain c2;
	where numberofclusters=&ncl;
	if not missing(cluster) then 	c2=cluster;
	else cluster=c2;
run;
proc sort data=_varclusters;
	by cluster rsquareratio owncluster nextclosest;
run;
data _varclusters;
	set _varclusters;
	by cluster;
	if not first.cluster then cluster="";
run;

proc sql ;
	title "Selected variables";
	select variable into :cluselect separated by " "
	from _varclusters
	where not missing(cluster);

	%str_tran(cluselect)
	title "Continuous variables, check the linear relation";
	select name into :recheck separated by " "
	from vars
	where name in (&cluselect) and class="cont";
	title "Clusters";
	select cluster, variable, owncluster, nextclosest, rsquareratio
	from _varclusters;
	title;
quit;
/*verify the represent variable of each cluster manually, modify select1 if nessary */
%e_logit(train1, y_n, &recheck, 100)

/*check the outlier*/
%str_tran(recheck)
data _null_;
	set vars end=eof ;
	title "Percentage of Outlers";
	lastlow=0;
	where (not missing(lowout)  or not missing(upout)) and  name in (&recheck);
	if _N_ =1 then call execute('proc sql; select count(*) into:nob from train1;
									select ');
	if eof=0 then do;
		if not missing(lowout) then call execute('round(sum(case when '||name||'<'||lowout
			||'  then 1 else 0 end)/%str(&nob)*100,0.01) as '||trim(name)||'_low label "'||trim(name)||'_low (%)",');
		if not missing(upout) then call execute('round(sum(case when '||name||'>'||upout
			||' then 1 else 0 end)/%str(&nob)*100,0.01) as '||trim(name)||'_up label "'||trim(name)||'_up (%)" ,');
	end;
	else do;
		if not missing(lowout) then do;
			call execute('round(sum(case when '||name||'<'||lowout
					||' then 1 else 0 end)/%str(&nob)*100,0.01) as '||trim(name)||'_low label "'||trim(name)||'_low (%)"');
			lastlow=1;
			end;
		if not missing(upout) then do;
			if lastlow then call execute(',');
			call execute('round(sum(case when '||name||'>'||upout
					||' then 1 else 0 end)/%str(&nob)*100,0.01) as '||trim(name)||' label "'||trim(name)||'_up (%)" ');
			end;
		call execute('from train1;title;quit;');
	end; 
run;
%myBinCont(train1, y_n, previous, 4,3, 0.02)
%mapbin(train1,previous, bin, map)
%e_logit2(train1, y_n, previous, bin)
%myBinCont(train1, y_n, campaign, 4,10, 0.02)
%mapbin(train1,campaign, bin, map)
%e_logit2(train1, y_n, campaign, bin)
%myBinCont(train1, y_n, cons_conf_idx, 4,20, 0.02)
%mapbin(train1,cons_conf_idx, bin, map)
%e_logit2(train1, y_n, cons_conf_idx, bin)

proc sql;
	update vars
	set exclude =1
	where  name not in (&cluselect);
quit;

ods output ParameterEstimates =_ParameterEstimates;
proc logistic data = train1 des; 
	model y_n =&cluselect / selection=backward fast slstay=.001; 
run;
ods output close;

proc sql noprint;
	select variable, quote(trim(variable))  
	into :inmodel separated by " ", :selected separated by " "
	from _parameterestimates 
	where variable ne "Intercept";

	alter table vars
	add select1 num ;

	update vars
	set select1=1
	where name in (&selected);
quit;

/* Create the offset*/
%let pi1=.1127;
proc means data=train1;
	var y_n; 
	output out=_yfreq mean=ymean;
run;
data offset (keep=off pi1);
	set _yfreq;
     off=round(log(((1-&pi1)*ymean)/(&pi1*(1-ymean))),0.01);
     pi1=&pi1;
     call symputx("off", off);
run;
 data train1;
 	set train1;
	off=&off;
run;

/* ************* validation data prepare * ***********************/
/*missing indicator and offset
data _null_;
	set vars end=eof;
	where miss>0;
	if _N_=1 then call execute('data valid; set valid;if _N_=1 then set offset;');
	call execute('miss_'||name||'=missing('||trim(name)||');');
	if eof then call execute('run;');
run;*/
/* replacing the missing value.  
proc sql noprint;
	select name into :mn separated by " "
	from vars
	where miss >0 and name ne "y_n";
quit;
proc stdize data=valid out=valid1 reponly method=in(inp_miss);
   var &mn;
run;*/
/* Collaspsing the levels of variables as did in training dataset 
%app_cluslevel(valid1)*/
data valid;
	set valid;
	if _N_=1 then set offset(keep=off);
	%include re_code /source2;
run;
