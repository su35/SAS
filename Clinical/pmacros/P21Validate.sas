/* ***********************************************************************************************************
     Name  : P21Validate.sas
     Author: Jun Fang
                 Modified from Chris Holland and Jack Shostak's code
*    ---------------------------------------------------------------------------------------------------------*
     Purpose: Run the Pinnacle 21 Community validator in batch mode;
*    ---------------------------------------------------------------------------------------------------------*
     Parameters : 
        type             = The standard being validated (SDTM, ADaM, Define, SEND, or Custom)
        sources        = Path of the directory that contains the SAS datasets or define file
        ctdatadate   = Specify the version of the controlled terminology XML file used to check 
                                against.  Since the file locations and names are standardized, all that is 
                                needed is the date in yyyy-mm-dd format. There are many different 
                                versions from which to choose and these are updated frequently.  Refer 
                                to your P21 software and/or the COMPONENTS\CONFIG\DATA\CDISC 
                                directory for CDISC controlled terminology.  
        p21path       = Path of the local OpenCDISC validator installation (D:\SAS\pinnacle21-community)
        validatorjar   = Subdirectory and name of the JAR file. (\components\lib\validator-cli-2.1.5.jar)
        files              = Defaults to all .xpt files in the directory. Alternatively, one specific file could 
                                be specified or a wildcard could be used on a partial name (e.g. LB*.xpt)*.xpt,
        reportfname = Name of the output Excel file that contains the validation report.  
                                Can be left blank to have automated naming occur.
        config           = Subdirectory and name of the configuration file to be used for validation.  
                                Should correspond to one of the files in the CONFIG sub-directory.
        define           = Choose Y, y, or 1 if a DEFINE.XML file exists (in the same directory as 
                                the data sets) for cross-validation.  Do NOT choose DEFINE=Y/y/1 
                                if wishing to validate a define file.Y,
        make_bat      = N. Specify Y if a .BAT file is desired.  The .BAT file can be submitted/typed 
                                at a command prompt (without the .BAT extension) to initiate the process 
                                of having a validation report generated (without having to resubmit this macro) 
*   **********************************************************************************************************/
%macro P21Validate(type= ,
                sources= ,
                ctdatadate= ,
                p21path=D:\SAS\pinnacle21-community,
                validatorjar=\components\lib\validator-cli-2.1.5.jar,
                files=*.xpt,
                reportfname= ,
                config= ,
                define=Y,
                make_bat=N
                );
                     
        ** set the appropriate system options;
       options xsync noxwait ;
                             
        ** specify the output report path;
        %let reportpath=&sources;                                                            
        
        ** ensure proper capitalization in case of case sensitivity;
        %if %upcase(&type)=ADAM %then
          %let type=ADaM;
          
        ** specify the name(s) of the validation reports; 
        %if %superq(reportfname) ne  %then
          %let reportfile=&reportfname;
        %else %if %upcase(&type)=SDTM %then
          %let reportfile=sdtm-validation-report-&sysdate.T%sysfunc(tranwrd(&systime,:,-)).xlsx;
        %else %if %upcase(&type)=ADAM %then
          %let reportfile=adam-validation-report-&sysdate.T%sysfunc(tranwrd(&systime,:,-)).xlsx;
        %else
          %let reportfile=p21-community-validation-report-&sysdate.T%sysfunc(tranwrd(&systime,:,-)).xlsx;
        ;
        
        ** specify the name(s) of the configuration file (if missing);
        ** (note that the names of the configuration files can change with new CDISC 
        ** IGs and software releases so maintenance of this is required!!); 
        %if %superq(config) = %then
          %do;
            %let configpath=&p21path\components\config;
            %if %upcase(&type)=SDTM %then
              %let config=&configpath\SDTM 3.2.xml;
            %else %if %upcase(&type)=ADAM %then
              %let config=&configpath\ADaM 1.0.xml;
            %else %if %upcase(&type)=DEFINE %then
              %do;
                %let config=&configpath\Define.xml.xml;
                %** ensure that [&]DEFINE=N in this case;
                %let define=N;
              %end;
          %end;
          
        %** cross-check against a define file?  if so, assume it exists in the same directory and is 
        %** named simply define.xml ;
        %** if validating a define, then use [&]files as the define file name;
        %if %upcase(&type)=DEFINE %then
          %let config_define=%str(-config:define="&sources\&files");
        %else %if %upcase(&define)=Y or &define=1 %then
          %let config_define=%str(-config:define="&sources\define.xml");
        %else
          %let config_define= ;
        ;
        
        %** if ctdatadate is non-missing, then check controlled terminology against the corresponding file;
        %if %superq(ctdatadate) ne  %then
          %do;
            %let ctdata=&p21path\components\config\data\CDISC\&type\&ctdatadate\&type Terminology.odm.xml;
            %let config_codelists=%str(-config:codelists="&ctdata");
          %end;
        %else
          %let config_codelists= ;
        ;
        
        %put submitting this command: ;
        %put java -jar "&p21path\&validatorjar" -type=&type -source="&sources\&files" -config="&config" 
             &config_codelists &config_define -report="&reportpath\&reportfile" -report:overwrite="yes" ;
          
        /* run the report;*/
        x java -jar "&p21path\&validatorjar" -type=&type -source="&sources\&files" -config="&config" 
          &config_codelists &config_define -report="&reportpath\&reportfile" -report:overwrite="yes" ; *> &sources\run_p21v_log.txt;

        %if &make_bat=Y %then
          %do;
            /*send the command to a bat file;*/
            data _null_;
                file "&sources\submit_p21_&type._job.bat" ;
                put 'java -jar "' "&p21path\&validatorjar" '"' " -type=&type -source=" '"' "&sources\&files" '" -config="' "&config" '"' 
                    " %bquote(&config_codelists) %bquote(&config_define) -report=" '"' "&reportpath\&reportfile" '"' ' -report:overwrite="yes" ';
            run;
          %end;
    x "&path\&reportfile";

    %put  NOTE:  ==The validation report was stored in &reportpath\&reportfile.==;
    %put  NOTE:  ==The macro P21Validate executed completed. ==;

%mend P21Validate;
