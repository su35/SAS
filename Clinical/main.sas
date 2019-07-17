*options nosource;
%let pathlen = %sysfunc(find(%sysget(SAS_EXECFILEPATH),%str(\),-260));
%let path=%substr(%sysget(SAS_EXECFILEPATH), 1 , &pathlen);
%include "&path.project_defination.sas";
%include "&pdir.data_prepare.sas";
%include "&pdir.analysis.sas";
%include "&pdir.reporting.sas";
/* ***********************************************
* export .xpt files 
* create define.xml file
* call pinnacle21 validator to validate the .xpt files
* ***************************************************/
%cdsic(SDTM);
%cdsic(ADaM);
*%cleanLib;

*options source;
