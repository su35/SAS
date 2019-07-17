/* *********************************************************************
* colors: color list, SAS accept natural languages, such as red, black, 
* and 16 hexadecimal code (with prefix cx or #)
* **********************************************************************/

%macro SetGcolor(colors,backgroud=cx000);
	%let cnum =0;
	%do %until (&color=);
		%let cnum =%eval(&cnum+1);
		%let color =%scan(&colors, &cnum);
		%let color&cnum = &color;
	%end;
	%let cnum=%eval(&cnum-1);
	%let rep=%eval(%sysfunc(floor(12/&cnum))-1);
	proc template;
		define style style.gchangecolor;
			parent=Styles.Default;
			style graphcolors from graphcolors / 
			%do i=1 %to &cnum;
				"gcdata&i"=&&color&i
				%do j=1 %to &rep;
					"gcdata%eval(&i+&cnum*&j)"= &&color&i
				%end;
			%end;
			;
			class color_list / "bgA" = &backgroud;
		end;
	run;
%mend SetGcolor ;

