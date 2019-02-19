/**** run project_defination.sas once for new session *******
%let pathlen = %sysfunc(find(%sysget(SAS_EXECFILEPATH),%str(\),-260));
%let path=%substr(%sysget(SAS_EXECFILEPATH), 1 , &pathlen);
%include "&path.project_defination.sas";
**************************************************************//* =========== Create Demographic Summary Table =========== */
proc sort data=addm;
	by trtpn;
run;
/* *******************************************************************************
* "blankno" define the indentation of sub-term. 
* for listing output, using the number of blanks 
* for HTML output, using a "&#160;", and use javascript and CSS file to control the indentation
* **************************************************************************************/
data _null_;
	call symput("blankno",'&#160;');
	call dm_summary_set("addm", "age sex race educatyr employ maritals","trtp trtpn","n mean median min max");
run;

/* ==== Create AE Summary Table, Count AE on Aesoc ============ */
proc sort data=adae; 
	by aesoc;
run;
proc sql noprint;
		create table _aesoc as
			select distinct aesoc
			from adae;
quit;
data _null_;
	set _aesoc;
	call symput("blankno",'&#160;');
	call ae_summary_set("adae", aesoc);
run;

/*analysis dataset*/
proc sql;
	create table anur as 
		select a.usubjid, trtp, trtpn, a.avisitn, (trtedt-trtsdt+1) as enday ,
				case when calculated enday <84 then  calculated enday  else 84 end as lastday,
				ceil((calculated lastday)/7) as lastweek, a.ady,  weekval, base,
				case when sum(crit1fn) =0 then 0 else 1 end as f_value, 
				case when calculated lastday< 84 then 1 else 0 end as drop_censor
			from adur as a, 
				(select usubjid, avisitn, ady, case when sum(crit1fn) = 0 then 0 else 1 end as weekval
					from adur 
					group by usubjid, avisitn) as b,
					adsl as d
			where a.usubjid=b.usubjid and a.avisitn=b.avisitn and a.usubjid=d.usubjid
					and a.ady=b.ady and a.avisitn between 1 and 12
			group by a.usubjid
			order by base, a.usubjid, a.ady;
quit;
/*data for Study retention for the topiramate and placebo groups*/
proc sort data = anur out = comp_status nodupkey;
	by usubjid;
run;
ods select none;
ods output ProductLimitEstimates = survivalist  HomTests=_survpval;
proc lifetest   data = comp_status;
   time lastday * drop_censor(0);
   strata trtp; /*trtp can be used as refer name*/
run;
ods output close;
ods select all;

/*************************************************
* Prepare analysis dataset for main study week
*************************************************/
proc sort data= anur  
			out=anmain (keep=usubjid trtpn trtp avisitn weekval base drop_censor);
	where avisitn between 6 and 12;
	by usubjid;
run;

proc sort data=anmain nodup;
	by base;
run;


/* *********************************************************************************************
* The percentage of subjects with a negative methamphetamine use week in study weeks
* **********************************************************************************************/
ods select none;
ods output crosstabfreqs=base_weekval;
proc freq data=anmain;
	by base;
	table trtp*avisitn*weekval /cmh missing;
	output out=pvalue_bw cmh;
run;
ods output close;
ods select all;

proc sort data=base_weekval;
	by trtp avisitn base;
run;

data base_weekval;
	length ppcent tpcent 6.2;
	retain ppcent tpcent;
	set base_weekval;
	keep base trtp avisitn weekval ppcent tpcent ;
	where weekval=0 and avisitn ne .;
	if base =0 then ppcent=rowpercent;
	if base=1;
	tpcent=rowpercent;
run;

ods output  GEEEmpPEst =_gee_pvalue FitPanel=_gee_fit;
ods graphics on;
proc genmod data=anmain;
	class usubjid trtp ;
	model weekval=trtp avisitn trtp*avisitn / dist=bin;
	repeated subject=usubjid ;
	effectplot fit (plotby=trtp x=avisitn);
*	lsmeans armcd*weeks/means ;
run;
ods graphics off;
ods output close;

proc sql;
	create table gee_means as 
	select _plotby as trtp, _xcont1 as weeks, _predicted*100 as means, floor(_xcont1) as week, mean(_predicted)*100  as week_mean
		from _gee_fit
		group by trtp, calculated week;
quit;
