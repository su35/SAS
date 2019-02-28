/****************************************************************************/
%Macro E_Logit(data,target,varlist,bins);
  %let d = 1;
  %do %while(%scan(&varlist,&d, %str( ))^= );
    %let var=%scan(&varlist,&d,%str( ) );

	/*第一步:对变量进行RANK分组*/
	proc rank data=&data groups=&bins out=_out;
	   var &var;
	   ranks bin;
	run;
	/*第二步:对每一组计算该变量的平均值;响应事件数和总事件数**/

	/*数据集BINS 包含:          */
	/* &target = 每个BIN里面响应事件数 */
	/* _FREQ_ =每个BIN里面总事件数 */
	/* &var =每个BIN里面&var平均值 */

	proc means data=_out noprint nway;
	   class bin;
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
		scatter y=elogit x=bin;
		series y=elogit x=bin;
	run;quit;
	title;

	/*第五步:用BIN变量替代原来的变量,并对BIN变量进行代码保存和改造*/

	/*proc means data = out noprint nway;
	   class bin;
	   var  &var;
	   output out=endpts  max(&var)=max;
	run;

	filename rank "d:\rank.sas";

	/*编写BIN代码*/
	/*data _null_;
	   file rank;
	   set endpts end=last;
	   if _n_ = 1 then put "select;";
	   if not last then do;
	     put "  when (&var <= " max ") B_&var =" bin ";";
	     end;
	   else if last then do;
	     put "otherwise B_&var =" bin ";";
	     put "end;";
	   end;
	run;

	/* Use the code. */
	/*data &data;
	   set &data;
	   %include rank /source2;
	run;

	/*proc means data = &data min max;*/
	/*   class B_&var;*/
	/*   var &var;*/
	/*run;*/
	/*proc delete data=out bins endpts;run;*/
	%let d=%eval(&d+1);
	%end;
%Mend E_Logit;

