/* **************************************************
* reporting.sas
* create the summary and graphic reports 
* **************************************************/
options nodate ls=100 nonumber missing="";
goptions device =png;
%SGANNO;
%SGANNO_HELP()
/* ****************************************************
* set path url="", so that the htm files link would be danamic
* include the css and javascript file to control the page display
* *****************************************************/
data _null_;
	if fileexist("&pdir.result") =0 then NewDir=dcreate("result","&pdir");
run; 
X "copy &proot.pub\customstyle.css &pdir.result\customstyle.css";
X "copy &proot.pub\display.js &pdir.result\display.js";

ods html5 path="&pdir.result" (url="")
headtext="<script src='https://ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js'></script>
<script type='text/javascript' src='display.js'></script>
<link href='customstyle.css' rel='stylesheet'/>"
stylesheet="style.css"
body="report.htm"
contents="contents.htm"
/*page="page.htm"*/
frame= "index.htm";

/* *****************************
* dm and ae report
* *****************************/
 /* put the number of subjects in each trt group into the global macro and remove blank */
proc sql noprint; 
		select strip(put(count(usubjid),4.)), strip(put(sum (case when trtpn=0 then 1 else 0 end),4.)), 
			strip(put(sum (case when trtpn=1 then 1 else 0 end),4.)) into : tatolsub, : plasub, : trtsub
			from addm;
quit;
ods proclabel "Demographics Report";
proc report data=dmreport headline headskip spacing=2 split="|";
	title1 "Protocal:  &pname";
	title2 "Demographics Table";
	footnote1 "Reported by Jun Fang on &sysdate9..";  

	columns group term trtpn0 trtpn1 trtpn2 pvalue;
	define group /order order=internal noprint;
	define term /display width=23 "";
	define trtpn0 /display width=15 "Placebo|No=&plasub";
	define trtpn1 /display width=15 "Topiramate|No=&trtsub";
	define trtpn2 /display width=15 "Tatal|No=&tatolsub";
	define pvalue /display width=15 "|Pvalue";
run;
ods proclabel "Adverse Event Report";
proc report data=aereport headline headskip spacing=5 split="|";
	title1 "Protocal:  &pname";
	title2 "Adverse Event Table";
	footnote1 "Reported by Jun Fang on &sysdate9..";  

	columns ( group term trtan0 trtan1 trtan2 );
	define group /order order=internal noprint;
	define term /display width=23 "";
	define trtan0 /display width=15 "Placebo|No=&plasub";
	define trtan1 /display width=15 "Topiramate|No=&trtsub";
	define trtan2 /display width=15 "Tatal|No=&tatolsub";
run;
/* **********************************************************************
* Image for Study retention for the topiramate and placebo groups
* ***********************************************************************/
data survivalist;
	set survivalist;
*	survival=survival*100;
	if upcase(trtp)="PLACEBO" then linecolor="red";
	else linecolor="#000";
run;
data _null_; /*get pvalue for image*/
	set _survpval;
	pvalue=put(probchisq, 4.2);
	if test="Log-Rank" then call symputx('survplr', pvalue );
	else if test="Wilcoxon" then call symputx('survpwc', pvalue);
run;

/*use annotation, the %SGANNO had been declared on top*/
data insertlab;
	%sgtext(label="p = &survplr",	textcolor= "red",	textstyle="italic", 	textweight="bold",
		x1=60,		y1=70);
run;
%SetGcolor(black red); 
ods html5 style=style.gchangecolor;

ods proclabel"Study retention for the topiramate and placebo groups";
proc sgplot data=survivalist noautolegend sganno=insertlab;
	title "Study retention for the topiramate and placebo groups";
	step y=survival x=lastday / group=trtp lineattrs=(pattern=4 thickness=2 ) name="R";
	xaxis label="Study Week" values=(1 to 84 by 7) 
		valuesdisplay=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12") offsetmin=0.05 offsetmax=0.05;
	yaxis label="Retention Rate" values=(0.5 to 1 by 0.1)
		valuesdisplay=("50" "60" "70" "80" "90" "100") offsetmin=0.05 offsetmax=0.05;
	keylegend  'R' / title='Treatment Group' location=inside position=topright;
*	inset ("p ="="&survplr") / noborder position=bottom textattrs=(color=red weight=bold);
run;
/* ***********************************************************************
* Generalized estimating equations (GEE) result
* ************************************************************************/
data _null_; /*get pvalue for image*/
	set _gee_pvalue;
	where parm="AVISITN*TRTP" and ProbZ ne .;
	 call symputx('geepval', put(probz, 4.2) );
run;
data insertlab;
	%sgtext(label="p = &geepval", textcolor= "black",	textstyle="italic",	textweight="bold",
		x1=50, 	y1=60	);
run;

ods proclabel "Precentage of Subjects with Negative Methamphetamine Use Week";
proc sgplot data=gee_means noborder sganno=insertlab;
	scatter y=week_mean x=week/ group=trtp;
	reg y=means x=weeks/ group=trtp  nomarkers;
	xaxis label="Study Week" values=(6 to 12 by 1) offsetmin=0.05 offsetmax=0.05;
	yaxis label="Precentage of Subjects with Negative Methamphetamine Use Week" 
			values=(0 to 100 by 10) offsetmin=0.05 offsetmax=0.05;
run;
/* *********************************************************************************************
* The percentage of subjects with a negative methamphetamine use week in study weeks
* **********************************************************************************************/
data insertlab;
	%sgtext(label="Negative",	textstyle="italic",	textweight="bold",	x1=20,	y1=75)
	%sgtext(label="Positive",textstyle="italic",textweight="bold",x1=20, y1=45)
run;

ods proclabel "Treatment group and last urine result prior to randomization 
for the percentage of subjects with a negative methamphetamine";
/*==sg version==*/
*ods graphics on /height=8in width =8in;
proc sgplot data=base_weekval  noborder sganno=insertlab;
	scatter y=ppcent x=avisitn /group=trtp markerattrs=(symbol=circlefilled size=10px) ;
	series y=ppcent x=avisitn /group=trtp  lineattrs=(pattern =4 thickness=2) name="BP";
	scatter y=tpcent x=avisitn /group=trtp markerattrs=(symbol=circlefilled size=10px) ;
	series y=tpcent x=avisitn/group=trtp lineattrs=(pattern =1 thickness=2)  name="BT";
	xaxis label="Study Week" values=(6 to 12 by 1) offsetmin=0.05 offsetmax=0.05;
	yaxis label="Precentage of Subjects with Negative Methamphetamine Use Week" 
			values=(0 to 100 by 10) offsetmin=0.05 offsetmax=0.05;
run;

/*==g version==
goptions reset=all device=png gsfmode=append;
axis1 label=(j=c "Study Week")
		order=(6 to 12 by 1)
		offset=(3,3)
		minor=none;
axis2 label=( j=c a=90 "Precentage of Subjects with Negative Methamphetamine Use Week" )
		order=(0 to 100 by 10)
		offset=(1,10)
		minor=none;
symbol1 c="blackf" v=dot line=4 i=j width=2;
symbol2 c="red" v=dot line=4 i=j width=2;
symbol3 c="black" v=dot line=1 i=j width=2;
symbol4 c="red" v=dot line=1 i=j width=2;

%annomac;
data annolen;
	%dclanno;
	xsys="2"; ysys="3"; hsys="3";
	%label(6, 95, "Treatment, last urine:", black, 0, 0, 2.5, , 6);
	%move(7.5, 94.5);
	%draw(8, 94.5, black, 4, 0.5);
	%slice(7.6, 94.5, ., 360, 0.5, black, PS);
	%slice(7.85 ,94.5, ., 360, 0.5, black, PS);
	%label(8.1, 95, "Placebo, negative", black, 0, 0, 2.5, , 6);
	%line(9.5, 94.5, 10, 94.5, black, 1, 0.5);
	%slice(9.65 ,94.5, ., 360, 0.5, black, PS);
	%slice(9.85, 94.5, ., 360, 0.5, black, PS);
	%label(10.15, 95, "Placebo, positive", black, 0, 0, 2.5, , 6);
	%line(7.5, 90.2 , 8, 90.2, red, 4, 0.5);
	%slice(7.6, 90.2, ., 360, 0.5, red, PS);
	%slice(7.85 ,90.2, ., 360, 0.5, red, PS);
	%label(8.1, 91, "Topiramate, negative", red, 0, 0, 2.5, , 6);
	%line(9.5, 90.2, 10, 90.2, red, 1, 0.5);
	%slice(9.65 ,90.2, ., 360, 0.5, red, PS);
	%slice(9.85, 90.2, ., 360, 0.5, red, PS);
	%label(10.15, 91, "Topiramate, positive", red, 0, 0, 2.5, , 6);
run;
proc gplot data=base_weekval ;
	plot ppcent*avisitn = trtp /haxis=axis1 vaxis=axis2 anno=annolen nolegend ;
	plot2	tpcent*avisitn = trtp / vaxis=axis2 noaxis nolegend;
run;quit;*/



ods html5 close;
ods html;
*ods preferences;
/* *************************************************************************************************
* If there is not a main program, run following macros 
* export .xpt files,  create define.xml file, and call pinnacle21 validator to validate the .xpt files

%cdsic(SDTM)
%cdsic(ADaM)
* *************************************************************************************************/

%cleanLib(work)
%cleanLib(&pname)
