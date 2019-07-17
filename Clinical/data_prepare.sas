/* ********* ********************* ****************************************
* data_prepare.sas
* 	read data from raw file, clean the data, create SDTM datasets,
* 	create ADaM datasets, and create analysis dataset
* ***********************************************************************/
/* *************************************************************************************
* Read data from local raw files in ori, and remove the format, informat, and label
* *************************************************************************************/
%ReadData();
%RemoveAttrib(lib=ori);

/*get the length of the character varibles in original dataset, and stored
in ori_matelen.xml. This data would be helpful when defining the variable 
length in sdtm_metadata.xlsx*/
%GetMatelen(lib=ori);

/*There is no usubjid in overall original dataset, , create the usubjid for each dataset*/
%SetUsubjid(length=25);

/*since the data de-identification,  the date of randomization = day 0. 
for practice reason, create a random date as a subject's ramdomizqtion date*/
data random;
	set ori.random;
	length rand_date 8;
	rand_date=createdate('01JUl2016'd);
	keep studyid usubjid treat rand_date;
run;

proc sort data=random;
	by usubjid;
run;
/* ****************************************
* Prepare ADTM dataset
* ****************************************/
libname sdtmfile  "&pdir.sdtm_metadata.xlsx";
/*creates a permanent SAS format library from the codelist metadata spreadsheet*/
%MakeFormats(SDTM)
/*creates a zero record dataset and a global macro variable called **keeplist that holds 
* the dataset variables desired and listed in the order they should appear based on 
* the dataset metadata spreadsheet. 
* so that no matter how the data was prepared, variables keep in fixed order and attribute.*/
%MakeEmptyDataset(SDTM)
/*create length define macro variable for the sdtm dataset*/
proc sql;
	create table _len as
	select substr(memname, 7) as dset, name, type, length
	from dictionary.columns
	where libname=upcase("&pname") and memname like "EMPTY_%";
quit;
proc sort data=_len;
	by 	dset type length;
run;
data _null_;
	set _len;
	by 	dset type length;
	length len $2000;
	retain len;
      id=ifc(type="char", "$", " ");
	len=catx(" ", len, name);
	if last.length then len=catx(" ", len, id, left(length));
	if last.dset then do;
		call symputx(trim(dset)||"len", len);
		len="";
	end;
run;

proc sql;
	create table _dm as
	select e.studyid as studyid, e.usubjid as usubjid, put(e.subjid,8.-L) as subjid,
			r.rand_date as first_t_day, r.rand_date + t.visdate as last_t_day, 
			r.rand_date + tl.visdate as infoday, 
			r.rand_date + max(f.visdate,  f.contdate, t.visdate, e.visdate) as endday, 
			.  as dthday, 
			case when f.died = "1" or t.deathda ne '' then 'Y' else "" end as Dthfl,
			put(e.siteid,8.-L) as siteid, birthday as age, gender as sex, 
			case when white ="1" then "1"  	when  black eq "1" then "2"  when asian ="1" then "3"
					when hawaiian = "1" then "4" when  indian= "1" then "5" else "" end as race, 
			case upcase(r.treat) when "TOPIRAMATE" then "T" when "PLACEBO" then "P" else "" end as armcd, 
			r.treat as arm,   
			case e.reasinel when "" then "" else "1" end as illegal,
			case e.reasdecl when "" then "" else "1" end as decline,
			case when e.visdate < 0 then e.visdate else e.visdate +1 end  as dmdy
		from (ori.enrl as e left join ori.tlfb as tl on e.usubjid=tl.usubjid) left join 
				((random as r inner join ori.term as t on r.usubjid=t.usubjid) left join ori.fup as f on r.usubjid=f.usubjid)
				on e.usubjid=r.usubjid 
		order by usubjid;
quit;
/* *****************************************************************************************
* When input the original data, there is no data for death and all valus in relatived 
* columns are null. The proc import evluated them as char and couldn't be used here 
* and hardcode the dthdtc  as unll.
* *****************************************************************************************/
data dm;
	set empty_dm 	_dm;
	domain = "DM";
	if first_t_day =. then do;
		rfstdtc = "";  rfendtc = "";  rfxstdtc = ""; 
		rfxendtc ="";  rficdtc = "";  rfpendtc = ""; 
	end;
	else do;
		rfstdtc = put(first_t_day, E8601DA10.-L); 
		rfendtc = put(last_t_day, E8601DA10.-L); 
		rfxstdtc = put(first_t_day, E8601DA10.-L); 
		rfxendtc = put(last_t_day, E8601DA10.-L); 
		rficdtc = put(infoday, E8601DA10.-L); 
		rfpendtc = put(endday, E8601DA10.-L); 
	end;
	dthdtc = ""; 
	sex = put(sex,sex.);
	race = put(race, race.);
	if illegal="1" then do;
		armcd="SCRNFAIL";
		actarmcd="SCRNFAIL";
		arm="Screen Failure";
		actarm="Screen Failure";
	end;
	else if decline ="1" then do
		armcd = "NOTASSGN";
		actarmcd = "NOTASSGN";
		arm = "Not Assigned";
		actarm = "Not Assigned";
	end;
	else do;
		actarm = arm;
		actarmcd = armcd;
	end;
	
	ageu = "YEARS";
	country = "USA";
	keep &dmkeeplist;
run;

/*finding the illegal values of the variables that would be included in suppdm*/
%LegVal(ori.enrl, educatyr employ30 maritals);
proc sort data=ori.enrl;
	by usubjid;
run;
data _suppdm;
	merge ori.enrl(keep=studyid usubjid educatyr maritals employ30  eligible)  
			random(keep= usubjid  rand_date);
	by usubjid;
	length  qorig  $ 8 qnam  $ 10 qval $ 30 qlabel $ 27;
	qnam = "EDUCATYR"; qlabel = "Years of Formal Education"; 
	if upcase(educatyr) in ("U","A","T") then educatyr = "";
	if educatyr ne "" then qval=educatyr; 
	else qval="";
	qorig ="CRF 01";
	output;
	qnam = "EMPLOY"; qlabel = "Usual Employment Pattern"; qorig ="CRF 01";
	if employ30 not in ("1","2","3","4","5","6","7","8","9","10") then employ30="10";
	qval=put(employ30, employ.);
	output;
	qnam = "MARITALS"; qlabel = "Marital Status";  qorig ="CRF 01";
	if maritals not in ('1','2','3','4','5','6','7') then maritals='7';  
	qval=put(maritals,maritals.);
	output;
	qnam = "RANDDT"; qlabel = "Date of Randomization"; qval=put(rand_date,E8601DA10.-L); 
	if qval="." then qval="";
	qorig ="CRF 01";
	output;
	qnam = "ELIGIBLE"; qlabel = "Subject Eligible"; qorig ="Derived";
	if eligible = 0 then qval="N"; 
	else if eligible in (1,2) then qval="Y";
	else qval="";
	output;
run;

data suppdm;
	set empty_suppdm
		_suppdm;
	rdomain = "DM";
	keep &suppdmkeeplist;
run;

/*for easy handling, change the names such as ae1sev, ae2sev to aesev1, aesev2*/
proc sql noprint;
	select strip(name)||"="||prxchange("s/(ae)(\d+)(type|sev|sae|rel|act|out)/$1$3$2/i", 1, name), count(name)
	into : rename separated by " ", :memb
	from dictionary.columns
	where libname="ORI" and memname="AELOG" and prxmatch('/(ae)(\d)+(type|sev|sae|rel|act|out)/i', name);
quit;

proc sort data= ori.aelog;
	by usubjid ;
run;

data _ae;
	length aeacn aerel aeout aesev aeser epoch aepresp $ 3 aestdy  aeendy 8;
	merge ori.aelog (where=(aenum ne 99) rename=(&rename)  in=inae) random(keep= usubjid  rand_date); 
	by usubjid;
	 /*in aelog, there are some almost empty record except hasing a aenum = 99.*/
	array act (48) $ aeact1-aeact48; 
	array rel (48) $ aerel1-aerel48;
	array out (48) $ aeout1-aeout48;
	array type (48) $ aetype1-aetype48 ;
	array sev (48) $ aesev1-aesev48 ;
	array ser (48) $ aesae1- aesae48 ;
	array rdte (3) aerdte1-aerdte3;

	/*normalize the value*/
	do i= 1 to 48;
		if not(sev(i) in('1','2','3')) then sev(i)='';
		if not(ser(i) in('0','1')) then ser(i)='';
		if not(act(i) in('1','2','3','4','5','6','')) then act(i)='5'; 
		if not(rel(i) in('1','2','3','4','5','6','')) then rel(i)='1';
		if not(out(i) in('1','2','3','4','5','6','7','')) then out(i)='7';
		else if out(i)='4' then out(i)='3';
		if not(type(i) in('1','2','3','4')) then type(i)='';
		else if type(i)='4' then type(i)='3';
	end;

	aesev =left(max(of aesev1-aesev48));
	aeser =left(max(of aesae1- aesae48));

	do i=48 to 1 by -1; 
		if act(i) ne '' and  (aeacn eq '' or aeacn eq '5' or aeacn eq '6' ) then aeacn=act(i);
		if rel(i) ne ''  and  aerel eq '' then aerel=rel(i);
		if out(i) ne ''  and  aeout eq '' then aeout=out(i);
		if type(i) ne ''  then do;
			if type(i) eq '1' then epoch ='S';
			else if type(i) eq '2' then aepresp = '1';
			else do;
				epoch ='T';
				aepresp = '';
			end;
		end;
	end;

	if aeodte < 0 then aestdy = aeodte;
	else aestdy = aeodte + 1;
		do i=3 to 1 by-1; 
		if rdte(i) ne .  then do;
			if rdte(i) < 0 then  aeendy =rdte(i); 
			else do;
				aeendy =rdte(i) + 1; 
				aerdte=rdte(i);
			end;
			continue;
		end;
	end;

	if inae;
run;

data ae;
	set empty_ae _ae;
	keep &aekeeplist;
	domain = "AE";
	aestdtc = put (rand_date + aeodte, E8601DA10.-L);
	if aestdtc="." then aestdtc="";
	aeendtc = put (rand_date + aerdte, E8601DA10.-L);
	if aeendtc="." then aeendtc="";
	aeterm = ptname;
	aedecod = aeevnt;
	aeptcd = ptcode;
	aesoc = socname;
	aesoccd = socode;
	aellt = lltname;
	aelltcd = lltode;
	aepresp = put(aepresp, ny.);
	aesev = put(aesev, aesev.);
	aeser = put(aeser, ny.);
	aeacn = put(aeacn, acn.);
	aerel = put(aerel, aerel.);
	aeout = put(aeout, aeout.);
	epoch = put(epoch, epoch.);
run;

proc sort data= ori.dose;
	by usubjid visid;
run;

%LegVal(ori.dose, t25_1 t25_2 t100_3 t100_4);
data _ex ; 
	length startdate enddate 8;
	merge ori.dose   random (keep=treat usubjid rand_date) end=eof;
	by usubjid;

	retain exdose exstdy _dose _date startdate;
	array dos (2,7) t25_1 - t25_7 t100_1-t100_7;
	array datearr(7) date1-date7;
	keep studyid  usubjid exstdy exendy exdose  startdate enddate treat;

	if first.usubjid then do;
		exdose =. ;  exstdy=.;  _date=.;
	end;

	do i=1 to 7;
		if dos(1,i) in ("U","A","T") then dos(1,i) ="0" ;
		if dos(2,i) in ("U","A","T")  then dos(2,i) ="0" ;
		_dose= sum(25*dos(1,i), 100*dos(2,i));
		if _dose >0 then do;
			if exstdy =.  then do;
				exstdy = datearr(i) +1;
				startdate =  datearr(i) + rand_date;
				exdose = _dose; 
			end;
			else if exdose ne _dose then do;
				exendy =  _date +1 ;
				enddate = _date + rand_date;
				output; 
				exstdy = datearr(i) +1 ;
				startdate =  datearr(i) + rand_date;
				exdose = _dose;
				exendy =  .;
				enddate = .;
			end;
			else if (last.usubjid or eof) and i=7 then do;
				exendy =  datearr(i) +1;
				enddate = datearr(i) + rand_date;
				output;
			end;		
			_date= datearr(i);
		end;
	end;
	if 0;
run;

data ex;
	set empty_ex  _ex;
	domain="EX";
      exdosu = "mg";
	exdosfrm= "TABLET";
	exstdtc = put(startdate, E8601DA10.-L);
	exendtc = put(enddate, E8601DA10.-L);
	extrt = treat;
	keep &exkeeplist;
run; 

proc sql noprint;
	select quote(trim(name)), 
		sum(case when prxmatch('/([a-z]*)(ev|eva|eval)/i', name) then 1 else 0 end), 
		case when prxmatch('/([a-z]*)(ev|eva|eval)/i', name) then 
			prxchange("s/([a-z]*)(ev[a]?[l]?)/$1$2/i", 1, name) else '' end
		into :labname separated by ",", : memb, : evalname separated by " "
		from dictionary.columns
		where libname="ORI" and memname="LABS";
quit;
%let he_chstart = %index(%bquote(&labname),"WBC");
%let he_chlen = %eval (%index(%bquote(&labname),"URCOLOR") - &he_chstart - 1);
%let urinstart = %index(%bquote(&labname),"SPECGRAV");
%let urinslen = %eval (%index(%bquote(&labname),"SIGNATUR") - &urinstart-1);
%let he_chvar = %substr(%bquote(&labname), &he_chstart, &he_chlen);
%let urinvar = %substr (%bquote(&labname), &urinstart, &urinslen);

proc sort data=ori.labs;
	by usubjid visdate;
run;

data _lb;
	length &lblen;
	merge ori.labs  random(keep=usubjid rand_date);
	by usubjid;
	if visid = 0 then lbblfL="Y"; 
	visitnum=visid;
	if visdate < 0 then lbdy = visdate;
	else lbdy = visdate + 1;
	col_date = rand_date + lbdy;
/*According to the notes of lbnrind in SDTMIG v3.2: "Should not be used to indicate clinical significance".
	The original value "3" of the lbnrind was classed to "2"*/
	array eval (&memb) $ &evalname;
	do i=1 to &memb;
		if eval(i) in ('1','2','3') then do;
			if eval(i) ="3" then eval(i)="2";
		end;
		else eval(i) = '';
	end;
	array  he_ch(25,3) $ wbc--hemglbx;
	array  he_chvar(25,3) $ _temporary_  (&he_chvar);
	array urin(9,3) $ specgrav -- leukox;
	array urinvar(9,3) $ _temporary_ (&urinvar);
	retain he_chvar urinvar;
	do i=1 to 25;
		lbcat =ifc(i<11, "HEMATOLOGY",  "CHEMISTRY");
		if he_ch(i,1) ne "" then do;
			lbtestcd = he_chvar(i,1);
			lbtest = he_chvar(i,1);
			lborres = he_ch(i,1);
			lbstresc = he_ch(i,1); 
			if not (prxmatch('/[a-z]/i', he_ch(i,1))) then lbstresn = he_ch(i,1);
			lbnrind = he_ch(i,2); 
			select (lbtestcd);
				when("HEMATOCR","NEUTROPH","LYMPHOCY","MONOCYTE","EOSINOPH","BASOPHIL","HEMGLBA1") lborresu= "%";
				when("SODIUM","POTASSIU","CHLORIDE","BICARB") lborresu= "mEq/L";
				when("HEMOGLOB","ALBUMIN") lborresu= "g/dL";
				when("BUN","CREATINI","GLUCOSE","TOTBILI","DIRBILI") lborresu= "mg/dL";
				when("WBC", "PLATELET") lborresu= "K/mm3";
				when("RBC") lborresu= "M/mm3";
				when("ALKPHOS") lborresu= "ALP";
				when("GGT","SGPTALT","SGOTAST") lborresu= "U/L";
				otherwise lborresu= "";
			end;
			output;
		end;
	end;

	do i=1 to 9;
		lbcat = "URINALYSIS"; lborresu= "";
		if urin(i,1) ne "" then do;
			lbtestcd = urinvar(i,1);
			lbtest = urinvar(i,1);
			lborres = urin(i,1);
			lbstresc = urin(i,1);
			lbnrind = urin(i,2);
			if lbtestcd in ("PH", "SPECGRAV") and not (prxmatch('/[a-z]/i', urin(i,1)))
				then lbstresn = urin(i,1);
			else lbstresn = "";
			output;
		end;
	end;
	lbstresn = ""; lbnrind = "";
	if urcolor ne '' then do;
		lbtestcd = "COLOR"; lbtest = "Color"; 
		lborres = urcolor; 
		lbstresc = urcolor; 
		output;
	end;
	if urapp ne '' then do;
		lbtestcd = "APPEAR"; lbtest = "Specimen Appearance"; 
		lborres = urapp; 	
		lbstresc = urapp; 
		output;
	end;
run;

data lb;
 	set empty_lb _lb;
	domain = "LB";
	lbtestcd = put(lbtestcd, lbtestcd.);
	lbtest = put(lbtest, lbtest.);
	lbstresu = put(lborresu, unit.);
	lbdtc = put(col_date, E8601DA10.-L);
	visit = put(visitnum,visit.);
	lbnrind = put(lbnrind, lbnrind.); 
	if upcase(lbtestcd) = "COLOR" 	then lbstresc = put(lbstresc,  urcolor.);
	else if upcase(lbtestcd) = "APPEAR"  then lbstresc = put(lbstresc,  urapp.);
	else if upcase(lbcat) = "URINALYSIS" and  upcase(lbtestcd) not in ("PH", "SPGRAV")
	then lbstresc = put(lbstresc,  lbstresc.);
	keep &lbkeeplist;
run;

/*The urine test is the "endpoint" of this study. According SDTMGI, 
* should including these data in LB doamin, rather than create custom domain. 
* However, on the urine drug screen form CRF 09, the result in neg/pos only and 
* there is not Creatinine. Even in the same date, the value of creatinine in labs dataset 
* is not match the value in urine dataset. It looks like some information was missed.
* To keep the result match the original, recording urine drug data in a custom domain*/
proc sort data=ori.urine;
	by usubjid coll_dat;
run;

data _ur;
	merge ori.urine random(keep=usubjid rand_date);
	by usubjid;
	length  urtestcd urstresc $ 8  urorres urorresu $ 7 urstresn urdy 8;
	if coll_dat < 0 and coll_dat >= -14 then urblfl="Y";
	else urblfl="";
	urdy = coll_dat;
	if coll_dat < 0 then do;
		urdy = coll_dat;
		visitnum =floor(urdy/7) ;
		end;
	else do;
		urdy = coll_dat + 1;	
		visitnum =ceil(urdy/7) ;
		end;
	coll_dat =coll_dat + rand_date;
	
	array ch(5) $ barb -- opi;
	array cvar(5) $ _temporary_ ("BARB", "BENZO", "THC", "COC", "OPI");
	array nu(2) $ mampconf creatin;
	array nvar(2) $ _temporary_ ("MAMPCONF", "CREATIN");
	do i=1 to 5;
		urtestcd = cvar(i); urtest = cvar(i); 
		if ch(i) ne "" then do;
			urorres = ch(i);  urstresc = ch(i); 
		end;
		else do;
			urorres = ""; urorresu= ""; urstresc = ""; urstresn = "";
		end;
		output;
	end;
	do i=1 to 2;
		urtestcd = nvar(i); urtest = nvar(i);
		if nu(i) ne "" and not(prxmatch('/[a-z]/i', nu(i))) then do;
			 urorresu= "ng/ml"; urorres = nu(i);  
			urstresc = "1"; urstresn = nu(i);
		end;
		else do;
			urorres = ""; urorresu= ""; urstresc = ""; urstresn = "";
		end;
		output;
	end;
	if ampconf ne '' or amp ne '' then do;
		urtestcd = "AMPHET"; URTEST =  "AMPHETAMINE"; 
		if ampconf ne '' and not(prxmatch('/[a-z]/i', ampconf)) then do;
			urorres = ampconf; urorresu= "ng/ml"; urstresc = "1"; 
			urstresn = input(ampconf, 8.);
		end;
		else do; 
			urorres = amp; urorresu = ""; urstresc = amp; urstresn = "";
		end;
		output;
	end;
	keep studyid usubjid urtestcd URTEST urorres urorresu urstresc urstresn urblfl 
				visitnum urdy coll_dat ;
run;

data ur;
	set empty_ur _ur;
	domain = "UR";
	urcat = "URINALYSIS";
	urtestcd = put(urtestcd, urtestcd.);
	urtest = put(urtest, urtest.);
	urdtc = put(coll_dat, E8601DA10.-L);
	visit =  put(visitnum,  visit.);
	urstresu = put(urorresu, unit.);
	urstresc = put(urstresc, urstresc.);
	keep &urkeeplist;
run;

proc sort data=ori.vs;
	by usubjid visdate;
run;

data _vs (keep=studyid usubjid vstestcd vstest vsorres vsorresu vsstresc vsstresn  
			vsblfl visitnum visdate  vsdy);
	merge ori.vs  random(keep=usubjid rand_date);
	by usubjid;
	length vsorresu $ 12 ;
	rename  visid = visitnum;
	if visitnum = 0 then vsblfl="Y";
	else VSBLFL="";
	vsdy= visdate +1;
	visdate = rand_date + visdate;
	
	array vsval(6) $ tempval -- weight;
	array vsvar(6) $ _temporary_ ("TEMPVAL","RESPRATE","BLDPRESS","BLDPRESD","PULSE","WEIGHT");
	array vsunit (6) $ 12. _temporary_ ("F","breaths/min","mmHg", "mmHg","beats/min","LB");
	do i=1 to 6;
		if vsval(i) ne "" and not(prxmatch('/[a-z]/i', vsval(i)))then do;
			vstestcd = vsvar(i); vstest = vsvar(i); vsorres = vsval(i); 
			vsorresu = vsunit (i); vsstresc = vsval(i);  vsstresn =input(vsval(i), 8.);
			output;
		end;
	end;
	if vsdy ne .;
run;

data vs;
	set empty_vs _vs;
	domain = "VS";
	vsdtc = put(visdate, E8601DA10.-L);
	vstestcd = put(vstestcd, vstestcd.);
	vstest = put(vstest, vstest.);
	vsstresu = put(vsorresu, vsresu.);
	visit=put(visitnum, visit.);
	keep &vskeeplist;
run;
/* **************************************************************************************
* sorting the dataset according to the keysequence metadata specified sort order 
* for a given dataset.
* if there is a __seq variable in a dataset, then create the __seq value for it
* ***************************************************************************************/
 %SortOrder();

 data status;
 	set ori.term;
	where status="1";
run;
%CheckMissing(random=random, status=status)
%ReLen(SDTM)
libname sdtmfile clear;
%Delmvars()
%cleanLib(work)
%cleanLib(&pname)

/* ****************************************
* Prepare ADaM dataset
* ****************************************/
libname adamfile  "&pdir.adam_metadata.xlsx";
%MakeEmptyDataset(ADaM)
proc sort data= suppdm;
	by usubjid qnam;
run;
proc transpose data =suppdm out= _adsupdm(drop=_name_  _label_
					rename=(randdt = randdtc 	educatyr = educatyrc));
	var qval;
	by usubjid;
	id qnam;
	IDLABEL qlabel;
run;

data addm;
	merge  empty_addm dm(in = indm where=(rfxstdtc ne ""))  
			_adsupdm(where=(randdtc ne ""));
	by usubjid;
	randdt = input(randdtc, E8601DA10.-L);
	educatyr = input(educatyrc, $3.);
	trtp = arm;
	if armcd = "P" then trtpn = 0;
	else if armcd = "T" then trtpn = 1;
	else trtpn = .;
	keep &addmkeeplist;
	if indm;
run;

data adsl;
	merge  empty_adsl  dm
			_adsupdm;
	by usubjid;
	if randdtc ne "" then do;
		randdt = input(randdtc, E8601DA10.-L);
		trtsdt = input(rfxstdtc,E8601DA10.-L);
		trtedt = input(rfxendtc,E8601DA10.-L);
		randfl = "Y";
		if (trtedt - trtsdt +1) >=84 then complfl ="Y";
		else complfl ="N";
	end;
	else do;
		randdt = "";	trtsdt = "";  trtedt = ""; 	
		randfl = "N";  complfl ="N";
	end;
	trt01p = arm;
	if armcd = "P" then trt01pn = 0;
	else if armcd = "T" then trt01pn = 1;
	else if armcd = "SCRNFAIL" then trtp01n = 2;
	else if armcd = "NOTASSGN" then trt01pn = 3;
	else trt01pn = .;
	pprotfl = eligible;
	keep &adslkeeplist;
run;

data adae;
	merge empty_adae ae ( in=inae rename= (aestdy = astdy  aeendy = aendy))  
			adsl(in=inad where=(trt01p ne "Screen Failure" and trt01p ne "Not Assigned" ) 
					keep= usubjid trt01p trt01pn);
	by usubjid;
	trta = trt01p;
	trtan = trt01pn;
	if aestdtc ne "" then astdt = input(aestdtc, E8601DA10.-L);
	else astdt=.;
	if aeendtc ne "" then aendt = input(aeendtc, E8601DA10.-L);
	else aendt=.;
	keep &adaekeeplist;
	if inae and inad;
run;
/*the last day recording in ur test does not match the recording in complete status recording
some subjedts were marked dropped, however, after several weeks, their ur test appeared again
Here, using complete status data*/ 
proc sql;
	create table _adur as
		select u.studyid, u.usubjid, d.age as age, d.sex as sex, d.race as race, d.arm as trtp, 
				d.trt01pn as trtpn, urstresn as aval, urstresc as avalc, visit as avisit, 
				visitnum as avisitn, input(urdtc, E8601DA10.-L) as adt ,  urdy as ady, 
				case when urblfl = "Y" then "Y" else "" end as ablfl,
				case when sum(urstresn)<=0 then "N" else "Y" end as crit1fl, 
				case when calculated crit1fl = "Y" then 1 else 0 end as crit1fn length=3,
				input(b.base, 3.) as base
		from ur as u, (select  usubjid, case when sum(urstresn)<=0 then "0" else "1" end as base 
							from ur where urblfl = "Y" and urtestcd = "METHAMPH" 
							group by usubjid) as b,
						adsl as d
		where u.usubjid = b.usubjid and u.usubjid = d.usubjid
				and  visitnum <= 13 and urtestcd = "METHAMPH"
		group by u.usubjid, visitnum;
quit;

data adur;
	set empty_adur _adur;
	param = "Qualitative Urine Drug Screen for Methamphetamine is Positive";
	paramcd = "URMEAMP" ;
	crit1 = "Week Methamphetamine Positive";
	keep &adurkeeplist;
run;
libname adamfile clear;
%Delmvars()
%cleanLib(work)
%cleanLib(&pname)

/*********************************
* Prepare analysis dataset
**********************************/
proc sql;
	create table anur as 
		select a.usubjid, trtp, trtpn, a.avisitn,  max(a.avisitn) as lastweek, a.ady, base, w_value,
			case when sum(crit1fn) =0 then 0 else 1 end as f_value
			from adur as a, 
				(select usubjid, avisitn, ady, case when sum(crit1fn) = 0 then 0 else 1 end as w_value
					from adur 
					group by usubjid, avisitn) as b
			where a.usubjid=b.usubjid and a.avisitn=b.avisitn and a.ady=b.ady
			group by a.usubjid
			order by a.usubjid, a.ady;
quit;

/*General info about the data
%LibInfor;
*/
