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
%macro WoeIv(dn, branch, bindn=bin, pdn=vars, g=0)/minoperator; 
	%if %superq(dn)= or %sysfunc(exist(&pdn))=0	%then %do;
		%put ERROR: The analysis dataset or variable description dataset is missing ;
		%return;
	%end;
	%local i varlist classlist orilist nvars var class ori target TotPos TotNeg total orivar;
	options nonotes noquotelenmax;

	proc sql noprint;
		%if %superq(branch)= %then 
			select variable, class, ifc(bin_var, ori_bin, variable)
			into :varlist separated by " ", :classlist separated by " ", :orilist separated by " "
			from &pdn
			where exclude is missing and target is missing and id is missing and
				variable not in (select ori_bin from vars where ori_bin not is missing);
		%else 
			select distinct d_var, class, variable 
			into :varlist separated by " ", :classlist separated by " ", :orilist separated by " "
			from &bindn where branch="&branch";
		;
		%let nvars=&sqlobs;

		select variable into :target
		from &pdn
		where target not is missing;

		select sum(&target), sum(case when &target=0 then 1 else 0 end), count(*)
		into :TotPos, :TotNeg, :total
		from &dn;

		create table work.wi_woe 
		( variable char(32) label='Variable',
		  ori_var char(32) label="Original Variable",
		   bin num label='Bin',
		   freq num label='Nomber of Record',
		   BinfreqTot num label='Percent of Total Record',
		   pos num label='Positive',
		   PosPtot num label='Percent of Total Positive',
		   neg num label='Negative',
		   NegNtot num label='Percent of Total Negative',
		   class char(8),
		   woe num,
		   iv num,
		   newbin num,
		   exclu num,
		   branch char(8),
		   elogit num,
		   maxfreq num
			);

		%if %sysfunc(exist(&dn._woe)) %then drop table &dn._woe%str(;);
	quit;

	%do i=1 %to &nvars; 
		%let var=%scan(&varlist, &i, %str( ));
		%let class=%scan(&classlist, &i, %str( ));
		%let ori=%scan(&orilist, &i, %str( ));
		proc sql noprint;
			insert into work.wi_woe
			select *, max(binfreqtot) as maxfreq 
			from(select "&var" as variable, "&ori" as ori_var, &var as bin, count(*) as freq, 
					calculated freq/&total as BinfreqTot, sum(&target) as pos, 
					calculated pos/&TotPos as PosPtot,
					sum(case when &target=0 then 1 else 0 end) as neg, 
					calculated neg/&TotNeg as NegNtot,
					"&class" as class, 
					log((ifn(calculated pos=0, 0.01, calculated pos)/&TotPos)/
						(ifn(calculated neg=0, 0.01, calculated neg)/&TotNeg)) as woe,
					(calculated PosPtot-calculated NegNtot)*calculated woe as iv, 
					., ., %if %superq(branch)^= %then "&branch"; %else " "; as branch, 
					log((calculated pos+(sqrt(calculated freq)/2))/
							(calculated neg+(sqrt(calculated freq)/2))) as elogit
				from &dn(keep=&target &var)
				group by &var);
		quit;
	%end;
	
	proc sql;
		update work.wi_woe set exclu=1
			where maxfreq>0.95;
		alter table work.wi_woe drop maxfreq;
	quit;

	%if %existsVar(dn=&pdn, var=description)>0 %then %do;
		proc sql;
			create table work.wi_woe2 as
			select a.ori_var, a.bin, a.freq, a.pos, a.BinfreqTot, a.PosPtot,a.class,a.woe,a.iv,a.variv, 
				a.newbin, a.exclu,a.branch, case when missing(b.description) then c.description else
 					b.description end as description,a.variable, a.neg,a.NegNtot,a.elogit
			from (select * , sum(iv) as variv from work.wi_woe group by variable, branch) as a left join 
					(select  variable, description from &pdn) as b 
					on  a.variable=b.variable left join
					(select variable, description from &pdn) as c on a.ori_var=c.variable
			order by variable, %if %superq(branch)^= %then branch,; bin;
		quit;

		data work.wi_woe;
			set work.wi_woe2;
			by variable;
			if first.variable=0 then description=" ";
		run;
	%end;
		
	proc append base=&dn._woe data=work.wi_woe;
	run;

	%if %superq(branch)= %then %do;
		proc datasets nolist nowarn;
		%if %sysfunc(exist(woe)) %then delete woe%str(;);
			change trainApp_woe_woe=woe ;
		run;
		quit;

		proc sql;
			create table iv as
			select distinct variable, variv as iv, max(bin) as binlevel
			from woe
			group by variable;
		quit;

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
			var &varlist;
			class &target; 
			output out=work.wi_ks(keep=_var_ _D_  rename=(_var_=variable _D_=ks));
		run;

		proc sort data=work.wi_ks; 
			by variable; 
		run; 

		proc sort data=iv; 
			by variable; 
		run;

		data iv;
			merge iv work.wi_ks;
			by variable;
		run;
		options notes;
		%put NOTE: == Calculate the woe and iv basing on &dn. The result was stored in woe ==;
		options nonotes;
	%end;

	proc datasets lib=work noprint;
	   delete wi_: ;
	run;
	quit;

	options quotelenmax notes;
	%put NOTE: == Macro WoeIv runing completed. ==;
%MEND WoeIv; 

