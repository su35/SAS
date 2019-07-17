/* ******************************************************************************
* 
* ******************************************************************************/
%macro CombFreq(dn, outdn);
	%if %superq(dn)=  or %superq(outdn)=  %then %do;
			%put ERROR: params are input dataset, output dataset;
			%return;
		%end;
	%local i vlen lib point dn_t;
	%let point=%index(&dn, .);
	%if &point %then %do;
		%let lib=%substr(&dn, 1, %eval(&point-1));
		%let dn_t=%substr(&dn, %eval(&point+1) );
	%end;
	%else %do;
		%let lib=work;
		%let dn_t=&dn;
	%end;
	proc sql noprint;
		select max(length) into :vlen
		from dictionary.columns where libname="ORI" and type="char";
	quit;

	data &outdn;
		length variable $32  %if %superq(vlen)^= %then value $&vlen; ;
		set &dn;
		variable=substr(table, 7);
		array chars(*) $ F_:;
		do i=1 to dim(chars);
			if not missing(chars[i]) and  chars[i] ne '.' then missing=0;
		end;
		%if  %superq(vlen)^=  %then value=strip(cats(of F_:))%str(;) ;
		%else value=sum(of F_:)%str(;) ; 
		if missing(missing) then missing=1;
		keep variable missing value frequency percent;
	run;
%mend CombFreq;	
