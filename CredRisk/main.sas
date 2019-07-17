*options nosource;
%let pathlen = %sysfunc(find(%sysget(sas_execfilepath),%str(\),-260));
%let path=%substr(%sysget(sas_execfilepath), 1 , &pathlen);
%include "&path.project_defination.sas";
%include "&path.dataprep.sas";
%include "&path.ModelEvaluate.sas";
*options source;
/* ***********************************************
*  
*
* 
* ***************************************************/
%cleanLib;

