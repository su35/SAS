/* **************************************************************************
* macro WoeIv: calculate the woe and iv. it will create 3 datasets
*                          WoeIv: detail for woe and iv
*                          iv: iv of variable level
*                          iverr: the group where has 0 positive or 0 negative
* dn: dataset name of which will be access
* pdn: dataset name of which store the variables description info.
* pref: the bin prefix of the numeric variable
* g: whether output graph. 0=no, 1=yes
* **************************************************************************/
%macro WoeIv(dn, pdn=vars, pref=b, g=0)/minoperator; 
	%if %superq(dn)= or %sysfunc(exist(&pdn))=0	%then %do;
		%put ERROR: The analysis dataset or variable description dataset is missing ;
		%return;
	%end;
	%local i wv_vlist wv_nvars wv_wtot_pos wv_wtot_neg wv_wtot_rec wv_vp1 wv_orivar;
	%put NOTE: == Calculate the woe and iv basing on &dn. The result was stored in woe_iv==;
	options nonotes;
	proc sql noprint;
		select variable, variable, class
		into :wv_var1- :wv_var999, :wv_vlist separated by " ", :wv_class1-:wv_class999
		from &pdn
		where excluded ne 1 and target ne 1;
		%let wv_nvars=&sqlobs;

		select variable into :wv_target
		from &pdn
		where target=1;

		select sum(&wv_target), sum(case when &wv_target=0 then 1 else 0 end), count(*)
		into :wv_wtot_pos, :wv_wtot_neg, :wv_wtot_rec
		from &dn;

		%if %existsVar(dn=vars, var=description)>0 %then
		select length into :desc_len
		from dictionary.columns
		where libname="%upcase(&pname)" and memname="VARS" 
			and upcase(name)="DESCRIPTION"%str(;) ;

		%if %sysfunc(exist(woe_iv)) %then drop table woe_iv;;
		%if %sysfunc(exist(binval)) %then drop table binval;;
	quit;

	%do i=1 %to &wv_nvars; 
		proc sql noprint;
			select case when missing(description) then (select description from &pdn
			where variable=(select ori_bin from &pdn where variable="&&wv_var&i"))
				else description end into :description
			from &pdn
			where variable="&&wv_var&i";

			create table work.tmp_woe 
			( variable char(32) label='Variable',
			   bin num label='Bin',
			   freq num label='Nomber of Record',
			   pct_bin_tot num label='Percent of Total Record',
			   pos num label='Positive',
			   dist_pos num label='Percent of Total Positive',
			   neg num label='Negative',
			   dist_neg num label='Percent of Total Negative',
			   pct_pos_bin num label='Percent of Positive',
			   class char(8),
			   woe num,
			   iv num,
			   newbin num,
			   exclu num,
			   discription char(&desc_len));
			insert into work.tmp_woe
			select "&&wv_var&i" as variable, &&wv_var&i as bin, count(*) as freq, 
				calculated freq/&wv_wtot_rec as pct_bin_tot, sum(&wv_target) as pos, 
				calculated pos/&wv_wtot_pos as dist_pos,
				sum(case when &wv_target=0 then 1 else 0 end) as neg, 
				calculated neg/&wv_wtot_neg as dist_neg,
				calculated pos/calculated freq as pct_pos_bin, "&&wv_class&i" as class,
				log((calculated pos/calculated neg)/(&wv_wtot_pos/&wv_wtot_neg)) as woe,
				((calculated pos/calculated neg)-(&wv_wtot_pos/&wv_wtot_neg))*calculated woe as iv,
				., ., %if %superq(description) ^= %then "&description"; %else ' '; as description
			from &dn(keep=&wv_target &&wv_var&i)
			group by &&wv_var&i;
		quit;

		proc append base=woe_iv data=work.tmp_woe;
		run;

		%if g=1 %then %do;
			proc sgplot data=work.tmp_woe;
				title "&&wv_var&i";
				series y=pos x=bin;
			run;
			proc sgplot data=work.tmp_woe;
				title "&&wv_var&i";
				series y=pct_pos_bin x=bin;
				series y=woe x=bin/ y2axis;
			run;
		%end;

		/*calculate the statistic value by group*/
		%if %upcase(%scan(&&wv_var&i, 1 , _)) =%upcase(&pref) %then %do;
			proc sql noprint;
				select ori_bin into :wv_orivar
				from &pdn
				where variable="&&wv_var&i";
			quit;
			proc means data=&dn(keep=&&wv_var&i &wv_orivar) median mean min max nway noprint; 
				class &&wv_var&i;
				var &wv_orivar;
				output out=work.tmp_binval(drop=_type_ _freq_ rename=(&&wv_var&i=bin))
					median=med_bin
					mean=mean_bin
					min=min_bin
					max=max_bin;
			run;

			data work.tmp_binval;
				length variable $32;
				set work.tmp_binval;
				variable="&&wv_var&i";
			run;
 
			%if %sysfunc(exist(binval)) %then %do;
				proc sql noprint;
					delete from binval where variable="&&wv_var&i";
				quit;
				proc append base=binval data=work.tmp_binval;
				run;
			%end;
			%else %do;
				data binval;
					set work.tmp_binval;
				run;
			%end;
		%end;
	%end;
	proc sql;
		create table iv as
		select distinct variable, sum(iv) as iv, max(bin) as binlevel
		from woe_iv
		group by variable;
		title "If any variable list bellow, it means that all responses are positive or negative in the bins. The re_bin is may needed";
		select variable, bin, pos, neg, iv
		from woe_iv
		where pos=0 or neg=0;
		title;
	quit;

	%if %sysfunc(exist(binval)) %then %do;
		proc sort data=woe_iv;
			by variable bin;
		run;
		proc sort data=binval;
			by variable bin;
		run;

		data woe_iv;
			merge woe_iv binval;
			by variable bin;
			label med_bin="Bin Median";
			label mean_bin="Bin Mean";
			label min_bin="Bin Min";
			label max_bin="Bin Max";
		run;
	%end;

	proc sort data=iv;
		by descending iv;
	run;
	data iv;
		set iv;
		adj=0;
		if iv=lag(iv) then adj+1;
		ivrank=_N_-adj;
		drop adj;
	run;

	proc npar1way data=&dn edf noprint;
		var &wv_vlist;
		class &wv_target; 
		output out=work.tmp_ks(keep=_var_ _D_  rename=(_var_=variable _D_=ks));
	run;

	proc sort data=work.tmp_ks; 
		by variable; 
	run; 
	proc sort data=iv; 
		by variable; 
	run;
	data iv;
		merge iv work.tmp_ks;
		by variable;
	run;
	options notes;
	%put NOTE: == Macro WoeIv runing completed. ==;
%MEND WoeIv; 

