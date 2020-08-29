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
	options nonotes;
	proc transpose data =&ParamDS out=work.mpt(drop=_label_) name=model_item;
		id _type_;
	run;	

	proc sql;
		create table &cdn as
		select a.*, b.b_var,  ifc(missing(ori_var), b.b_var, ori_var) as ori_var, b.bin, border, 
				cluster, woe, -woe*coef * &beta as points
		from (select * from work.mpt(rename=(parms=coef)) where model_item ne '_LNLIKE_') 
			as a left join
			(select d_var, variable as b_var, bin, woe from woe_code) as b 
			on a.model_item=b.d_var left join
			(select d_var, variable as ori_var, bin, border, cluster from bin_code) as c 
			on b.b_var=c.d_var and b.bin=c.bin ;

		update &cdn set points=int(&alpha + &beta * coef)
		where upcase(model_item)="INTERCEPT";
	quit;

	proc datasets lib=work noprint;
	   delete mpt;
	run;
	quit;

	options notes;
	%put NOTE: == Dataset &cdn was created ==;
	%put NOTE: == Macro ScordCard running completed ==;
%mend ScordCard;
