/* ***************************************************************************
** macro RFValid: score the valid dataset and output the resault
** sdn: valid dataset 
** outdn: the name of output dataset
** tn: the number of trees 
** pth: the output path, the default is the outfile fold under project fold 
**  **************************************************************************/
%macro RFValid(sdn, id, target, outdn=, tn=, pth=);
	%if %superq(sdn)= %then %do;
		%put ERROR: == The score dataset is required. ==;
		%return;
	%end;
	%if %superq(tn)= %then %let tn=1000;
	%if %superq(pth)= %then %let pth=&pout;
	%if %superq(outdn)= %then %let outdn=score_val;

	options nonotes;

	proc sort data=&sdn(keep=&id &target) out=work._valid;
		by &id;
	run;

	%do i=1 %to &tn;
		data work.tmp_valid;
			set &sdn;
			%include "&pth.&pname._rule&i..txt";
			p_&i=p_target1;
			keep &id p_&i ;
		run;

		proc sort data=work.tmp_valid;
			by &id;
		run;

		data work._valid;
			merge work._valid work.tmp_valid;
			by &id;
		run;
	%end;

	data &outdn;
		set work._valid;
		prob=mean(of p_1-p_&tn);
		keep &id target prob;
	run;

	proc sql noprint;
		select sum(&target), count(&target)
		into :totalp, :total
		from &outdn;
		%let totaln=%eval(&total-&totalp);
	quit;

	proc sort data=&outdn;
		by descending prob;
	run;

	data &outdn;
		length prob pos neg fpos fneg sensit fpr 8;
		set &outdn;
		retain pos fpos 0;
		if _N_=1 then do;
			neg=&totaln;
			fneg=&totalp;
		end;
		pos=pos+&target;
		fpos=fpos+(1-&target);
		neg=&totaln-fpos;
		fneg=&totalp-pos;
		sensit=pos/&totalp;
		fpr=fpos/&totaln;
	run;

	options notes;
	%put  NOTE:  ==The macro RFValid executed completed. ==;
	%put  NOTE:  ==The score dataset &outdn was created.==;
%mend;
