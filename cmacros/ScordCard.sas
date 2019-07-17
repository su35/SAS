/* *********************************************************************************
* macro ScordCard: create scorecard dataset
* params:
* 		paramds: model params dataset
* 		basepoints: base score
* 		baseodds: odds ratio at the base point
* 		pdo: score of ratio doubling
* 		cdn: name of output scorecard dataset
* *********************************************************************************/
%macro ScordCard(ParamDS, BasePoints, BaseOdds, PDO, cdn);
	%local alpha beta;
	%let beta=%sysevalf(&PDO / %sysfunc(log(2)));
	%let alpha=%sysevalf(&BasePoints - &beta * %sysfunc(log(&BaseOdds)));

	proc transpose data =model_parm out=work.mpt(drop=_label_) name=model_item;
		id _type_;
	run;	

	data work.mpt;
		set work.mpt;
		rename parms=coef;
		if model_item ne '_LNLIKE_' ;
	run;

	proc sql;
		create table &cdn as
		select a.*, b.b_var, 
			case when not missing(c.ori_var) then c.ori_var
				when not missing(d.ori_var) then d.ori_var else b.b_var end as ori_var, 
			b.bin, border, ori_val, woe, -woe*coef * &beta as points
		from (select * from work.mpt) as a left join
			(select d_var, variable as b_var, bin, woe from woe_code) as b 
			on a.model_item=b.d_var left join
			(select d_var, variable as ori_var, bin, border from bin_code_num) as c 
			on b.b_var=c.d_var and b.bin=c.bin left join
			(select d_var, variable as ori_var, cluster, value as ori_val from bin_nominal) as d 
			on b.b_var=d.d_var and b.bin=d.cluster;

		update &cdn set points=int(&alpha + &beta * coef)
		where upcase(model_item)="INTERCEPT";
	quit;
	%put NOTE: == Dataset &cdn was created ==;
	%put NOTE: == Macro ScordCard running completed ==;
%mend ScordCard;
