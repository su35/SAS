/* **************************************************************************
** tdn: the training dataset
** pdn: the variable description dataset, the default is vars
** tn: the number of trees, the default is 1000 
** tsize: the size of each tree, the default is 50 
** obs: obs for each single tree, the default is 0.2 (20%)
** pth: the output path, the default is the outfile fold under project fold 
** *************************************************************************/
%macro RFTrain(tdn, pdn=vars, tn=1000, tsize=50, obs=0.2, pth=);
	%if %superq(tdn)= or %superq(pdn)= %then %do;
		%put ERROR: == The train dataset, parameter dataset, and target variable are required. ==;
		%return;
	%end;
	%if %superq(pth)= %then %let pth=&pout;

	%local i j;

	options nonotes;
	%do i=1 %to &tn;
		/*select variables (excluding target variable) randomly for each single tree*/
		proc surveyselect data=&pdn(where=(exclude ne 1)) 
				out=work._tvar sampsize=&tsize noprint;
		quit;

		proc sql noprint;
			select 	variable, class
			into :target, :tlevel
			from &pdn
			where target=1;

			select distinct class, count(distinct class)
			into :classlist separated by ' ', :classn
			from work._tvar;

			select 
				%do j= 1 %to &classn;
					%let class&j=%scan(&classlist, &j);
					case when class="&&class&j" then variable else '' end
					%if &j < &classn %then , ;
				%end;
				into 
				%do j=1 %to &classn;
					:&&class&j separated by ' '
					%if &j < &classn %then , ;
				%end;
			from work._tvar;
		quit;

		/*select  obs randomly for each single tree*/
		data work._tree;
			set &tdn.;
			x=ranuni(0);
			if x<=&obs;
		run;

		/*create decision tree*/
		Proc split data=work._tree outleaf=work.tmp_leaf  outimportance=work.tmp_importance 
					outtree=work.tmp_tree outmatrix=work.tmp_matrix outseq=work.tmp_seq 
			criterion=entropy
			assess=impurity 
			maxbranch=3
			maxdepth=5
			exhaustive=100
			leafsize=30
			splitsize=30
			subtree=assessment;
			code file="&pth.&pname._rule&i..txt";
			describe file="&pth.&pname._ruledescri&i..txt";
			%do j=1 %to &classn;
				%if %superq(&&class&j) ne %then input  &&&&&&class&j/ level=&&class&j; ;
			%end;
			target &target/level=&tlevel;
		run;
	%end;
	options notes;
	%put  NOTE:  ==The macro RFTrain executed completed. ==;
	%put  NOTE:  ==The score files were stored in &pth.==;
%mend;

