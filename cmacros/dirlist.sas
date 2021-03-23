/* ***********************************************************************************************
     Name : dirlist.sas
     Author: Jun Fang  June, 2016
*    --------------------------------------------------------------------------------------------*
     Purpose      : list the all file names in a specific location
*    --------------------------------------------------------------------------------------------*
     Program type   : routine 
     SAS type          : macro
*    --------------------------------------------------------------------------------------------*
     Input    : required: path
                   optional: outdn
     Output : may be a dataset content the file name and extension name
*    --------------------------------------------------------------------------------------------*
     Parameters : path    = the unqouted path to the specific location in where the file 
                                       name would be listed
                         outdn  = the dataset name that store the file name and extension name
*   *********************************************************************************************/
%macro dirlist(path, outdn);
    /*set the defualt value of the required params if the value is null*/
    %if %superq(path)= %then %let path=&pdir.data;
    %if %superq(outdn)= %then %let outdn=_null_;

    filename filelist pipe %tslit(dir "&path" /o:n /b);

    data &outdn;
        /*The max length of the name of a PC file is 255*/
        length fullname $255 %if &outdn ne _null_ %then filename $255 extname $10 ; ;
        infile filelist truncover dlm="|";
        input fullname;
        %if &outdn=_null_ %then put fullname %str(;) ;
        %else %do;
            if index(fullname, ".") then do;
                extname=lowcase(scan(fullname, -1, '.'));
                filename=substr(fullname, 1, length(fullname)-length(extname)-1);
            end;
            else do;
                filename=fullname;
                call missing(extname);
            end;
        %end;
    run;

    %if &outdn ne _null_ %then %do;
        proc sort data=&outdn;
            by extname;
        run;

        title "The &path contents";
        proc print data=&outdn;
        run;
        title;
    %end;

    filename filelist clear;
%mend dirlist;
