*options nosource;
%let pathlen = %sysfunc(find(%sysget(SAS_EXECFILEPATH),%str(\),-260));
%let path=%substr(%sysget(SAS_EXECFILEPATH), 1 , &pathlen);
%include "&path.project_defination.sas";
%include "&pdir.campaigns.sas";
%include "&pdir.modeling";

*%cleanLib;

*options source;
