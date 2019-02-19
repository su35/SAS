/** *************************************************
* macro libInfor: get the dataset information
* parameters
* lib: specify the library. default is user or work
* dataset: the name of the datasets. default is _all_
* **************************************************/
%macro libInfor(lib=, dataset=);
	%local i;
	%if %superq(dataset)= %then %do;
		proc datasets %if not(%superq(lib)=) %then lib=&lib; 
						;
			contents data=_all_   varnum ;
		run;
		quit;
	%end;
	%else %do;
		%let setnum = 1;
		%do %until (&set =);
			%let set=%scan(&dataset, &setnum);
			%if &set = %then %return;
			proc datasets %if not(%superq(lib)=) %then lib=&lib; 
							;
				contents data=&set   varnum ;
			run;
			quit;
			%let setnum = %eval(&setnum + 1);
		%end;
	%end;
%mend libInfor;
