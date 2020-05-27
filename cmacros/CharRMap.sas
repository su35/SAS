/*	macro CharRMap: remap the numeric value to char value in score card dataset if the 
**	char value has been map to numeric value.
**	carddn: the name of the score card dataset. 
**	chardn: the name of the char map dataset. */

%macro CharRMap(carddn, chardn)/minoperator;
	proc sql noprint;
		select distinct quote(trim(ori_var)), ifc(missing(cluster), "", ori_var)
		into :vlist separated by " ", :cluvlist separated by " "
		from &carddn
		where ori_var not is missing and ori_var in (select distinct variable from &chardn);
	quit;
	%let varnum=&sqlobs;

	proc sort data=&carddn out=work._&carddn;
		by ori_var bin;
		where ori_var in (&vlist);
	run;
	proc sort data=&chardn out=work._&chardn;
		by vid value_n;
	run;
	%strtran(vlist)
	%do i=1 %to &varnum;
		%let var=%scan(&vlist, &i, %str( ));
		proc sql noprint;
			select quote(trim(ifc(missing(value), "missing", value))), quote(trim(left(put(value_n, 8.)))), max(lengthc(value))
			into :mapval separated by " ", :mapval_n separated by  " ", :mlen
			from work._&chardn
			where variable="&var" and value not is missing;
		quit;
		%let valnum=&sqlobs;

		data work._tmp;
			set work._&carddn;
			by  ori_var bin;
			length cvalue $ 32767;
			where ori_var="&var";
			array mapval(&valnum) $ &mlen _temporary_ (&mapval);
			array mapvaln(&valnum) $  _temporary_ (&mapval_n);
			retain low 0;

			if missing(cluster)=0 then do;
				cvalue=compress(cluster, '"');
				do i=&valnum to 1 by -1;
					cvalue=tranwrd(cvalue, trim(mapvaln[i]), trim(mapval[i]));
				end;
				cvalue='"'||tranwrd(trim(cvalue), ' ' ,'" "')||'"';
			end;
			else if missing(border)=0 then do;
				do i=1 to &valnum;
					if mapvaln[i]=border then do;
						if first.ori_var then do;
							do j=1 to i;
								cvalue=catx(' ', cvalue, quote(trim(mapval[j])));
							end;
						end;
						else if last.ori_var then do;
							do j=i+1 to &valnum; 
								cvalue=catx(' ', cvalue, quote(trim(mapval[j])));
							end;
						end;
						else do;
							do j=low to i; 
								cvalue=catx(' ', cvalue, quote(trim(mapval[j])));
							end;
						end;
						low=i+1;
						leave;
					end;
				end;
			end;
			else do;
				do i=1 to &valnum;
					if mapvaln[i]=bin then do;
						cvalue=quote(trim(mapval[i]));
						leave;
					end;
				end;
			end; 
			drop i j low;
		run;

		data work._&carddn;
			merge work._&carddn work._tmp;
			by ori_var bin;
		run;

	%end;

	proc sql;
		select max(lengthn(cvalue))
		into :mlen
		from work._&carddn;

		alter table work._scard
		modify cvalue char(&mlen);
	quit;

	proc sort data=&carddn;
		by ori_var bin;
	run; 

	data &carddn;
		merge &carddn work._&carddn;
		by ori_var bin;
	run;
%mend;
