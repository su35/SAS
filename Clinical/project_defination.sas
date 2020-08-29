/* *************************************************
* project _defination.sas
* define project global macro variables
* declare library, user folder and system options
* define the path of the macros,  custome call routins and functions
* *************************************************/

/*get full path to this file*/
%let fullpath=%sysget(sas_execfilepath);

/*define the project name*/
%let pname=%scan(&fullpath, -2, %str(\));

/*define the root folder of all projects*/
%let proot=%substr(&fullpath, 1 , %eval(%index(&fullpath,&pname)-1));

/*define the project folder*/
%let pdir=&proot.&pname.\;

/*create the folder libori and lib, if they are not existed*/
data _null_;
   if fileexist("&pdir.libori") =0 then NewDir=dcreate("libori","&pdir");
   if fileexist("&pdir.lib")=0 then NewDir=dcreate("lib","&pdir");
   if fileexist("&pdir.libori")=0 then NewDir=dcreate("libori","&pdir");
   if fileexist("&pdir.outfiles")=0 then NewDir=dcreate("outfiles","&pdir");
   if fileexist("&pdir.pmacro")=0 then NewDir=dcreate("pmacro","&pdir");
*   if fileexist("&pdir.funcs")=0 then NewDir=dcreate("funcs","&pdir");
run; 
/*define the project out put file folder*/
%let pout=&pdir.outfiles\;

/* publib: subroutine and function
   orilib: original dataset that input from data
   plib: project lib*/
libname publib "&proot.pub";
libname orilib  "&pdir.libori";
libname &pname  "&pdir.lib";

options user= &pname;
options cmplib = (publib.funcs); 
/*protect against overwriting the input data sets */
options datastmtchk =corekeywords;

/*define the custom autocall macro path*/
filename cmacros "&proot.cmacros";
filename pmacro "&pdir.pmacro";
options mautosource sasautos=(sasautos cmacros pmacro);
*options mstored sasmstore=&pname;
%include "&proot.cmacros\tools.sas";

/*define the format search order*/
options fmtsearch= (&pname work library);
/*merge statement must be accompanied with by statement*/
options mergenoby = error;

options xsync noxwait ;
/*uses threaded processing if available*/
options threads=yes cpucount=&sysncpu;

%symdel fullpath;

/*copy the vardefine.csv to data folder. this command need to run once only*/
*X "copy &proot.pub\vardefine.csv &pdir.vardefine.csv";
