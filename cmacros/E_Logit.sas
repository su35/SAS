/**********************************************************************************************
* Macro E_Logit: showing the relationship between the continuous variable x and logit(y)
* 	params:
* 		dn: the name of dataset
* 		target: the name of target variable
* 		varlist: the list of continuous variables
* 		bins: number of bins or the prefix of the bin variables
* *********************************************************************************************/
%Macro E_Logit(dn,target,varlist,bins);
	%let vnum= %VarsCount(&varlist); 
	%do i=1 %to &vnum;
		%let var=%scan(&varlist,&i,%str( ) );

		/*if bins is a numerical variable, then it is the number of bins*/
		%if %datatyp(&bin)==NUMERIC %then %do;
			proc rank data=&dn groups=&bins out=work._out;
				var &var;
				ranks bin;
			run;
		%end;
		
		/*dataset work._bins include:   &target = number of events
		*  									_FREQ_ = total obs
		*									&var = mean of &var */
		proc means data= %if %sysfunc(notdigit(&bin))=0 %then work._out; %else &dn;
			noprint nway;
			class %if %sysfunc(notdigit(&bin))=0 %then bin; %else &bins&var;
				;
			var &target &var;
			output out=_bins sum(&target)=&target mean(&var)=&var;
		run;
		/*calculate empirical logit */ 
		data work._bins;
		   set work._bins;
		   elogit=log((&target+(sqrt(_FREQ_ )/2))/( _FREQ_ -&target+(sqrt(_FREQ_ )/2)));
		run;
		
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
	%end;
%Mend E_Logit;
