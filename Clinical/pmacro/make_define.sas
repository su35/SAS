/*---------------------------------------------------------------*;
* %make_define creates the define.xml file for the SDTM and ADaM.  
* It creates define.xml based on the contents of a set of metadata
* tabs found in an Excel spreadsheet.
*
* PARAMETERS:
*            path = System path to where the SDTM or ADaM metadata
*                   file exists as well as where the define.xml
*                   file will be stored.
*        metadata = The name of the metadata spreadsheet.
*
* It requires that the following tabs exist in the metadata file:
* DEFINE_HEADER_METADATA = define file header metadata
* TOC_METADATA = "table of contents" dataset metadata
* VARIABLE_METADATA = variable/column level metadata
* VALUELEVEL_METADATA = value/parameter level metadata
* COMPUTATIONAL_METHOD = computational methods
* CODELISTS = controlled terminology metadata
* ANALYSIS_RESULTS = ADaM analysis metadata. [Only for ADaM define]
* EXTERNAL_LINKS = ADaM results file pointers. [Only for ADaM define]
*---------------------------------------------------------------*/

%macro make_define(path=,metadata=);

**** GET DEFINE FILE HEADER INFORMATION METADATA;
proc import 
    out = work.md_define_header
    datafile = "&metadata" 
    dbms=excelcs 
    replace;
    sheet="DEFINE_HEADER_METADATA";
run;

**** DETERMINE IF THIS IS A SDTM DEFINE FILE OR AN ADAM DEFINE FILE
**** AND SET THE STANDARD MACRO VARIABLE FOR THE REST OF THE PROGRAM;
/*data _null_;*/
/*    set work.md_define_header;*/
/**/
/*    if upcase(standard) = 'ADAM-IG' then*/
/*        call symput('standard','ADAM');*/
/*    else if upcase(standard) = 'SDTM-IG' then*/
/*        call symput('standard','SDTM');*/
/*    else*/
/*        put "ERR" "OR: CDISC standard undefined in define_header_metadata";*/
/*run;*/

**** GET "TABLE OF CONTENTS" LEVEL DATASET METADATA;
proc import 
    out = work.md_toc_metadata
    datafile = "&metadata" 
    dbms=excelcs 
    replace;
    sheet = "TOC_METADATA" ;
run;

**** GET THE VARIABLE METADATA;
proc import 
    out = work.md_VARIABLE_METADATA
    datafile = "&metadata"
    dbms=excelcs
    replace;
    sheet = "VARIABLE_METADATA";
run;

**** GET THE CODELIST METADATA;
proc import 
    out = work.md_codelists
    datafile = "&metadata" 
    dbms=excelcs
    replace;
    sheet = "CODELISTS" ;
run; 

**** GET THE COMPUTATIONAL METHOD METADATA;
proc import 
    out = work.md_compmethod
    datafile = "&metadata" 
    dbms=excelcs
    replace;
    sheet = "COMPUTATION_METHOD" ;
run; 

**** GET THE VALUE LEVEL METADATA;
proc import 
    out = work.md_valuelevel
    datafile = "&metadata" 
    dbms=excelcs
    replace;
    sheet = "VALUELEVEL_METADATA" ;
run; 

**** GET THE WHERE CLAUSE METADATA;
proc import 
    out = work.md_whereclause
    datafile = "&metadata" 
    dbms=excelcs
    replace;
    sheet = "WHERE_CLAUSES" ;
run; 

**** GET THE METADATA COMMENTS;
proc import 
    out = work.md_comments
    datafile = "&metadata" 
    dbms=excelcs
    replace;
    sheet = "COMMENTS" ;
run; 

**** GET THE External Link Information;
proc import 
    out = work.md_externallinks
    datafile = "&metadata" 
    dbms=excelcs
    replace;
    sheet = "EXTERNAL_LINKS" ;
run; 

%if "&standard" = "ADAM" %then
  %do;
    **** GET THE ANALYSIS RESULTS METADATA;
    proc import 
        out = work.md_analysisresults
        datafile = "&metadata" 
        dbms=excelcs
        replace;
        sheet = "ANALYSIS_RESULTS" ;
    run; 

  %end;


**** use htmlencode on source text that needs encoding for proper browser representatiion;
%if &standard=ADAM %then
  %do;
  
    data work.md_toc_metadata;
        length documentation $ 800;
            set work.md_toc_metadata;
      
          documentation = htmlencode(documentation);
          ** convert single quotes to double quotes;
          documentation = tranwrd(documentation, "'", '"');
          ** convert double quotes to html quote;
          documentation = tranwrd(trim(documentation), '"', '&quot;');
          format documentation $800.;
    run;
  
  %end;
  
        
data work.md_VARIABLE_METADATA;
  length comment $ 2000;
  set work.md_VARIABLE_METADATA;

    format comment;
    informat comment;   
        origin = htmlencode(origin); 
    label = htmlencode(label); 
    comment = htmlencode(comment); 

        **** FOR ADAM, JOIN ORIGIN/"SOURCE" AND COMMENT
    **** TO FORM "SOURCE/DERIVATION" METADATA;
    if "&standard" = "ADAM" and origin ne '' and comment ne '' then 
          comment = "SOURCE: " || left(trim(origin)) ||
                    " DERIVATION: " || left(trim(comment)); 
    else if "&standard" = "ADAM" and origin ne '' and 
        comment = '' then 
          comment = "SOURCE: " || left(trim(origin)); 
    if "&standard" = "ADAM" and origin = '' and 
        comment ne '' then 
          comment = "DERIVATION: " || left(trim(comment)); 
run;

data work.md_codelists;
    set work.md_codelists;

    codedvalue = htmlencode(codedvalue);
    translated = htmlencode(translated);
run;

data work.md_compmethod;
    set work.md_compmethod;

    computationmethod = htmlencode(computationmethod); 
run;

*******  FIX THIS LATER SINCE COMMENTS ARE NOW IN A SEPARATE SPREADSHEET **********;
data work.md_valuelevel;
  length comment $ 2000;
  set work.md_valuelevel;

    format comment;
    informat comment;   
        origin = htmlencode(origin); 
    label = htmlencode(label); 
    comment = htmlencode(comment); 
        
        **** FOR ADAM, JOIN ORIGIN/"SOURCE" AND COMMENT
    **** TO FORM "SOURCE/DERIVATION" METADATA;
    if "&standard" = "ADAM" and origin ne '' and 
        comment ne '' then 
          comment = "SOURCE: " || left(trim(origin)) ||
                   " DERIVATION: " || left(trim(comment)); 
    else if "&standard" = "ADAM" and origin ne '' and 
        comment = '' then 
          comment = "SOURCE: " || left(trim(origin)); 
    if "&standard" = "ADAM" and origin = '' and 
        comment ne '' then 
          comment = "DERIVATION: " || left(trim(comment)); 
run;


%if "&standard" = "ADAM" %then
  %do;
    data work.md_analysisresults;
      length programmingcode $800. ;
      set work.md_analysisresults;
        where displayid ne '';
          
      arrow + 1;
      selectioncriteria = htmlencode(selectioncriteria); 
      paramlist = htmlencode(paramlist);
      reason = htmlencode(reason); 
      documentation = htmlencode(documentation);   
      
      programmingcode = htmlencode(programmingcode);
       
      ** convert single quotes to double quotes;
      programmingcode = tranwrd(programmingcode, "'", '"');
      ** convert double quotes to html quote;
      programmingcode = tranwrd(programmingcode, '"', '&quot;');
      format programmingcode $800.;
    run;

    ** ENSURE UNIQUENESS ON DISPLAYID AND RESULTID AND CREATE A COMBO ID;
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
      else
          arid = displayid;
    run;          
            
    ** TWO SEPARATE MERGES WITH EXTERNAL_LINKS ARE NEEDED:              ;
    **   1) To get the link information for the actual analysis display ;
    **      NOTE that DISPLAYID must match the LEAFID in EXTERNAL_LINKS ;
    **   2) To get the link information for the analysis reference      ;    
    proc sort
      data = work.md_analysisresults;
      by displayid;
    run;
 
    proc sort
      data = work.md_externallinks 
      (drop = LeafRelPath SupplementalDoc AnnotatedCRF
      rename=(title=doctitle leafid=displayid leafpageref=dsplylfpgref leafpagereftype=dsplylfpgreftyp))
      out  = work.md_doc_links;
      by displayid;
    run;
 
    data work.md_analysisresults;
      merge work.md_analysisresults (in = inar) work.md_doc_links (in = indoc_links);
      by displayid;
    
      if inar;
    run;
    
    ** now merge in reference links;
    proc sort
      data = work.md_analysisresults;
      by refleafid;
    run;
 
    proc sort
      data = work.md_externallinks 
      (drop = LeafRelPath SupplementalDoc AnnotatedCRF
      rename=(title=reftitle leafid=refleafid leafpageref=reflfpgref leafpagereftype=reflfpgreftyp))
      out  = work.md_doc_links;
      by refleafid;
    run;
 
    data work.md_analysisresults;
      merge work.md_analysisresults (in = inar) work.md_doc_links (in = indoc_links);
      by refleafid;
    
      if inar;
    run;

    proc sort
      data = work.md_analysisresults;
      by arrow;
    run;
  %end;
    
**** CREATE DEFINE FILE HEADER SECTION;
filename dheader "&path\define_header.txt";
data work.md_define_header;
    set work.md_define_header;

    file dheader notitles;

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

data work.md_define_header2;
    file dheader mod notitles;
    set work.md_externallinks;
    
        if _n_ = 1 then
          put /
              @5 "<!-- ******************************************* -->" /
              @5 "<!-- EXTERNAL DOCUMENT REFERENCE             *** -->" /    
              @5 "<!-- ******************************************* -->"
              ;

        if upcase(SupplementalDoc) in('Y', '1', 'YES') then
          put
            @5 '<def:SupplementalDoc>' /
            @7 '<def:DocumentRef leafID="' leafid +(-1) '"/>' /
            @5 '</def:SupplementalDoc>' /
            ;
        if upcase(AnnotatedCRF) in('Y', '1', 'YES') then
          put
            @5 '<def:AnnotatedCRF>' /
            @7 '<def:DocumentRef leafID="' leafid +(-1) '"/>' /
            @5 '</def:AnnotatedCRF>' /
            ; 
run;


**** ADD LEAVES;
filename leaves "&path\leaves.txt";
data _null_;
  set work.md_externallinks;

        file leaves notitles;


        if _n_ = 1 then
          put /
              @5 "<!-- ******************************************* -->" /
              @5 "<!-- LEAF DEFINITION SECTION                 *** -->" /    
              @5 "<!-- ******************************************* -->"
              ;

       put @5 '<def:leaf ID="' leafid +(-1) '"'     /
            @7 'xlink:href="' leafrelpath +(-1) '">' /
            @7 '<def:title>' title '</def:title>'    /
            @5 '</def:leaf>' /
            ;
run;            


**** ADD ITEMOID TO VARIABLE METADATA;
proc sort
  data = work.md_VARIABLE_METADATA;
    by DOMAIN variable;

proc sort
  data = work.md_valuelevel
  (keep = domain variable)
  out = work.md_vlmid
  nodupkey;
    by domain variable;
    
data work.md_VARIABLE_METADATA;
    length itemoid valuelistoid $ 200;
    merge work.md_VARIABLE_METADATA (in = in_vm rename=(domain = oid))
          work.md_vlmid             (in = in_vlm rename=(domain = oid))
          ;
      by oid variable;

    if in_vm;
    itemoid = compress(oid || "." || variable);
      
    if in_vlm then
      valuelistoid = 'VL.' || compress(itemoid) ;
run;

        
**** ADD ITEMOID TO VALUE LEVEL METADATA;
proc sort
  data = work.md_valuelevel;
    by domain variable valuevar valuename ;
run;
    
data work.md_valuelevel work.md_whereclause2 (keep = whereclauseoid domain valuevar valuename);
    length valuelistoid $200. itemoid whereclauseoid $ 200;
    set work.md_valuelevel;
      by domain variable valuevar valuename ;
    
    ** NOTE: The VALUELISTOID has to be unique in order for the unique value/variable-level metadata ;
    **       to be represented.  Therefore, _SEQ is used to uniquely define VALUELISTOID when one ;
    **       VALUENAME (e.g. TESTCD/PARAMCD) has multiple records; 
    drop _seq;
    if first.valuename then
      _seq = 0;
    if not(first.valuename and last.valuename) then
      _seq + 1;
    
    if valuelistoid = '' then     
      valuelistoid = compress("VL." || compress(domain) || "." || compress(variable)); 

    itemoid = compress(valuelistoid) || "." || trim(valuename);
    if _seq>0 then
      itemoid = compress(valuelistoid) || "." || trim(valuename) || "." || put(_seq,1.);
    
    ** if WhereClauseOID is missing in the spreadsheet then create a simple WhereClause ;
    **   for the PARAMCD/TESTCD only                                                    ;
    if whereclauseoid = '' then
      do;
        if itemoid=:'VL.' then
          whereclauseoid = 'WC.' || compress(substr(itemoid,4));
        else 
          whereclauseoid = 'WC.' || compress(itemoid);
        output work.md_whereclause2;
*        put whereclauseoid= valuelistoid= valuevar= valuename= ;
      end;
      
    output work.md_valuelevel;
    format whereclauseoid $200.;
run;

data work.md_whereclause2;
  set work.md_whereclause2;
  
        retain seq ' 1' softhard 'Soft' comparator 'EQ' ;
        drop domain valuevar;
        rename valuename = values;
        itemoid = compress(domain || "." || valuevar);
run;


**** CREATE COMPUTATION METHOD SECTION;
proc contents
  data = work.md_compmethod;
run;

filename comp "&path\compmethod.txt";
data work.md_compmethods;
    set work.md_compmethod;

    file comp notitles;

    if _n_ = 1 then
      put /
          @5 "<!-- ******************************************* -->" /
          @5 "<!-- COMPUTATIONAL METHOD INFORMATION        *** -->" /    
          @5 "<!-- ******************************************* -->"
          ;
    put @5 '<MethodDef OID="' computationmethodoid +(-1) '" Name="' label +(-1) '" Type="' type +(-1) '">' /
        @7 '<Description>' /
        @9 '<TranslatedText xml:lang="en">' computationmethod +(-1) '</TranslatedText>' /
        @7 '</Description>' /
        @5 '</MethodDef>'
        ;
run;


**** CREATE COMMENTS SECTION;
filename commnts "&path\comments.txt";
data work.md_comments;
    set work.md_comments;

    file commnts notitles;

    if _n_ = 1 then
      put /
          @5 "<!-- ******************************** -->" /
          @5 "<!-- COMMENTS DEFINITION SECTION      -->" /
          @5 "<!-- ******************************** -->" 
          ;
    put @5 '<def:CommentDef OID="' commentoid +(-1) '">' / 
        @7 '<Description>' /
        @9 '<TranslatedText xml:lang="en">' comment +(-1) '</TranslatedText>' /
        @7 '</Description>' /
        @5 '</def:CommentDef>'
        ;
        
run;

**** CREATE VALUE LEVEL LIST DEFINITION SECTION;
proc sort
    data=work.md_valuelevel;
    where valuelistoid ne '';
    by valuelistoid;
run;

filename vallist "&path\valuelist.txt";
data work.md_valuelevel;
  set work.md_valuelevel;
    by valuelistoid;

    file vallist notitles;

    if _n_ = 1 then
      put /
          @5 "<!-- ******************************************* -->" /
          @5 "<!-- VALUE LEVEL LIST DEFINITION INFORMATION  ** -->" /    
          @5 "<!-- ******************************************* -->";

    if first.valuelistoid then
      put @5 '<def:ValueListDef OID="' valuelistoid +(-1) '">';

    ** If a computation method *and* a comment are both linked, the computation method will ;
    **   take priority.  Otherwise set the MethodOID to the comment oid;
    if computationmethodoid ne '' then
      methodoid = computationmethodoid;
    else
      methodoid = commentoid;
      
    put @7 '<ItemRef ItemOID="' itemoid /***valuename***/ +(-1) '"' /
        @9 'OrderNumber="' varnum +(-1) '"'  /
        @9 'Mandatory="' mandatory +(-1) '"' @;

    if methodoid ne '' then
      put / @9 'MethodOID="' methodoid +(-1) '"' @; 

    put '>' /
        @9 '<def:WhereClauseRef WhereClauseOID="' whereclauseoid +(-1) '"/>' / 
        @7 '</ItemRef>'
        ;

    if last.valuelistoid then
      put @5 '</def:ValueListDef>';
run;

**** CREATE WHERE CLAUSE DEFINITION SECTION;
proc sort
    data=work.md_whereclause;
    where whereclauseoid ne '';
    by whereclauseoid seq;
run;

filename wherecls "&path\whereclause.txt";
data work.md_whereclause3;
  length whereclauseoid values itemoid $200. softhard comparator $5. seq $2. ;
  set work.md_whereclause2 work.md_whereclause ;
    by whereclauseoid seq;    

    file wherecls notitles;

    if _n_ = 1 then
      put /
          @5 '<!-- ****************************************************************** -->' /
          @5 '<!-- WhereClause Definitions Used/Referenced in Value List Definitions) -->' /    
          @5 '<!-- ****************************************************************** -->'  
          ;

    if first.whereclauseoid then
      put @5 '<def:WhereClauseDef OID="' whereclauseoid +(-1) '">';

    *--- default softhard to Soft if not specified;
    if softhard eq '' then
      softhard = 'Soft';

    *--- NOTE: Would be nice to know how to handle OR conditions-- are they possible?;   
    put @7 '<RangeCheck SoftHard="' softhard +(-1) '" def:ItemOID="' itemoid +(-1) '" Comparator="' comparator +(-1) '">' /
        @9 '<CheckValue>' values +(-1) '</CheckValue>' /
        @7 '</RangeCheck>' 
        ;

    if last.whereclauseoid then
      put @5 '</def:WhereClauseDef>';

    format whereclauseoid itemoid values $200. softhard comparator $5. seq $2. ;
run;   


**** CREATE "ITEMGROUPDEF" SECTION;
proc sort
    data=work.md_VARIABLE_METADATA;
    where oid ne '';
    by oid varnum;
run;

proc sort
    data=work.md_toc_metadata;
    where oid ne '';
    by oid;
run;

** per the Define-XML specification (section 3.4.2) display datasets in an order ;
**     based on their class; 
proc format;
    value $clsordr "TRIAL DESIGN"    = "1"
                   "SPECIAL PURPOSE" = "2"
                   "INTERVENTIONS"   = "3"
                   "EVENTS"          = "4"
                   "FINDINGS"        = "5"
                   "FINDINGS ABOUT"  = "6"
                   "RELATIONSHIP"    = "7"
                   "SUBJECT LEVEL ANALYSIS DATASET" = "1"
                   "OCCURRENCE DATA STRUCTURE"      = "2"
                   "BASIC DATA STRUCTURE"           = "3"
                   "ADAM OTHER"                     = "4"
    ;
run;

data work.md_itemgroupdef;
    length label $ 40;
    merge work.md_toc_metadata (rename=(commentoid=dmcommentoid))
          work.md_VARIABLE_METADATA(drop=label)
          ;
    by oid;

    _order = input(put(upcase(class), $clsordr.), best.);
run;

proc sort
  data = work.md_itemgroupdef;
    by _order oid;
run;
    
filename igdef "&path\itemgroupdef.txt";
data work.md_itemgroupdef;
  set work.md_itemgroupdef;
    by _order oid;
            
    file igdef notitles; 

    ** Trim all trailing blanks and other non-visible characters to ensure no warnings are issued by ;
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
        if dmcommentoid ne '' then
            put @7 'def:CommentOID="' dmcommentoid +(-1) '"' ;
        
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

    if computationmethodoid ne '' then 
      put @9 'MethodOID="' computationmethodoid +(-1) '"' ;
        
    if keysequence then 
      put  @9 'KeySequence="' keysequence +(-1) '"' ;
        
    if role ne '' and "&standard" = "SDTM" then
      put @9 'Role="' role +(-1) '"'    /
          @9 'RoleCodeListOID="CodeList.rolecode"/>'
          ;
    else
      put '/>';


    if last.oid then
      put @7 "<!-- **************************************************** -->" /
          @7 "<!-- def:leaf details for hypertext linking the dataset   -->" /
          @7 "<!-- **************************************************** -->" /
          @7 '<def:leaf ID="Location.' oid +(-1) '" xlink:href="' archivelocationid +(-1) '.xpt">' /
          @9 '<def:title>' archivelocationid +(-1) '.xpt </def:title>' /
          @7 '</def:leaf>' /
          @5 '</ItemGroupDef>';
run;
  

**** CREATE "ITEMDEF" SECTION;
filename idef "&path\itemdef.txt";
 
data work.md_itemdef;
    set work.md_VARIABLE_METADATA end=eof;
    by oid;

    file idef notitles; 

    if _n_ = 1 then
      put @5 "<!-- ************************************************************ -->" /
          @5 "<!-- The details of each variable are here for all domains         -->" /
          @5 "<!-- ************************************************************ -->" ;

    put @5 '<ItemDef OID="' itemoid +(-1) '"' /
        @7 'Name="' variable +(-1) '"' /
        @7 'SASFieldName="' variable +(-1) '"' /
        @7 'DataType="' type +(-1) '"';
    /* JBS 2016-02-06: date datatypes cannot have a length specified in define even though it is needed for BASE macro to create dates */
    if length ne '' and type ne 'date' then
      put @7 'Length="' length +(-1) '"';
    if significantdigits ne '' then
      put @7 'SignificantDigits="' significantdigits +(-1) '"';
    if displayformat ne '' then
      put @7 'def:DisplayFormat="' displayformat +(-1) '"';
    else if length ne '' then
      put @7 'def:DisplayFormat="' length +(-1) '"';

    if commentoid ne '' then
      put @7 'def:CommentOID="' commentoid +(-1) '"';
    put @7 '>' /            

        @7 '<Description>' /
        @9 '  <TranslatedText xml:lang="en">' label +(-1) '</TranslatedText>' /
        @7 '</Description>';

    if codelistname ne '' then
      put @7 '<CodeListRef CodeListOID="CodeList.' codelistname +(-1) '"/>';

    if upcase(origin)=:'CRF PAGE' then 
      do;
        if "&standard" = "ADAM" then
          put 'WARN' 'ING: CRF Page origins for ADaM variables are not allowed.  SDTM predecessor variables should be used instead'; 
        pageref = compress(substr(origin, 9));
        origin = 'CRF'; 
        put @7 '<def:Origin Type="' origin +(-1) '">' ;
      end; 
    else if "&standard" = "ADAM" and upcase(origin) not in:('DERIVED', 'ASSIGNED', 'PROTOCOL', 'EDT') then 
      do;
        ** if just a domain/data set is provided (i.e. there is no '.') then use the current variable name joined with the data ;
        **   set/domain for the predecessor;
        if index(origin,'.')=0 then
          origin = trim(origin) || '.' || trim(variable);        
        put @7  '<def:Origin Type="Predecessor">' /
            @9  '<Description>' /
            @11 '<TranslatedText xml:lang="en">' origin +(-1) '</TranslatedText>' /
            @9  '</Description>' 
            ;
      end;
    else
      put @7 '<def:Origin Type="' origin +(-1) '">' ;
    if pageref then 
      put @9 '<def:DocumentRef leafID="blankcrf">' /
          @11 '<def:PDFPageRef PageRefs="' pageref +(-1) '" Type="PhysicalRef"/>' /
          @9 '</def:DocumentRef>'
          ;
    put @7 '</def:Origin>' ;
               
    if valuelistoid ne '' then
      put @7 '<def:ValueListRef ValueListOID="' valuelistoid +(-1) '"/>';

    put @5 '</ItemDef>';
run;
 

**** ADD ITEMDEFS FOR VALUE LEVEL ITEMS TO "ITEMDEF" SECTION;
filename idefvl "&path\itemdef_value.txt";
 
data work.md_itemdefvalue;
    length sasfieldname $16.;
    set work.md_valuelevel end=eof;
    by valuelistoid;

    file idefvl notitles; 

    if _n_ = 1 then
      put @5 "<!-- ************************************************************ -->" /
          @5 "<!-- The details of value level items are here                    -->" /
          @5 "<!-- ************************************************************ -->" ;

    if sasfieldname='' then
      sasfieldname = valuename;

    put @5 '<ItemDef OID="' itemoid /*valuename*/ +(-1) '"' /
        @7 'Name="' valuename +(-1) '"' /
        @7 'DataType="' type +(-1) '"' /
        @7 'SASFieldName="' sasfieldname +(-1) '"'
        ;
    if length ne '' then
      put @7 'Length="' length +(-1) '"';
    if significantdigits ne '' then
      put @7 'SignificantDigits="' significantdigits +(-1) '"';
    if displayformat ne '' then
      put @7 'def:DisplayFormat="' displayformat +(-1) '"';
    else if length ne '' then
      put @7 'def:DisplayFormat="' length +(-1) '"';
/* JBS 2016-01-16 ITEMDEF cant have computationmethodoid but ITEMREF can 
    if computationmethodoid ne '' then
      put @7 'def:methodoid="' computationmethodoid +(-1) '"';
*/    
    put @7 ">";
    
    if label ne '' then
      put @7 "<Description>" / 
          @9 '<TranslatedText xml:lang="en">' label +(-1) '</TranslatedText>' /
          @7 "</Description>" ;
          
    if codelistname ne '' then
      put @7 '<CodeListRef CodeListOID="CodeList.' codelistname +(-1) '"/>';

    if upcase(origin)=:'CRF PAGE' then 
      do;
        if "&standard" = "ADAM" then
          put 'WARN' 'ING: CRF Page origins for ADaM variables are not allowed.  SDTM  predecessor variables should be used instead'; 
        pageref = compress(substr(origin, 9));
        origin = 'CRF'; 
        put @7 '<def:Origin Type="' origin +(-1) '">' ;
      end; 
    else if "&standard" = "ADAM" and upcase(origin) not in:('DERIVED', 'ASSIGNED', 'PROTOCOL',  'EDT') then 
      do;
        ** if just a domain/data set is provided (i.e. there is no '.') then use the current  variable name joined with the data ;
        **   set/domain for the predecessor;
        if index(origin,'.')=0 then
          origin = trim(origin) || '.' || trim(variable);        
        put @7  '<def:Origin Type="Predecessor">' /
            @9  '<Description>' /
            @11 '<TranslatedText xml:lang="en">' origin +(-1) '</TranslatedText>' /
            @9  '</Description>' 
            ;
      end;
    else
      put @7 '<def:Origin Type="' origin +(-1) '">' ;
    if pageref then 
      put @9 '<def:DocumentRef leafID="blankcrf">' /
          @11 '<def:PDFPageRef PageRefs="' pageref +(-1) '" Type="PhysicalRef"/>' /
          @9 '</def:DocumentRef>'
          ;
    put @7 '</def:Origin>' ;
    put @5 '</ItemDef>';
run;
 

**** ADD ANALYSIS RESULTS METADATA SECTION FOR ADAM;
%if "&standard" = "ADAM" %then
  %do;
    filename ar "&path\analysisresults.txt";

    data _null_;
      set work.md_analysisresults end=eof;

      ** note that it is required that identical display IDs be adjacent to 
      ** each other in the metadata spreadsheet;
      by displayid notsorted;

      file ar notitles; 
      if _n_ = 1 then
        put @5 "<!-- ************************************************************ -->" /
            @5 "<!-- Analysis Results MetaData are Presented Below                -->" /
            @5 "<!-- ************************************************************ -->" /
            @5 "<arm:AnalysisResultDisplays> "/
            ;
      if first.displayid then
        put @5 '<arm:ResultDisplay OID="RD.' displayid +(-1) '" Name="' doctitle +(-1) '"> ' /
            @7 '<Description>' /
            @9 '  <TranslatedText xml:lang="en">' displayname +(-1) '</TranslatedText>' /
            @7 '</Description>' /
            @7 '<def:DocumentRef leafID="' displayid +(-1) '">' /
            @9 '<def:PDFPageRef PageRefs="' dsplylfpgref +(-1) '" Type="' dsplylfpgreftyp +(-1) '"/>' /
            @7 '</def:DocumentRef>' 
            ;
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
      do while(scan(analysisvariables,vnum,',') ne '');
        analysisvar = scan(analysisvariables,vnum,',');
        put @11 '<arm:AnalysisVariable ItemOID="' analysisdataset +(-1) '.' analysisvar +(-1) '"/>';
        vnum = vnum + 1;
      end;
      
      put  @11 '</arm:AnalysisDataset>' / 
           @9  '</arm:AnalysisDatasets>'
           ;
    
      /*    @13    '<def:ComputationMethod OID="SC' _n_ z3. 
                 '" Name="Selection Criteria ' _n_ z3. '"> [' selectioncriteria ' ]</def:ComputationMethod> '/
          @11  '</adamref:SelectionCriteria> ' /
      */

      put @9  '<arm:Documentation>' /
          @9  '<Description>'       /
          @11 '<TranslatedText xml:lang="en">' documentation '</TranslatedText>' /
          @9  '</Description>' /
          @9  '<def:DocumentRef  leafID="' refleafid +(-1) '">' 
          ;
      if leafpageref ne '' then
          put @11 '<def:PDFPageRef PageRefs="' reflfpgref +(-1) '" Type="' reflfpgreftyp +(-1) '"/>' ;
      put @9  '</def:DocumentRef>' /
          @9  '</arm:Documentation>' / 
          ;
          
      *---------------------------------------------------------------;
      * put each line of code on a separate line to prevent the output;
      * table from being too wide;
      *---------------------------------------------------------------;
      length _tmp $100; *array lines{99} $100 _temporary_;
      if programmingcode ne '' then
        do;
          put @9  '<arm:ProgrammingCode Context="' context +(-1) '">' /
              @9  '<arm:Code>' ;
          _tmp = tranwrd(programmingcode,"%nrstr(&quot;)", "%nrstr(&quot:)");
          i = 1;
          do while(scan(_tmp,i,';')^='');
            _tmp2 = scan(_tmp,i,';');
            _tmp2 = trim(tranwrd(_tmp2,"%nrstr(&quot:)", "%nrstr(&quot;)")) || ';';
            if upcase(_tmp2) in:('DATA', 'PROC', 'RUN') then
              put @1 _tmp2;
            else 
              put @3 _tmp2;
            i = i+1;
          end;
          put @9  '</arm:Code>' /
              @9  '</arm:ProgrammingCode>'
              ;
        end;
      if programleafid ne '' then
        put @9   '<arm:ProgrammingCode Context="' context +(-1) '">'    /
            @11  '<def:DocumentRef leafID="' programleafid +(-1) '" />' /
            @9  '</arm:ProgrammingCode>'
            ;
                
      put @7 '</arm:AnalysisResult>' ;
        
      if last.displayid then
        put @5 '</arm:ResultDisplay>';
      
      if eof then 
        put @5 '</arm:AnalysisResultDisplays>' ;
        
    run;  
  %end;


**** CREATE CODELIST SECTION;
filename codes "&path\codelist.txt";
 
proc sort
    data=work.md_codelists
    nodupkey;
    by codelistname codedvalue translated;
run;

**** MAKE SURE CODELIST IS UNIQUE;
data _null_;    
    set work.md_codelists;
    by codelistname codedvalue;

    if not (first.codedvalue and last.codedvalue) then 
      put "ERR" "OR: multiple versions of the same coded value " 
           codelistname= codedvalue=;
run;

proc sort
    data=work.md_codelists;
    by codelistname rank;   
run;

data work.md_codelists;
    set work.md_codelists end=eof;
    by codelistname rank;

    file codes notitles; 

    if _n_ = 1 then
      put @5 "<!-- ************************************************************ -->" /
          @5 "<!-- Codelists are presented below                                -->" /
          @5 "<!-- ************************************************************ -->" ;

    if first.codelistname then
      put @5 '<CodeList OID="CodeList.' codelistname +(-1) '"' /
          @7 'Name="' codelistname +(-1) '"' /
          @7 'DataType="' type +(-1) '">';

    **** output codelists that are not external dictionaries;
    if codelistdictionary = '' then
      do;
        put @7  '<CodeListItem CodedValue="' codedvalue +(-1) '"' @;
        if rank ne . then
      put ' Rank="' rank +(-1) '"' @;
    if ordernumber ne . then
      put ' OrderNumber="' ordernumber +(-1) '"' @;
    put '>';
        put @9  '<Decode>' /
            @11 '<TranslatedText>' translated +(-1) '</TranslatedText>' /
            @9  '</Decode>' /
            @7  '</CodeListItem>';
      end;
    **** output codelists that are pointers to external codelists;
    if codelistdictionary ne '' then
      put @7 '<ExternalCodeList Dictionary="' codelistdictionary +(-1) 
             '" Version="' codelistversion +(-1) '"/>';

    if last.codelistname then
      put @5 '</CodeList>';

run;

filename closeit "&path\closeit.txt";
data _null_;

      file closeit notitles;
      put @3 '</MetaDataVersion>' /
          @1 '</Study>' /
          @1 '</ODM>';
run;

** create the .BAT file that will put all of the files together to create the define;
** NOTE: codelist.txt MUST come last because it contains the closing XML code;
filename dotbat "make_define.bat";
data _null_;
    file dotbat notitles;
    drive = substr("&path",1,2); 
    put @1 drive;
    put @1 "cd &path";
    put @1 "type define_header.txt valuelist.txt whereclause.txt itemgroupdef.txt itemdef.txt itemdef_value.txt  codelist.txt compmethod.txt comments.txt leaves.txt" @@;
    if "&standard" = "ADAM" then
      put " analysisresults.txt " @@ ;
    put " closeit.txt > define.xml " ;
    put @1 "exit";
run;
x "make_define";    
x "del &path\*.txt";
x "&path\&xsldefine";

%mend make_define;

