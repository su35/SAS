/* ***********************************************************************************************
     Name  : SDTM.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: Output transport file for each SDTM dataset.
                   Create the define file
                   Call Pinnacle 21 Community validator to validate
*   *********************************************************************************************/
/*If the SDTM folder doesn't exist, create the folder*/
data _null_;
    if fileexist("&pdir.SDTM")=0 then 
        NewDir=dcreate("SDTM","&pdir");
    stop;
run; 

/*define the metadata file and path pointed to SDTM folder*/
%let metadatafile=&pdir.SDTM_METADATA.xlsx;
%let path=&pdir.SDTM\;
%let sheet=Contents;

/*output the transport file to SDTM folder*/
proc import 
    datafile="&metadatafile"
    out=_temp(keep=name) 
    dbms=excelcs
    replace;
    sheet="&sheet";
run;
data _null_;
    set _temp;
    code=catx(" ", "libname", name, "xport %tslit(&path"||trim(name)||".xpt);", 
                "proc copy in=&pname out=", name, "; select", name, "; run;");
    call execute(code);
run;

/*copy the ODM define file to SDTM folder*/
%sysexec copy "&proot.pub\define2-0-0.xsl" "&path.define2-0-0.xsl";

/*create the define.xml*/
%make_define(metadata=&metadatafile, path=&path)

/*Specify the version of the controlled terminology XML*/
%let ctdatadate=2016-06-24;
/*configuration file to be used for validation*/
%let config=SDTM 3.2.xml;

/*create the validate report file*/
%P21Validate(type=SDTM, sources=&path , ctdatadate=&ctdatadate, config=&config);

