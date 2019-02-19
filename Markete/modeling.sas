/*  Building logistic model */
data _null_;
	set offset;
	call symputx('pi1', pi1);
run;
proc sql noprint;
	select name  
	into :inmodel separated by " "
	from vars 
	where select1=1;
quit;
proc logistic data=train1 des outest=logpara;
	model y_n=&inmodel /offset=off ;
	score data=valid out=scored priorevent=&pi1 outroc=roc fitstat;
run;

data roc;
	set roc;
	retain total;
	if _N_=1 then total=sum(of _pos_ -- _falneg_);
	cutoff=_PROB_;
	specif=1-_1MSPEC_;
	tp=_pos_/total;
	tn=_neg_/total;
	fp=_falpos_/total;
	fn=_falneg_/total;
	depth=tp+fp;
	pospv=tp/depth;
	negpv=tn/(1-depth);
	acc=tp+tn;
	lift=pospv/&pi1;
	keep cutoff tn fp fn tp _SENSIT_ _1MSPEC_ specif depth pospv negpv acc lift;
run;
/* Use the NPAR1WAY procedure to get the  Kolmogorov-Smirnov D Statistic 
	and  the Wilcoxon-Mann-Whitney Rank sum test */
proc npar1way edf wilcoxon data=scored;
	class y_n;
	var p_1;
	output out=scorks(keep=_D_ P_KSA RENAME=(_D_=KS P_KSA=P_Value));
run;
/* get c-statistic.    */
ods output Association=Association;
proc logistic data=scored des;
	model y_n=p_1;
run;
ods output close;

/* For Lift chart */
proc gplot data=roc;
	where 0.005 < depth < 0.50;
	plot Lift*depth;
run;
quit;
/*%ks(scored,p_1,y_n,scored1,10)
%PlotKS(scored1)*/



