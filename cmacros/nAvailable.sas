/* ***********************************************************************************************
     Name: nAvailable.sas
     Author: Jun Fang   Feb. 22, 2021
*    --------------------------------------------------------------------------------------------*
     Description : Since some SAS system autocall macros are called by internal process, 
                        if the name of those macros collide with name of customer defined macros, 
                        may case a unexpected result. So, when defining a macro program, 
                        it is need to check if the name is conflicting.
                        The names of the system autocall macros have been stored in 
                        publib.sysautomacros dataset by macro listautomacros
*    --------------------------------------------------------------------------------------------*
     program type   : routine
     SAS type          : macro
*    --------------------------------------------------------------------------------------------*
     input    : required: name
     output : from MacroName
*    --------------------------------------------------------------------------------------------*
     Parameters : name = a name string
*   *********************************************************************************************/
%macro nAvailable(nstring);
    %let dsid=%sysfunc(open(publib.sysautomacros(
                                            where=(upcase(macName)=upcase("&nstring")))));
    %let rc=%sysfunc(fetch(&dsid));
    %if &rc eq -1 %then %put NOTE- == The name "&nstring" is available ==;
    %else %if &rc eq 0 %then %put ERROR- == The name "&nstring" has been taken ==;
    %else %put ERROR- == A unexecpted result ==;
    %let rc=%sysfunc(close(&dsid));
%mend nAvailable;

