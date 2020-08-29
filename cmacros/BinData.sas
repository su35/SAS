%macro BinData(dn, bdn=bin);
	%local i b1 b2 b3 b4 ;
	options nonotes noquotelenmax;
	proc sql noprint;
		select distinct branch into :b1-:b4
		from &bdn;
	quit;
	%let bnum=&sqlobs;

	%do i=1 %to &bnum;
		data work.bd_&&b&i;
			set &dn;
			%include "&pout.bin_&&b&i.._code.txt";
		run;

		%WoeIv(work.bd_&&b&i, &&b&i)
		options nonotes;
	%end;

	proc sql;
		create table woe as 
		%do i=1 %to &bnum;
			select * from work.bd_&&b&i.._woe %if &i^=&bnum %then union;
		%end;
		order by variable, branch, bin;
	quit;

	proc datasets lib=work noprint;
	   delete bd_: ;
	run;
	quit;

	options notes quotelenmax;

	%put NOTE: == The result was stored in &pout.&&dn._woe.xlsx==;
	%put NOTE: == Macro BinData excuted completed. ==;
%mend BinData;
