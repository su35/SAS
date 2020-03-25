/* ==== run macro readdata() to input data ==== */
%ReadData(oriname=accepted_2007_to_2018.csv);
/* ==== Out put the variables infor. and compare with variable dictionary. ==== */
proc sql;
	select name as variable, type, length
	from dictionary.columns
	where memname="ACCEPTED_2007_TO_2018" and libname="ORI"
	order by 1;
quit;
/* check if the value of the char variables which have long length is free text.
*   if it is, then exclude it to reduce the dataset size.*/
proc sql;
	select name
	into :lvarlist 
	from dictionary.columns 
	where libname="ORI" and memname="ACCEPTED_2007_TO_2018"
							and length>=20;
quit;

%let lvarlist=desc emp_title title hardship_type hardship_reason;
/*For large dataset, it will take time to exacute the marcro MissTimeWid*/
%CharValChk(ori.accepted_2007_to_2018, &lvarlist)
proc freq data=ori.accepted_2007_to_2018;
	table hardship_reason/missing nocum;
run;
/*Transform the datetime value to date value*/
proc sql noprint;
	select 	trim(name)||"=datepart("||trim(name)||")", trim(name)
	into :trlist separated by "; ", :folist separated by " "
	from dictionary.columns
	where libname="ORI" and memname="ACCEPTED_2007_TO_2018" and 
		format="DATETIME.";
quit;

/* ==== Copy the dataset to the loan library. ==== */
/*1. The desc, emp_title, and title are free text. then exclude them.
*  2. The hardship_type has only one value except for missing value, so exclude it.
*  3. The member_id has missing value only, so exclude it.
*  4. The zip_code is too detail and keep the same type information as addr_state. exclude it.
*  4. The id has a type as char and the length is 48, this is abnormal. output the obs
*      those the id length large than 10 to tmp_accp*/
data accepted tmp_accp;
	set ori.accepted_2007_to_2018 (drop=member_id desc emp_title title url zip_code);
	&trlist;
	format &folist date9. ;
	if lengthn(id) >12 then output tmp_accp;
	else output accepted;
run;
proc sql noprint;
	select max(length(id)) into :idlen trimmed
	from accepted (keep=id);

	alter table accepted
	modify id char(&idlen) format=$&idlen.. informat=$&idlen..;
quit;
/* ======== Input the data dictionary in project lib. ========== */
%ReadData(oriname=LCDataDictionary.xlsx);
/*	The dictionary includes three sheets, but in each sheet the variables name are different 
**	and  some variable in browsenotes, which include the variables that are available to 
**	the investors, are not included data set.
**	1.	Map the variables among the sheets basing on the variable description.
**	2	Remove the variables those don't include in data set. */
proc sort data=ori.browsenotes(obs=120) out=_browsenotes;
	by description;
run;
proc sort data=ori.loanstats(obs=151) out=_loanstats (rename=(LoanStatNew=variable));
	by description;
run;
data _vardict;
	/*when the data was input into SAS lib, the variable name would be truncated to 32*/
	length variable browsenotesfile $32;
	merge _browsenotes(in=brow) _loanstats(in=loan);
	by description;
	if brow then apply=1;
	if brow and not loan then variable=browsenotesfile;
	drop browsenotesfile; 
run;
proc sort data=_vardict;
	by variable;
run;
proc sql;
	create table _meta as
	select name as variable, type, length
	from dictionary.columns
	where memname="ACCEPTED" and libname="LOAN"
	order by 1;
quit;

data _vardict ;
 	merge _vardict(in=var) _meta(in=t);
	by variable;
	indict=var;
	inset=t;
run;
/*	Output to excel file, make it's easy to modify or correct.
**	1.	Focus on the items that inset do not equal indict, remove the items that inset=0 and 
**	the duplications cased by the variable "description" has the same meaning with 
**	different words.
**	2.	Add variable "class" and assign the value basing on description.
**	3.	Remove indict and inset.
**	4.	 Add id*/
%toexcel(_vardict)
%readexcel(vardict, &pout._vardict.xlsx, nlist=id)
/*check if there is variable that should be included in apply risk model but doesn't include
* in browsenotes*/
proc print data=vardict;
	where apply is missing;
run;

/* ==== Check missing value ==== */
%MissChk(accepted)
proc print data=acceptedmiss;
run;

/* Check if the value is associated with special time point. */
proc sql noprint;
	select variable 
	into :miss separated by " "
	from acceptedmiss;
quit;
/*For large dataset, it will take time to exacute the marcro MissTimeWid*/
%MissTimeWid(accepted, &miss, issue_d)
proc print data=misswid(keep=variable monthinterval where=(monthinterval>0)) ;
run;
/*Update variable dictionary dataset*/
proc sort data=misswid out=_misswid;
	by variable;
	where monthinterval>0;
run;
proc sort data=vardict;
	by variable;
run;

data vardict;
	merge vardict _misswid;
	by variable;
	if variable in ("issue_d" "loan_status") then apply=1;
	drop start;
run;
/* == Check the illegal of char value and map the char value to numeric value == */
proc sql noprint;
	select variable
	into :keeplist separated by  " "
	from vardict
	where type="char" and id is missing;
quit;
/*read the char variable only to reduce the excuting time.*/
ods output OneWayFreqs=_freq;
proc freq data=accepted(keep=&keeplist);
	table _char_ /missing nocum;
run;
ods output close;
/*The hardship_type has 1 value excepted the missing value (99.52%). Exclude it*/
data vardict;
	set vardict;
	if variable="hardship_type" then exclude=1;
run;
proc sort data=_freq;
	by table;
run;

data _null_;
	file "&pout.charmap.csv";
	set _freq end=eof;
	by table;
	retain vid 0;
	if first.table then vid+1;
	variable=substr(table, 7);
	value=compbl(cat(of F_:));
	if variable ^="hardship_type" then put vid " , " variable " , " value;
run;
/*	Define the numeric value.
*	Since a macro variable included, the double quotes is need*/
x "&pout.charmap.csv";
data CharMap;
	infile "&pout.charmap.csv" dsd ;
	length vid value_n 4. variable value $32;
	input vid  variable   value value_n; 
run;

%ReCode(CharMap, outfile=recode)
/*check the code*/
x "&pout.recode.txt";
/*transform the char variable to numeric variable*/
data accepted_n;
	set accepted;
	%include "&pout.recode.txt";
run;

%cleanLib()
