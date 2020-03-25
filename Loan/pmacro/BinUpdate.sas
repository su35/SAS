/* *****************************************************************************************
* macro BinUpdate: read the excel file which has manually bin combination info.  if type=num then
* 	update the border of interval variable, otherwise update the pdn and output 
* 	the code for re-bin .
* dn: dataset name of which include the bin update information.
* pdn: dataset name of which store the variables description info.
* type: define the update type
* path: code output path. The default is outfiles folder under the project folder;
* update: if update the pdn dataset. (Insert the bin variabels and set the exclude of the 
			original varialbes to 1).
* ***********************************************************************************************/
%macro BinUpdate(dn, pdn=vars, path=, type=, update=0, varlist=, file=xlsx, bdn=bin, bcode=bin_code);
	%if %superq(dn)= %then %do;
		%put ERROR: ===== The dataset name is missing. ======;
		%return;
	%end;
	%if %superq(path)= %then %let path=&pout;
	%if %sysfunc(fileexist(&path.&dn..&file))=0 %then %do;
		%put ERROR: ======= The CSV file does not exist ===========;
		%return;
	%end;

	options nonotes;
	%if &type=border %then %BinUpdate_border(&dn, &path.&dn..&file);
	%else  %BinUpdate_woe(&path.&dn..&file, &pdn);
	options nonotes;

	proc datasets lib=work noprint;
	   delete bu_: ;
	run;
	quit;

	options notes;
	%if &type=border %then %put NOTE: == Update the border in &dn from &path.&dn..csv ==;
	%else 	%do;
		%put NOTE: == Dataset &bdn and &bcode hasve been update ==;
	%end;
	%put NOTE: == Macro BinUpdate running completed ==;
%mend BinUpdate;
%macro BinUpdate_border(dn, data);
	data work.bu_bin;
		length variable $32 border 8;
		infile "&data" dsd firstobs=2;
		input variable border;
	run;

	proc sort data=&dn;
		by variable border;
	run;
	proc sort data=work.bu_bin;
		by  variable border;
	run;

	options varlenchk=nowarn;
	data &dn;
		merge &dn work.bu_bin;
		by variable;
	run;
	options varlenchk=warn;
%mend BinUpdate_border;

%macro BinUpdate_woe(data, pdn);
	%local vlist var bList branch obsnum i;
	options  varlenchk=nowarn;
	/*== Import the update information ==*/
	proc import datafile= "&data"  out=work.bu_woe( 
		%if %superq(varlist)^= %then %do;
			%StrTran(varlist)
			where=(variable in (&varlist))%str( )
		%end;
			keep=variable ori_var bin newbin exclu class branch) dbms=excel replace;
		getnames=yes;
	run;

	data work.bu_woe(rename=(_newbin=newbin _exclu=exclu));
		length variable ori_var $32 class branch $8 _newbin _exclu bin 8;
		set work.bu_woe;
		if vtype(newbin)="C" then _newbin=input(newbin, 8.);
		else _newbin=newbin;
		if vtype(exclu)="C" then _exclu=input(exclu, 8.);
		else _exclu=exclu;
		drop newbin exclu;
	run;

	proc sql;
		create table work.bu_update as
		select a.*, b.border, b.cluster, c.ori_nlevels, c.description
		from (select ori_var as variable, variable as d_var, class, newbin, bin, branch, 
			max(newbin) as nlevels from work.bu_woe where newbin not is missing 
			group by 1, branch) as a left join
		(select variable, border, cluster, branch, bin from &bcode) as b 
			on a.variable=b.variable and a.branch=b.branch and a.bin=b.bin left join
		(select variable, nlevels as ori_nlevels, description from &pdn) as c on a.variable=c.variable
		order by 1, branch,  newbin desc, bin desc;
	quit;

	data work.bu_update;
		length cluster2 $1000;
		set work.bu_update;
		by variable branch  descending newbin descending  bin;
		retain cluster2;
		if class="nominal" then do;
			if first.newbin then cluster2=cluster;
			else cluster2=catx(" ", cluster2, cluster);
			bin=newbin;
			if last.newbin then do;
				cluster=cluster2;
				output;
			end;
		end;
		else if newbin^=nlevels and  first.newbin then do;
			bin=.;
			output;
		end;
		drop cluster2 newbin;
	run;

	proc sort data=work.bu_update;
		by variable branch border bin;
	run;

	data work.bu_update;
		set work.bu_update;
		by variable branch border bin;
		if last.branch=0  then do;
			nlevels=.;
			ori_nlevels=.;
			description=" ";
		end;
	run;

	proc sql noprint;
		create table work.bu_del as
		select distinct variable, branch from work.bu_update union
		select distinct ori_var, branch from work.bu_woe where exclu not is missing ;

		select distinct variable, branch
		into :vlist separated by " ", :blist separated by " "
		from work.bu_del;

		%let obsnum=&sqlobs;

		%do i=1 %to &obsnum;
			%let var=%scan(&vlist, &i, %str( ));
			%let branch=%scan(&blist, &i, %str( ));
			delete from &bdn
			where	variable="&var" and branch="&branch";
		%end;
	quit;

 	proc append base=&bdn data=work.bu_update force;
	run;

	proc sort data=&bdn;
		by variable branch border bin;
	run;

	%BinMap(bin)

	%if &update=1 %then %do;
		proc sql noprint;
			%if %existsVar(dn=&pdn, var=ori_bin)=0 %then
			alter table &pdn add ori_bin char(32)%str(;);

			create table work.bu_vars as
			select distinct d_var as variable,  "num" as type length=4, 
				ifc(class="nominal", "nominal", "ordinal") as class length=8, 
					max(bin) as nlevels, 1 as derive_var, 1 as bin_var,  variable as ori_bin
			from &bcode
			group by 1;

/*			update &pdn set exclude=1 
			where variable in (select distinct variable from &bcode);*/
		quit;

		proc sort data=work.bu_vars  nodupkey dupout=work.bu_dup;
			by variable;
		run;
		proc sort data=&pdn;
			by variable;
		run;

		data &pdn;
			update &pdn work.bu_vars;
			by variable;
		run;

		options notes;
		%if %sysfunc(nobs("work", "bu_dup")) %then %do;
			%put ERROR: There are duplicated variable name;
			proc datasets  lib=work noprint;
				change bu_dup=_dup;
			run;
			quit;
		%end;
		%put NOTE: == The update=1, the dataset vars has been updated ==;
	%end;
	options notes varlenchk=warn;
%mend BinUpdate_woe;
