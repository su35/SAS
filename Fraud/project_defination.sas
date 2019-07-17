/* *************************************************
* project _defination.sas
* define project global macro variables
* declare library, user folder and system options
* define the path of the macros,  custome call routins and functions
* *************************************************/

/*get full path to this file*/
%let fullpath=%sysget(SAS_EXECFILEPATH);

/*define the project name*/
%let pname=%scan(&fullpath, -2, %str(\));

/*define the root folder of all projects*/
%let proot=%substr(&fullpath, 1 , %eval(%index(&fullpath,&pname)-1));

/*define the project folder*/
%let pdir=&proot.&pname.\;

/*create the folders, if they are not existed*/
data _null_;
	if fileexist("&pdir.data")=0 then NewDir=dcreate("data","&pdir");
	if fileexist("&pdir.lib")=0 then NewDir=dcreate("lib","&pdir");
	if fileexist("&pdir.libori")=0 then NewDir=dcreate("libori","&pdir");
	if fileexist("&pdir.outfiles")=0 then NewDir=dcreate("outfiles","&pdir");
	if fileexist("&pdir.pmacro")=0 then NewDir=dcreate("pmacro","&pdir");
run; 
/*define the project out put file folder*/
%let pout=&pdir.outfiles\;

/* pub: self-defined macro, subroutine and function
	ori: original dataset that input from data
	plib: project lib*/
libname pub "&proot.pub";
libname ori  "&pdir.libori";
libname &pname  "&pdir.lib";
/*must use the name "library", so that SAS can automatically see the SAS formats 
without having to specify FMTSEARCH explicitly in the OPTIONS statement.*/
libname library "&pdir.lib"; 
/*copy the vardefine.csv to data folder. this command would be run once only*/
*X "copy &proot.pub\vardefine.csv &pdir.vardefine.csv";

options user= &pname;
options cmplib = pub.funcs; 
/*protect against overwriting the input data sets */
options datastmtchk =corekeywords;

/*define the custom autocall macro path*/
filename cmacros "&proot.cmacros";
filename pmacro "&pdir.pmacro";
options mautosource sasautos=(sasautos cmacros pmacro);
%include "&proot.cmacros\tools.sas";
/*define the format search order*/
options fmtsearch= (&pname library);
/*merge statement must be accompanied with by statement*/
options mergenoby = error;

options xsync noxwait ;

