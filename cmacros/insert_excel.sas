/* ******************************************************
* macro insert_excel.sas: create a xml file or inset a sheet into an existed xml file
* usage: call by custome insert_excel call routine
* ********************************************************/

%macro insert_excel;
	%let lib=%sysfunc(compress(&lib,"'")); 
	%let dataset=%sysfunc(compress(&dataset,"'")); 
	%let file=%sysfunc(compress(&file,"'")); 

	ods tagsets.excelxp	options( Sheet_Name="&dataset");
	proc sql;
		select memname, name, type, length, format   from dictionary.columns 
			where libname = "&lib" and memname = "&dataset"
			order by memname, type;
	quit;
%mend insert_excel;

