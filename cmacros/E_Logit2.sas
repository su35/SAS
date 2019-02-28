/****************************************************************************/
%Macro E_Logit2(data,target,varlist, prebin);
  %let d = 1;
  %do %while(%scan(&varlist,&d, %str( ))^= );
		%let var=%scan(&varlist,&d,%str( ) );

		/*第二步:对每一组计算该变量的平均值;响应事件数和总事件数**/

		/*数据集BINS 包含:          */
		/* &target = 每个BIN里面响应事件数 */
		/* _FREQ_ =每个BIN里面总事件数 */
		/* &var =每个BIN里面&var平均值 */

		proc means data=&data noprint nway;
			class &prebin&var;
			var &target &var;
			output out=_bins sum(&target)=&target mean(&var)=&var;
		run;
		/*第三步:根据公式计算 empirical logit */ 
		data _bins;
			set _bins;
			elogit=log((&target+(sqrt(_FREQ_ )/2))/
			    ( _FREQ_ -&target+(sqrt(_FREQ_ )/2)));
		run;
		/*第四步:画LOGIT与原变量平均值;LOGIT与BIN变量的线图*/
		/*proc sgplot data = bins;*/
		/*title "Empirical Logit against &var";*/
		/*series y=elogit x=&var;*/
		/*scatter y=elogit x=&var;*/
		/*run;*/
		proc sgplot data = _bins;
		title "Empirical Logit against &var"; 
		scatter y=elogit x=&var;
		series y=elogit x=&var;
		run;quit;

		proc sgplot data = _bins;
		title "Empirical Logit against Binned &var";
		scatter y=elogit x=&prebin&var;
		series y=elogit x=&prebin&var;
		run;quit;
		title;

		%let d=%eval(&d+1);
	%end;
%Mend E_Logit2;

