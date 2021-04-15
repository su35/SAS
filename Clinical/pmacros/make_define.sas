/* ***********************************************************************************************
     Name  : make_define.sas
     Author: Jun Fang 
                 Modified from Chris Holland and Jack Shostak's code
*    --------------------------------------------------------------------------------------------*
     Purpose: Creates the define.xml file for the SDTM and ADaM.  
                    It creates define.xml based on the contents of a set of metadata
                    tabs found in an Excel spreadsheet.
*    --------------------------------------------------------------------------------------------*
     Parameters : metadata = The name of the metadata spreadsheet. (required)
                         path         = System path to where the SDTM or ADaM data located, 
                                             as well as where the define.xml file will be stored.
                         xsldefine   = CDSIC ODM define file
*    --------------------------------------------------------------------------------------------*
     Notes: It requires that the following tabs exist in the metadata file:
                DefineHearder = define file header metadata
                Contents = "table of contents" dataset metadata
                VariableLevel = variable/column level metadata
                ValueLevel = value/parameter level metadata
                ComputationMethods = computational methods
                CodeLists = controlled terminology metadata
                AnalysisResults = ADaM analysis metadata. [Only for ADaM define]
                ExternalLinks = ADaM results file pointers. [Only for ADaM define]
*   *********************************************************************************************/
%macro make_define(metadata, path, xsldefine);
	%local standard;

	%if %superq(metadata) ne %then
		%do;
			/*the metadata does not include the path*/
			%if %index(&metadata, \)=0 %then
				%let metadata=&pdir.&metadata;

			/*declare the libref*/
			%if %sysfunc(fileexist("&metadata")) %then
				libname templib xlsx "&metadata"%str(;);
			%else
				%do;
					%put ERROR: ==The file "&metadata" could be found==;

					%return;
				%end;
		%end;
	%else
		%do;
			%put ERROR: ==The parameter metadata is missing==;

			%return;
		%end;

	/*ascertain the standard*/
	data work.md_defineHeader;
		set templib.DefineHeader;

		if upcase(standard) = 'ADAM-IG' then
			call symput('standard','ADAM');
		else if upcase(standard) = 'SDTM-IG' then
			call symput('standard','SDTM');
		else put "ERR" "OR: CDISC standard undefined in Define_Hearder";
	run;

	/*if the path was not assigned, define the path*/
	%if %superq(path)= %then
		%let path=&pdir.&standard\;

	/*if the xsldefine was not assigned, define the xsldefine*/
	%if %superq(xsldefine)= %then
		%let xsldefine =define2-0-0.xsl;

	/*use htmlencode on source text that needs encoding for proper browser 
	   representatiion*/
	data work.md_Contents;
		set templib.Contents;

		%if &standard=ADAM %then
			%do;
				length documentation $ 800;
				documentation = htmlencode(documentation);

				** convert single quotes to double quotes;
				documentation = tranwrd(documentation, "'", '"');

				** convert double quotes to html quote;
				documentation = tranwrd(trim(documentation), '"', '&quot;');
				format documentation $800.;
			%end;
	run;

	data work.md_VariableLevel;
		length comment $ 2000 origin label $ 200;
		set templib.VariableLevel;
		format comment;
		informat comment;
		origin = htmlencode(origin);
		label = htmlencode(label);
		comment = htmlencode(comment);

		/* For adam, join origin/"source" and comment
		    to form "source/derivation" metadata*/
		if "&standard" = "ADAM" then
			do;
				if not missing(origin) and not missing(comment) then
					comment =catx(" ", "SOURCE:", origin, "DERIVATION:", comment);
				else if not missing(origin) and missing(comment) then
					comment = catx(" ", "SOURCE:", origin);
				else if missing(origin) and not missing(comment) then
					comment =catx(" ", "DERIVATION:", comment);
			end;
	run;

	data work.md_codelists;
		set templib.codelists;
		codedvalue = htmlencode(codedvalue);
		translated = htmlencode(translated);
	run;

	data work.md_compmethod;
		length computationmethod $10000;
		set templib.ComputationMethod;
		computationmethod = htmlencode(computationmethod);
	run;

	/*Fix this later since comments are now in a separate spreadsheet */
	data work.md_valuelevel;
		length comment $ 2000 origin label $ 200;
		set templib.ValueLevel;
		format comment;
		informat comment;
		origin = htmlencode(origin);
		label = htmlencode(label);
		comment = htmlencode(comment);

		/* For adam, join origin/"source" and comment
		     to form "source/derivation" metadata;*/
		if "&standard" = "ADAM" then
			do;
				if not missing(origin) and not missing(comment) then
					comment =catx(" ", "SOURCE:", origin, "DERIVATION:", comment);
				else if not missing(origin) and missing(comment) then
					comment = catx(" ", "SOURCE:", origin);
				else if missing(origin) and not missing(comment) then
					comment =catx(" ", "DERIVATION:", comment);
			end;
	run;

	%if "&standard" = "ADAM" %then
		%do;

			data work.md_analysisresults;
				length programmingcode $800.;
				set templib.analysisresults;
				where displayid is not missing;
				arrow + 1;

				/*            selectioncriteria = htmlencode(selectioncriteria); */
				/*            paramlist = htmlencode(paramlist);*/
				reason = htmlencode(reason);
				documentation = htmlencode(documentation);
				programmingcode = htmlencode(programmingcode);

				** convert single quotes to double quotes;
				programmingcode = tranwrd(programmingcode, "'", '"');

				** convert double quotes to html quote;
				programmingcode = tranwrd(programmingcode, '"', '&quot;');
				format programmingcode $800.;
			run;

			/* Ensure uniqueness on displayid and resultid and create a combo id*/
			data work.md_analysisresults;
				set work.md_analysisresults;
				by displayid notsorted;
				drop resultnum;
				retain resultnum;

				if first.displayid then
					resultnum = 0;
				resultnum + 1;

				if not(first.displayid and last.displayid) then
					arid = trim(displayid) || ".R." || put(resultnum,z2.);
				else arid = displayid;
			run;

			/* Two separate merges with ExternalLinks are needed:              ;
			 **   1) To get the link information for the actual analysis display ;
			 **      NOTE that DISPLAYID must match the LEAFID in ExternalLinks ;
		 **   2) To get the link information for the analysis reference   */
			proc sort data = work.md_analysisresults;
				by displayid;
			run;

			proc sort data = templib.ExternalLinks 
				(drop = LeafRelPath SupplementalDoc AnnotatedCRF)
				out  = work.md_doc_links(rename=(title=doctitle leafid=displayid leafpageref=dsplylfpgref 
				leafpagereftype=dsplylfpgreftyp));
				by leafid;
			run;

			data work.md_analysisresults;
				merge work.md_analysisresults (in = inar) 
					work.md_doc_links (in = indoc_links);
				by displayid;

				if inar;
			run;

			/* now merge in reference links*/
			proc sort data = work.md_analysisresults;
				by refleafid;
			run;

			proc sort  data = templib.ExternalLinks  
				(drop = LeafRelPath SupplementalDoc AnnotatedCRF)
				out  = work.md_doc_links(rename=(title=reftitle leafid=refleafid leafpageref=reflfpgref 
				leafpagereftype=reflfpgreftyp));
				by leafid;
			run;

			data work.md_analysisresults;
				merge work.md_analysisresults (in = inar) 
					work.md_doc_links (in = indoc_links);
				by refleafid;

				if inar;
			run;

			proc sort data = work.md_analysisresults;
				by arrow;
			run;

		%end;

	/* Create define file header section */
	filename dheader "&path.define_header.txt";

	data work.md_defineHeader;
		set work.md_defineHeader;
		file dheader notitles lrecl=32767;
		creationdate = compress(put(datetime(), IS8601DT.));
		put @1 '<?xml version="1.0" encoding="ISO-8859-1" ?>' /
		@1 '<?xml-stylesheet type="text/xsl" href="' stylesheet +(-1) '"?>' /
		@1 '<!-- ******************************************************************************* -->' /
		@1 '<!-- File: define.xml                                                                -->' /
		@1 "<!-- Date: &sysdate9.                                                                -->" /
		@1 '<!-- Description: Define.xml file for '   studyname +(-1) '                          -->' /
		@1 '<!-- Created by the %make_define SAS macro                                          -->' /
		@1 '<!-- ******************************************************************************* -->' /
		@1 '<ODM' /
		@3 'xmlns="http://www.cdisc.org/ns/odm/v1.3"'/ 
		@3 'xmlns:xlink="http://www.w3.org/1999/xlink"'/
		@3 'xmlns:def="http://www.cdisc.org/ns/def/v2.0"'/
		@3 'ODMVersion="1.3.2"'/
		%if "&standard" = "ADAM" %then
			@3 'xmlns:arm="http://www.cdisc.org/ns/arm/v1.0"' /
		;

		/*@3 '<!-- Assuming no extensions and therefore no schema -->' /
		 @3 '<!--xsi:schemaLocation="' schemalocation +(-1) '" -->' /     */

		@3 'FileOID="' fileoid +(-1) '"' /
		@3 'FileType="Snapshot"' /
		@3 'CreationDateTime="' creationdate +(-1) '">' /
		@1 '<Study OID="' studyoid +(-1) '">' /
		@3 '<GlobalVariables>' /
		@5 '<StudyName>' studyname +(-1) '</StudyName>' /
		@5 '<StudyDescription>' studydescription +(-1) '</StudyDescription>' /
		@5 '<ProtocolName>' protocolname +(-1) '</ProtocolName>' /
		@3 '</GlobalVariables>' /
		@3 '<MetaDataVersion OID="CDISC.' standard +(-1) '.' version +(-1) '"' /
		@5 'Name="' studyname +(-1) ', ' "&standard" ' Data Definitions"' /
		@5 'Description="' studyname +(-1) ', ' "&standard" ' Data Definitions"' /
		@5 'def:DefineVersion="2.0.0"' /
		@5 'def:StandardName="' standard +(-1) '"' /
		@5 'def:StandardVersion="' version +(-1) '">' 
		;
	run;

	data work.md_defineHeader2;
		file dheader mod notitles lrecl=32767;
		set templib.ExternalLinks;

		if _n_ = 1 then
			put /
			@5 "<!-- ******************************************* -->" /
			@5 "<!-- EXTERNAL DOCUMENT REFERENCE             *** -->" /    
			@5 "<!-- ******************************************* -->";

		if upcase(SupplementalDoc) in('Y', '1', 'YES') then
			put
			@5 '<def:SupplementalDoc>' /
			@7 '<def:DocumentRef leafID="' leafid +(-1) '"/>' /
			@5 '</def:SupplementalDoc>' /;

		if upcase(AnnotatedCRF) in('Y', '1', 'YES') then
			put
			@5 '<def:AnnotatedCRF>' /
			@7 '<def:DocumentRef leafID="' leafid +(-1) '"/>' /
			@5 '</def:AnnotatedCRF>' /;
	run;

	/* Add leaves*/
	filename leaves "&path.leaves.txt";

	data _null_;
		set templib.ExternalLinks;
		file leaves notitles lrecl=32767;

		if _n_ = 1 then
			put /
			@5 "<!-- ******************************************* -->" /
			@5 "<!-- LEAF DEFINITION SECTION                 *** -->" /    
			@5 "<!-- ******************************************* -->";
		put @5 '<def:leaf ID="' leafid +(-1) '"'     /
			@7 'xlink:href="' leafrelpath +(-1) '">' /
			@7 '<def:title>' title '</def:title>'    /
			@5 '</def:leaf>' /
		;
	run;

	/* ADD ITEMOID TO VARIABLE METADATA*/
	proc sort  data = work.md_VariableLevel;
		by domain Variable;
	run;

	proc sort data = work.md_valuelevel (keep = domain variable)
		out = work.md_vlmid 
		nodupkey;
		by domain variable;
	run;

	data work.md_VariableLevel;
		length itemoid valuelistoid $ 200;
		merge work.md_VariableLevel (in = in_vm rename=(domain = oid))
			work.md_vlmid   (in = in_vlm rename=(domain = oid))
		;
		by oid variable;

		if in_vm;
		itemoid = compress(oid || "." || variable);

		if in_vlm then
			valuelistoid = 'VL.' || compress(itemoid);
	run;

	/* Add itemoid to value level metadata*/
	proc sort data = work.md_valuelevel;
		by domain variable valuevar valuename;
	run;

	data work.md_valuelevel work.md_whereclause2 (keep = whereclauseoid domain valuevar valuename);
		length valuelistoid $200. itemoid whereclauseoid $ 200;
		set work.md_valuelevel;
		by domain variable valuevar valuename;

		** NOTE: The VALUELISTOID has to be unique in order for the unique value/variable-level metadata;
		**       to be represented.  Therefore, _SEQ is used to uniquely define VALUELISTOID when one;
		**       VALUENAME (e.g. TESTCD/PARAMCD) has multiple records;
		drop _seq;

		if first.valuename then
			_seq = 0;

		if not(first.valuename and last.valuename) then
			_seq + 1;

		if missing(valuelistoid) then
			valuelistoid = compress("VL." || compress(domain) || "." || compress(variable));
		itemoid = compress(valuelistoid) || "." || trim(valuename);

		if _seq>0 then
			itemoid = compress(valuelistoid) || "." || trim(valuename) || "." || put(_seq,1.);

		** if WhereClauseOID is missing in the spreadsheet then create a simple WhereClause;
		**   for the PARAMCD/TESTCD only;
		if missing(whereclauseoid) then
			do;
				if itemoid=:'VL.' then
					whereclauseoid = 'WC.' || compress(substr(itemoid,4));
				else whereclauseoid = 'WC.' || compress(itemoid);
				output work.md_whereclause2;
			end;

		output work.md_valuelevel;
		format whereclauseoid $200.;
	run;

	data work.md_whereclause2;
		set work.md_whereclause2;
		retain seq ' 1' softhard 'Soft' comparator 'EQ';
		drop domain valuevar;
		rename valuename = values;
		itemoid = compress(domain || "." || valuevar);
	run;

	/* Create computation method section*/
	proc contents data = work.md_compmethod;
	run;

	filename comp "&path.compmethod.txt";

	data work.md_compmethods;
		set work.md_compmethod;
		file comp notitles lrecl=32767;

		if _n_ = 1 then
			put /
			@5 "<!-- ******************************************* -->" /
			@5 "<!-- COMPUTATIONAL METHOD INFORMATION        *** -->" /    
			@5 "<!-- ******************************************* -->";
		put @5 '<MethodDef OID="' computationmethodoid +(-1) '" Name="' label +(-1) '" Type="' type +(-1) '">' /
			@7 '<Description>' /
			@9 '<TranslatedText xml:lang="en">' computationmethod +(-1) '</TranslatedText>' /
			@7 '</Description>' /
			@5 '</MethodDef>'
		;
	run;

	/* Create comments section*/
	filename commnts "&path.comments.txt";

	data work.md_comments;
		set templib.comments;
		file commnts notitles lrecl=32767;

		if _n_ = 1 then
			put /
			@5 "<!-- ******************************** -->" /
			@5 "<!-- COMMENTS DEFINITION SECTION      -->" /
			@5 "<!-- ******************************** -->";
		put @5 '<def:CommentDef OID="' commentoid +(-1) '">' / 
			@7 '<Description>' /
			@9 '<TranslatedText xml:lang="en">' comment +(-1) '</TranslatedText>' /
			@7 '</Description>' /
			@5 '</def:CommentDef>'
		;
	run;

	/* CREATE VALUE LEVEL LIST DEFINITION SECTION*/
	proc sort  data=work.md_valuelevel;
		where valuelistoid is not missing;
		by valuelistoid;
	run;

	filename vallist "&path.valuelist.txt";

	data work.md_valuelevel;
		set work.md_valuelevel;
		by valuelistoid;
		file vallist notitles lrecl=32767;

		if _n_ = 1 then
			put /
			@5 "<!-- ******************************************* -->" /
			@5 "<!-- VALUE LEVEL LIST DEFINITION INFORMATION  ** -->" /    
			@5 "<!-- ******************************************* -->";

		if first.valuelistoid then
			put @5 '<def:ValueListDef OID="' valuelistoid +(-1) '">';

		** If a computation method *and* a comment are both linked, the computation method will;
		**   take priority.  Otherwise set the MethodOID to the comment oid;
		if not missing(computationmethodoid) then
			methodoid = computationmethodoid;
		else methodoid = commentoid;
		put @7 '<ItemRef ItemOID="' itemoid /***valuename***/

		+(-1) '"' /
		@9 'OrderNumber="' varnum +(-1) '"'  /
		@9 'Mandatory="' mandatory +(-1) '"' @;
		if not missing(methodoid) then
			put / @9 'MethodOID="' methodoid +(-1) '"' @;
		put '>' /
			@9 '<def:WhereClauseRef WhereClauseOID="' whereclauseoid +(-1) '"/>' / 
			@7 '</ItemRef>'
		;

		if last.valuelistoid then
			put @5 '</def:ValueListDef>';
	run;

	/* Create where clause definition section*/
	proc sort data=templib.WhereClauses out=work.md_whereclause;
		where whereclauseoid is not missing;
		by whereclauseoid seq;
	run;

	filename wherecls "&path.whereclause.txt";

	data work.md_whereclause3;
		length whereclauseoid values itemoid $200. softhard comparator $5. seq $2.;
		set work.md_whereclause2 work.md_whereclause;
		by whereclauseoid seq;
		file wherecls notitles lrecl=32767;

		if _n_ = 1 then
			put /
			@5 '<!-- ****************************************************************** -->' /
			@5 '<!-- WhereClause Definitions Used/Referenced in Value List Definitions) -->' /    
			@5 '<!-- ****************************************************************** -->';

		if first.whereclauseoid then
			put @5 '<def:WhereClauseDef OID="' whereclauseoid +(-1) '">';

		*--- default softhard to Soft if not specified;
		if missing(softhard) then
			softhard = 'Soft';

		*--- NOTE: Would be nice to know how to handle OR conditions-- are they possible?;
		put @7 '<RangeCheck SoftHard="' softhard +(-1) '" def:ItemOID="' itemoid +(-1) '" Comparator="' comparator +(-1) '">' /
			@9 '<CheckValue>' values +(-1) '</CheckValue>' /
			@7 '</RangeCheck>' 
		;

		if last.whereclauseoid then
			put @5 '</def:WhereClauseDef>';
		format whereclauseoid itemoid values $200. softhard comparator $5. seq $2.;
	run;

	/* Create "itemgroupdef" section*/
	proc sort data=work.md_VariableLevel;
		where oid is not missing;
		by oid varnum;
	run;

	proc sort data=work.md_Contents;
		where oid is not missing;
		by oid;
	run;

	/* per the Define-XML specification (section 3.4.2) display datasets 
	   in an order based on their class*/
	proc format;
		value $clsordr "TRIAL DESIGN"    = "1"
			"SPECIAL PURPOSE" = "2"
			"INTERVENTIONS"   = "3"
			"EVENTS"          = "4"
			"FINDINGS"        = "5"
			"FINDINGS ABOUT"  = "6"
			"RELATIONSHIPS"    = "7"
			"SUBJECT LEVEL ANALYSIS DATASET" = "1"
			"OCCURRENCE DATA STRUCTURE"      = "2"
			"BASIC DATA STRUCTURE"           = "3"
			"ADAM OTHER"                     = "4"
		;
	run;

	data work.md_itemgroupdef;
		length label $ 40;
		merge work.md_Contents (rename=(commentoid=dmcommentoid))
			work.md_VariableLevel(drop=label)
		;
		by oid;
		_order = input(put(upcase(class), $clsordr.), best.);
	run;

	proc sort data = work.md_itemgroupdef;
		by _order oid;
	run;

	filename igdef "&path.itemgroupdef.txt";

	data work.md_itemgroupdef;
		set work.md_itemgroupdef;
		by _order oid;
		file igdef notitles lrecl=32767;

		** Trim all trailing blanks and other non-visible characters to ensure no warnings are issued by;
		** the stylesheet;
		if upcase(purpose)=:'TABULATION' then
			purpose = 'Tabulation';
		else if upcase(purpose)=:'ANALYSIS' then
			purpose = 'Analysis';

		if first.oid then
			do;
				put @5 "<!-- ******************************************* -->" /
					@5 "<!-- " oid   @25   "ItemGroupDef INFORMATION *** -->" /    
					@5 "<!-- ******************************************* -->" /
					@5 '<ItemGroupDef OID="' oid +(-1) '"' /
					@7 'Domain="' name +(-1) '"' /
					@7 'Name="' name +(-1) '"' /
					@7 'Repeating="' repeating +(-1) '"' /
					@7 'Purpose="' purpose +(-1) '"' /
					@7 'IsReferenceData="' isreferencedata +(-1) '"' /
					@7 'SASDatasetName="' name +(-1) '"' /
					@7 'def:Structure="' structure +(-1) '"' /
					@7 'def:Class="' class +(-1) '"' 
				;

				if not missing(dmcommentoid) then
					put @7 'def:CommentOID="' dmcommentoid +(-1) '"';
				put @7 'def:ArchiveLocationID="Location.' oid +(-1) '">' /
					  @7 '<Description>' /
					  @9 '<TranslatedText xml:lang="en">' label +(-1) '</TranslatedText>' /
					  @7 '</Description>' 
				;
			end;

		put @7 '<ItemRef ItemOID="' itemoid +(-1) '"' /
			  @9 'OrderNumber="' varnum +(-1) '"'  /
			  @9 'Mandatory="' mandatory +(-1) '"' 
		;

		if not missing(computationmethodoid) then
			put @9 'MethodOID="' computationmethodoid +(-1) '"';

		if keysequence then
			put  @9 'KeySequence="' keysequence +(-1) '"';

		if not missing(role) and "&standard" = "SDTM" then
			put @9 'Role="' role +(-1) '"'    /
    			  @9 'RoleCodeListOID="CodeList.rolecode"/>';
		else put '/>';

		if last.oid then
			put @7 "<!-- **************************************************** -->" /
    			  @7 "<!-- def:leaf details for hypertext linking the dataset   -->" /
    			  @7 "<!-- **************************************************** -->" /
    			  @7 '<def:leaf ID="Location.' oid +(-1) '" xlink:href="' archivelocationid +(-1) '.xpt">' /
    			  @9 '<def:title>' archivelocationid +(-1) '.xpt </def:title>' /
    			  @7 '</def:leaf>' /
    			  @5 '</ItemGroupDef>';
	run;

	/* Create "itemdef" section*/
	filename idef "&path.itemdef.txt";

	data work.md_itemdef;
		set work.md_VariableLevel end=eof;
		by oid;
		file idef notitles lrecl=32767;

		if _n_ = 1 then
			put @5 "<!-- ************************************************************ -->" /
    			  @5 "<!-- The details of each variable are here for all domains         -->" /
    			  @5 "<!-- ************************************************************ -->";
		put @5 '<ItemDef OID="' itemoid +(-1) '"' /
			  @7 'Name="' variable +(-1) '"' /
			  @7 'SASFieldName="' variable +(-1) '"' /
			  @7 'DataType="' type +(-1) '"';

		/* JBS 2016-02-06: date datatypes cannot have a length specified in define even though it is needed for BASE macro to create dates */
		if not missing(length) and type ne 'date' then
			put @7 'Length="' length +(-1) '"';

		if not missing(significantdigits) then
			put @7 'SignificantDigits="' significantdigits +(-1) '"';

		if not missing(displayformat) then
			put @7 'def:DisplayFormat="' displayformat +(-1) '"';
		else if not missing(length) then
			put @7 'def:DisplayFormat="' length +(-1) '"';

		if not missing(commentoid) then
			put @7 'def:CommentOID="' commentoid +(-1) '"';
		put @7 '>' /            
			  @7 '<Description>' /
			  @9 '  <TranslatedText xml:lang="en">' label +(-1) '</TranslatedText>' /
			  @7 '</Description>';

		if not missing(codelistname) then
			put @7 '<CodeListRef CodeListOID="CodeList.' codelistname +(-1) '"/>';

		if upcase(origin)=:'CRF PAGE' then
			do;
				if "&standard" = "ADAM" then
					put 'WARN' 'ING: CRF Page origins for ADaM variables are not allowed.  SDTM predecessor variables should be used instead';
				pageref = compress(substr(origin, 9));
				origin = 'CRF';
				put @7 '<def:Origin Type="' origin +(-1) '">';
			end;
		else if "&standard" = "ADAM" and upcase(origin) not in:('DERIVED', 'ASSIGNED', 'PROTOCOL', 'EDT') then
			do;
				** if just a domain/data set is provided (i.e. there is no '.') then use the current variable name joined with the data;
				**   set/domain for the predecessor;
				if index(origin,'.')=0 then
					origin = trim(origin) || '.' || trim(variable);
				put @7  '<def:Origin Type="Predecessor">' /
    				  @9  '<Description>' /
    				  @11 '<TranslatedText xml:lang="en">' origin +(-1) '</TranslatedText>' /
    				  @9  '</Description>' 
    			 ;
			end;
		else put @7 '<def:Origin Type="' origin +(-1) '">';

		if not missing(pageref) then
			put @9 '<def:DocumentRef leafID="blankcrf">' /
    			  @11 '<def:PDFPageRef PageRefs="' pageref +(-1) '" Type="PhysicalRef"/>' /
    			  @9 '</def:DocumentRef>';
		put @7 '</def:Origin>';

		if not missing(valuelistoid) then
			put @7 '<def:ValueListRef ValueListOID="' valuelistoid +(-1) '"/>';
		put @5 '</ItemDef>';
	run;

	/* Add itemdefs for value level items to "itemdef" section*/
	filename idefvl "&path.itemdef_value.txt";

	data work.md_itemdefvalue;
		length sasfieldname $16.;
		set work.md_valuelevel end=eof;
		by valuelistoid;
		file idefvl notitles lrecl=32767;

		if _n_ = 1 then
			put @5 "<!-- ************************************************************ -->" /
    			  @5 "<!-- The details of value level items are here                    -->" /
    			  @5 "<!-- ************************************************************ -->";

		if missing(sasfieldname) then
			sasfieldname = valuename;
		put @5 '<ItemDef OID="' itemoid /*valuename*/

    		  +(-1) '"' /
    		  @7 'Name="' valuename +(-1) '"' /
    		  @7 'DataType="' type +(-1) '"' /
    		  @7 'SASFieldName="' sasfieldname +(-1) '"'
    		;
		if not missing(length) then
			put @7 'Length="' length +(-1) '"';

		if not missing(significantdigits) then
			put @7 'SignificantDigits="' significantdigits +(-1) '"';

		if not missing(displayformat) then
			put @7 'def:DisplayFormat="' displayformat +(-1) '"';
		else if not missing(length) then
			put @7 'def:DisplayFormat="' length +(-1) '"';

		/* JBS 2016-01-16 ITEMDEF cant have computationmethodoid but ITEMREF can 
		     if computationmethodoid ne '' then
		       put @7 'def:methodoid="' computationmethodoid +(-1) '"';
		*/
		put @7 ">";

		if not missing(label) then
			put @7 "<Description>" / 
    			  @9 '<TranslatedText xml:lang="en">' label +(-1) '</TranslatedText>' /
    			  @7 "</Description>";

		if not missing(codelistname) then
			put @7 '<CodeListRef CodeListOID="CodeList.' codelistname +(-1) '"/>';

		if upcase(origin)=:'CRF PAGE' then
			do;
				if "&standard" = "ADAM" then
					put 'WARN' 'ING: CRF Page origins for ADaM variables are not allowed.  SDTM  predecessor variables should be used instead';
				pageref = compress(substr(origin, 9));
				origin = 'CRF';
				put @7 '<def:Origin Type="' origin +(-1) '">';
			end;
		else if "&standard" = "ADAM" and upcase(origin) not in:('DERIVED', 'ASSIGNED', 'PROTOCOL',  'EDT') then
			do;
				/* if just a domain/data set is provided (i.e. there is no '.') then use the current  
				       variable name joined with the data set/domain for the predecessor*/
				if index(origin,'.')=0 then
					origin = trim(origin) || '.' || trim(variable);
				put @7  '<def:Origin Type="Predecessor">' /
					  @9  '<Description>' /
					  @11 '<TranslatedText xml:lang="en">' origin +(-1) '</TranslatedText>' /
					  @9  '</Description>' 
				  ;
			end;
		else put @7 '<def:Origin Type="' origin +(-1) '">';

		if not missing(pageref) then
			put @9 '<def:DocumentRef leafID="blankcrf">' /
    			  @11 '<def:PDFPageRef PageRefs="' pageref +(-1) '" Type="PhysicalRef"/>' /
    			  @9 '</def:DocumentRef>';
		put @7 '</def:Origin>';
		put @5 '</ItemDef>';
	run;

	/*Add analysis results metadata section for adam*/
	%if "&standard" = "ADAM" %then
		%do;
			filename ar "&path.analysisresults.txt";

			data _null_;
				set work.md_analysisresults end=eof;

				** note that it is required that identical display IDs be adjacent to 
				** each other in the metadata spreadsheet;
				by displayid notsorted;
				file ar notitles lrecl=32767;

				if _n_ = 1 then
					put @5 "<!-- ************************************************************ -->" /
    					  @5 "<!-- Analysis Results MetaData are Presented Below                -->" /
    					  @5 "<!-- ************************************************************ -->" /
    					  @5 "<arm:AnalysisResultDisplays> "/;

				if first.displayid then
					put @5 '<arm:ResultDisplay OID="RD.' displayid +(-1) '" Name="' doctitle +(-1) '"> ' /
					      @7 '<Description>' /
					      @9 '  <TranslatedText xml:lang="en">' displayname +(-1) '</TranslatedText>' /
					      @7 '</Description>' /
					      @7 '<def:DocumentRef leafID="' displayid +(-1) '">' /
					      @9 '<def:PDFPageRef PageRefs="' dsplylfpgref +(-1) '" Type="' dsplylfpgreftyp +(-1) '"/>' /
					      @7 '</def:DocumentRef>';
				put   @7 '<arm:AnalysisResult ' / 
					    @9 'OID="' arid +(-1) '"' /
					    @9 'ParameterOID="' analysisdataset +(-1) '.PARAMCD"' /
					    @9 'ResultIdentifier="' arid +(-1) '"' /
					    @9 'AnalysisReason="' reason +(-1) '"' /
					    @9 'AnalysisPurpose="' purpose +(-1) '">' /
					    @9 '<Description>' /
					    @11 '<TranslatedText xml:lang="en">' resultname +(-1) '</TranslatedText>' /
					    @9 '</Description>' /
					    @9 '<arm:AnalysisDatasets>' /
					    @11 '<arm:AnalysisDataset ItemGroupOID="' analysisdataset +(-1) '" >' /
					    @11 '<def:WhereClauseRef WhereClauseOID="' whereclauseoid +(-1) '" />' /
				   ;

				** loop through the analysis variables;
				vnum = 1;

				do while(not missing(scan(analysisvariables,vnum,',')));
					analysisvar = scan(analysisvariables,vnum,',');
					put @11 '<arm:AnalysisVariable ItemOID="' analysisdataset +(-1) '.' analysisvar +(-1) '"/>';
					vnum = vnum + 1;
				end;

				put  @11 '</arm:AnalysisDataset>' / 
					   @9  '</arm:AnalysisDatasets>'
				  ;
				put @9  '<arm:Documentation>' /
					  @9  '<Description>'       /
					  @11 '<TranslatedText xml:lang="en">' documentation '</TranslatedText>' /
					  @9  '</Description>' /
					  @9  '<def:DocumentRef  leafID="' refleafid +(-1) '">' 
				  ;

				if not missing(reflfpgref) then
					put @11 '<def:PDFPageRef PageRefs="' reflfpgref +(-1) '" Type="' reflfpgreftyp +(-1) '"/>';
				put @9  '</def:DocumentRef>' /
					  @9  '</arm:Documentation>' / 
				   ;

				*---------------------------------------------------------------;
				* put each line of code on a separate line to prevent the output;
				* table from being too wide;
				*---------------------------------------------------------------;
				length _tmp $100;

				*array lines{99} $100 _temporary_;
				if not missing(programmingcode) then
					do;
						put @9  '<arm:ProgrammingCode Context="' context +(-1) '">' /
							  @9  '<arm:Code>';
						_tmp = tranwrd(programmingcode,"%nrstr(&quot;)", "%nrstr(&quot:)");
						i = 1;

						do while( not missing(scan(_tmp,i,';')));
							_tmp2 = scan(_tmp,i,';');
							_tmp2 = trim(tranwrd(_tmp2,"%nrstr(&quot:)", "%nrstr(&quot;)")) || ';';

							if upcase(_tmp2) in:('DATA', 'PROC', 'RUN') then
								put @1 _tmp2;
							else put @3 _tmp2;
							i = i+1;
						end;

						put @9  '</arm:Code>' /
							  @9  '</arm:ProgrammingCode>'
						  ;
					end;

				if  not missing(programleafid) then
					put @9   '<arm:ProgrammingCode Context="' context +(-1) '">'    /
					      @11  '<def:DocumentRef leafID="' programleafid +(-1) '" />' /
					      @9  '</arm:ProgrammingCode>';
				put @7 '</arm:AnalysisResult>';

				if last.displayid then
					put @5 '</arm:ResultDisplay>';

				if eof then
					put @5 '</arm:AnalysisResultDisplays>';
			run;
		%end;

	/*Create codelist section*/
	filename codes "&path.codelist.txt";

	proc sort data=work.md_codelists
		nodupkey;
		by codelistname codedvalue translated;
	run;

	/* Make sure codelist is unique*/
	data _null_;
		set work.md_codelists;
		by codelistname codedvalue;

		if not (first.codedvalue and last.codedvalue) then
			put "ERR" "OR: multiple versions of the same coded value " 
			codelistname= codedvalue=;
	run;

	proc sort data=work.md_codelists;
		by codelistname rank;
	run;

	data work.md_codelists;
		set work.md_codelists end=eof;
		by codelistname rank;
		file codes notitles lrecl=32767;

		if _n_ = 1 then
			put @5 "<!-- ************************************************************ -->" /
			      @5 "<!-- Codelists are presented below                                -->" /
			      @5 "<!-- ************************************************************ -->";

		if first.codelistname then
			put @5 '<CodeList OID="CodeList.' codelistname +(-1) '"' /
			      @7 'Name="' codelistname +(-1) '"' /
			      @7 'DataType="' type +(-1) '">';

		**** output codelists that are not external dictionaries;
		if missing(codelistdictionary) then
			do;
				put @7  '<CodeListItem CodedValue="' codedvalue +(-1) '"' @;

				if not missing(rank) then
					put ' Rank="' rank +(-1) '"' @;

				if not missing(ordernumber) then
					put ' OrderNumber="' ordernumber +(-1) '"' @;
				put '>';
				put @9  '<Decode>' /
					  @11 '<TranslatedText>' translated +(-1) '</TranslatedText>' /
					  @9  '</Decode>' /
					  @7  '</CodeListItem>';
			end;

		**** output codelists that are pointers to external codelists;
		if not missing(codelistdictionary) then
			put @7 '<ExternalCodeList Dictionary="' codelistdictionary +(-1) 
			'" Version="' codelistversion +(-1) '"/>';

		if last.codelistname then
			put @5 '</CodeList>';
	run;

	filename closeit "&path.closeit.txt";

	data _null_;
		file closeit notitles lrecl=32767;
		put @3 '</MetaDataVersion>' /
			  @1 '</Study>' /
			  @1 '</ODM>';
	run;

	/*create the .BAT file that will put all of the files together to create the define;
 ** NOTE: codelist.txt MUST come last because it contains the closing XML code*/
	filename dotbat "make_define.bat";

	data _null_;
		file dotbat notitles lrecl=32767;
		drive = substr("&path",1,2);
		put @1 drive;
		put @1 "cd &path";
		put @1 "type define_header.txt valuelist.txt whereclause.txt itemgroupdef.txt itemdef.txt itemdef_value.txt  codelist.txt compmethod.txt comments.txt leaves.txt" @@;

		if "&standard" = "ADAM" then
			put " analysisresults.txt " @@;
		put " closeit.txt > define.xml ";
		put @1 "exit";
	run;

	x "make_define";
	x  %tslit(del "&path\*.txt");

	/*    x "&path.&xsldefine";*/
	libname templib clear;

    proc datasets lib=work noprint;
        delete md_: ;
    run;
    quit;
%mend make_define;
