/* Macro MissChk(): check the percent of missing value
*  and store the result in dataset loanmiss 
*  paras: 
*  dn: the name of the dataset
*  drop: the variable list that would be exclued if any*/
%macro MissChk(dn, drop);
	%if %superq(dn)= %then %do;
		%put ERROR: == The dataset name is missing ==;
		%return;
	%end;
	/*to void a unnecessary out put, close the notes, html, and listing */
	ods select none;
	ods noresults;

	options nonotes;
	proc format;
		 value $cmisscnt 	" "   = "CMissing"
							other = "Nonmissing";
		value	nmisscnt 	 .="NMissing"
							other="Nonmissing";
	run;
	ods output OneWayFreqs = work.mc_freq;
	proc freq data=&dn %if %superq(drop)^= %then (drop=&drop); %str(;)
		 tables _all_ / nocum missing;
		 format _character_   $cmisscnt. _numeric_ nmisscnt. ;
	run;

	%CombFreq(work.mc_freq)

	data &dn.miss;
		set work.mc_freq;
		where value in("NMissing","CMissing");
		if value="CMissing" then type="char";
		else type="num";
		keep variable Frequency percent type;
	run;

	proc sort data=&dn.miss;
		by percent variable;
	run;

	ods results;
	ods select ALL;
	options notes;

	%put NOTE: == The macro MissChk executed completed. ==;
	%put NOTE: == The result was stored in &dn.miss. ==;
%mend MissChk;
