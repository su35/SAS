/*macro cleanLib: remove the temporary dataets*/
%macro cleanLib(lib);
	proc datasets %if not(%superq(lib)=) %then lib=&lib; 
					noprint;
		delete empty: _: temp_:;
	run;
	quit;
%mend cleanLib;
