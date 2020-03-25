/* ***************************************************************************
** macro RFValid: score the valid dataset and output the resault
** sdn: valid dataset 
** outdn: the name of output dataset
** tn: the number of trees 
** pth: the output path, the default is the RFRule fold under project fold 
**  **************************************************************************/
%macro RFValid(sdn, pdn=vars, outdn=, tn=50, pth=);
	%if %superq(sdn)= %then %do;
		%put ERROR: == The score dataset is required. ==;
		%return;
	%end;
	%if %superq(pth)= %then %let pth=&pdir.RFRule\;
	%if %superq(outdn)= %then %let outdn=RFScore;
	%local i id target totalp totaln total;
	options nonotes;

	proc sql noprint;
		select variable into :id trimmed
		from &pdn
		where id not is missing;

		select variable into :target trimmed
		from &pdn
		where target not is missing;
	quit;

	proc sort data=&sdn(keep=&id &target) out=work.rfv_valid;
		by &id;
	run;

	%let posp=p_&target.1;

	%do i=1 %to &tn;
		data work.tmp_valid;
			set &sdn;
			%include "&pth.&pname._rule&i..txt";
			p_&i=&posp;
			keep &id p_&i ;
		run;

		proc sort data=work.tmp_valid;
			by &id;
		run;

		data work.rfv_valid;
			merge work.rfv_valid work.tmp_valid;
			by &id;
		run;
	%end;

	data &outdn;
		set work.rfv_valid;
		prob=mean(of p_1-p_&tn);
		keep &id &target prob;
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
	proc datasets lib=work noprint;
	   delete rfv_: tmp_:;
	run;
	quit;

	options notes;
	%put  NOTE:  ==The macro RFValid executed completed. ==;
	%put  NOTE:  ==The score dataset &outdn was created.==;
%mend;
