%macro del_mvars() /minoperator;
	proc sql;
		title 'Deleted Macro Variables';
		select distinct name
			into :cleanlist separated by ' '
			from sashelp.vmacro
			where scope = 'GLOBAL' and substr(name,1,3) ne 'SYS'  and substr(name,1,3) ne 'SQL'  
					and name not in("MVARCLEAN","PDIR","PNAME","PROOT");
	quit;
	%str(%symdel &cleanlist);
	title 'The SAS System';
%mend;

