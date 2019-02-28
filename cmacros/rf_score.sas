
*代码2-2 模型打分代码;
%macro rf_score(sdn,tn, pth, outdn);
	%if %superq(sdn)= %then %do;
		%put ERROR: == The score dataset is required. ==;
		%goto exit;
	%end;
	%if %superq(tn)= %then %let tn=1000;
	%if %superq(pth)= %then %let pth=&pdir.rule/;
	%if %superq(outdn)= %then %let outdn=score;

	options nonotes;
	%do i=1 %to &tn;
		data work.score_&i;
			set &sdn;
			%include "&pth.&pname._rule&i..txt";
			p_&i=p_target1;
			keep csr_id p_&i ;
		run;

		proc sort data=work.score_&i.;
			by csr_id;
		run;
	%end;

	proc sort data=&sdn(keep=csr_id target) out=_tmp1;
		by csr_id;
	run;

	data &outdn;
		merge _tmp1 
		%do i=1 %to &tn;
			work.score_&i
		%end;;

		by csr_id;
		pr=sum(of p_1-p_&tn)/&tn;
		keep csr_id target pr;
	run;
	options notes;
%exit:
%mend;
