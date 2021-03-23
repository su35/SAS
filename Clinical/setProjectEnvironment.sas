/* *******************************************************************************************************
     Name : setProjectEnvironment.sas
     Author: Jun Fang  Feb. 2017
*    -----------------------------------------------------------------------------------------------------*
     purpose  : set project environment, including:
                     1. define project global macro variables and options. 
                         Using readonly option to protect those variables.
                     2. define the librefs. if the location is not available, then create the location.
                     3. define the location of the custome macros, custome call routins and functions.
                     4. declare system option.
*    -----------------------------------------------------------------------------------------------------*
    usage: copy the this file to project folder and run it.
*   ******************************************************************************************************/
options nosource;

/*get full path to this file*/
%let setFile=%sysget(sas_execfilepath);

/*get the project name*/
%let projectName=%scan(&setFile, -2, %str(\));

/*define the project folder, the max length of filename in windows is 260*/
%global/readonly pdir=%substr(&setFile, 1, %sysfunc(find(&setFile, %str(\), -261)));

/*define the root folder of all projects*/
%global/readonly proot=%substr(&pdir, 1, %eval(%sysfunc(find(&pdir, \&projectName, -261, I))));

/*remove blanks from projectName. if its length is larger than 8, then trunce the length to 8.*/
%macro getpname(name);
    %let name=%sysfunc(compress(&name));
    %if %length(&name)>8 %Then %let name=%substr(&name,1,8);
    &name
%mend getpname;
/*define the project name which will use to create libref, so the max lenght is 8*/
%global/readonly pname=%getpname(&projectName);

/*define the project outpur files folder. if the folder doesn't exist, then create it. */
%global/readonly pout=%sysfunc(ifc(%sysfunc(fileexist(&pdir.outfiles)), &pdir.outfiles, 
                                                         %sysfunc(dcreate(outfiles,&pdir))))\;

/*define the project temp files folder to store the temp files. 
* if the folder doesn't exist, then create it.                                */
%global/readonly ptemp=%sysfunc(ifc(%sysfunc(fileexist(&pdir.temp)), &pdir.temp, 
                                                            %sysfunc(dcreate(temp,&pdir))))\;

/* declare the libref. if the folder doesn't exist, then create it. 
    publib: self-defined macro, subroutine and function
    orilib: original dataset that input from data
    plib: project lib*/
libname publib "&proot.pub";
libname orilib  "%sysfunc(ifc(%sysfunc(fileexist(&pdir.libori)), &pdir.libori, %sysfunc(dcreate(libori,&pdir))))";
libname &pname  "%sysfunc(ifc(%sysfunc(fileexist(&pdir.lib)) ,&pdir.lib, %sysfunc(dcreate(lib,&pdir))))";

/*define the custom autocall macro path*/
options mautosource;
options insert=(sasautos=("&proot.cmacros"
        %sysfunc( ifc(%sysfunc(fileexist(&pdir.pmacros)),  "&pdir.pmacros" , %str( )))  
        ));

/*compile a set of small macros*/
%include "&proot.cmacros\tools.sas";

/*define the coustom defined function path*/
options cmplib = publib.funcs; 

/*define the format search order*/
options fmtsearch= (&pname work library);

/*redirect the default library to project lib folder*/
options user= &pname;

/*merge statement must be accompanied with by statement*/
options mergenoby = error;
/*protect against overwriting the input data sets */
options datastmtchk =corekeywords;

/*X command or statement executes synchronously; 
automatically returns to the SAS session after the specified command is executed*/
options xsync noxwait ;

/*uses threaded processing if available*/
options threads=yes cpucount=&sysncpu;

/*forcing the serious notes to be errors to avoid the invisible errors*/
options dsoptions=note2err;

/*copy the vardefine.csv to data folder. this command would be run once only*/
*X "copy &proot.pub\vardefine.csv &pdir.vardefine.csv";
options source;
