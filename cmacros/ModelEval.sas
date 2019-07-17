/******************************************************************************
* Macro roc: evalute the model on roc datasets output by proc logistic 
* 			or other roc-like dataset
* 		rocdn- dataset created by outroc option
* 		pi1- proportions of target=1 in original dataset if oversampled and 
*			priorevent= was not specified
* 		rho1- proportions of target=1 in sample dataset
* 		matr- profit or cost matrix
* 		type- type of matrix, p=>profit c=>cost
* ****************************************************************************/
%macro ModelEval(rocdn, pi1=, rho1=, matr=, type=c);
	%if %superq(rocdn)=  or %superq(rho1)= %then %do;
		%put ERROR: === Parameter Error ===;
		%return;
	%end;
	%local p mn ksref costref;
	%let mn=%scan(&rocdn, -1, _);
	%if %superq(pi1)^= %then %let p=&pi1;
	%else %let p=&rho1;
	data &rocdn.1;
		set &rocdn;
		retain auc 0;
		%if %superq(pi1)^= %then cutoff=prob*&pi1*(1-&rho1)/(prob*&pi1*(1-&rho1)+
		    (1-prob)*(1-&pi1)*&rho1);
		%else cutoff=prob;
		;
		specif=1-fpr;
		tp=&p*sensit;
		fn=&p*(1-sensit);
		tn=(1-&p)*specif;
		fp=(1-&p)*fpr;
		depth=tp+fp;
		if 0<depth<1 then do;
			pospv=tp/depth;
			negpv=tn/(1-depth);
		end;
		else if depth=1 then do;
			pospv=tp;
			negpv=0;
		end;
		else do;
			pospv=0;
			negpv=tn;
		end;
		acc=tp+tn;
		lift=pospv/&p;
		ks=sensit-fpr;
		auc=auc + sum(sensit, lag(sensit))*abs(sum(fpr, -lag(fpr)))/2;

		%if %superq(matr)^= %then %do;
			%local m00 m01 m10 m11 parm;
			%let m00=%scan(&matr, 1, %str( ));
			%let m01=%scan(&matr, 2, %str( ));
			%let m10=%scan(&matr, 3, %str( ));
			%let m11=%scan(&matr, 4, %str( ));
			%if &type=c %then %let parm=cost;
			%else %if &type=p %then %let parm=profit;
			&parm=tn*&m00+fp*&m01+fn*&m10+tp*&m11;
		%end;
		keep cutoff tn fp fn tp sensit fpr specif depth pospv negpv acc lift ks auc
		%if %superq(matr)^= %then &parm ;%str(;)
	run;
	proc sql noprint;
		select cutoff 
		into :ksref
		from &rocdn.1
		having  ks=max(ks);

		select max(cutoff), max(auc) 
		into :max_cut, :auc
		from &rocdn.1;

		%if %superq(matr)^= %then %do;
			select cutoff 
			into :&parm.ref
			from &rocdn.1
			having  &parm=min(&parm);
		%end;
	quit;

	proc sgplot data=&rocdn.1;
		title "ROC Curve for the validation Data Set";
		title2 "auc=&auc";
		xaxis values=(0 to 1 by 0.1);
		series x=fpr  y=sensit /smoothconnect ;
		series x=fpr y=fpr;
	run;
	proc sgplot data=&rocdn.1;
		title "Lift Chart for  the model &mn";
		xaxis values=(0 to 1 by 0.1);
		series x=depth y=lift /smoothconnect ;
	run;
	proc sgplot data=&rocdn.1;
		title "KS Curve for the model &mn";
		xaxis values=(0 to 1 by 0.1);
		yaxis values=(0 to 1 by 0.1)  label="Sensitivity";
		y2axis values=(0 to 1 by 0.1)  label="1-Specif";
		series x=depth y=sensit /smoothconnect ;
		series x=depth y=fpr/y2axis smoothconnect  ;
		series x=depth y=ks/smoothconnect  ;
	run;
	proc sgplot data=&rocdn.1;
		title "Selected Statistics against Cutoff"; 
		xaxis values=(0 to &max_cut by 0.1);
		yaxis values=(0 to 1 by 0.1)  label="Sensitivity, Specif, depth, and PV+ ";
		series x=cutoff y=sensit /smoothconnect curvelabel="Sensitivity" lineattrs=(color=black);
		series x=cutoff y=specif/smoothconnect  curvelabel=" Specif" lineattrs=(color=blue);
		series x=cutoff y=depth/smoothconnect  curvelabel="Depth" curvelabelpos=start lineattrs=(color=green);
		series x=cutoff y=pospv/smoothconnect  curvelabel="PV+" lineattrs=(color="#8B008B") ;
		refline &ksref /axis= x  transparency=0.5  label="With Max KS cutoff = &ksref" 
				lineattrs=(color="#FF4500") labelpos=min labelloc=inside;
		%if  %superq(matr)^= %then %do;
			%local label;
			%if &type=c %then %let label=With Min Cost;
			%else %if &type=p %then %let label=With Max Profit;
			Y2AXIS label="&parm";
			series x=cutoff y=&parm /y2axis smoothconnect curvelabel="&parm" lineattrs=( color=red);
			refline &&&parm.ref /axis= x transparency=0.5 label="&label cutoff = &costref" 
				lineattrs=(color="#FF00FF") labelloc=inside;
		%end;
	run;
	title;
%mend ModelEval;
