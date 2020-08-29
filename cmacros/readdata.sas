/* ****************************************************************************
 * macro ReadData.sas: read the data stored in local external files
 * option minoperator: make the in() operator is available in macro, 
 * parameters 
 *      path: the folder where the data is stored. default is the data folder.
 *      lib: the library where the dataset would be stored.default is ori.
 *      ext: specify the file type(extension name) in which the data would be input.
 *          default is empty which means all types.
 *      file: specify the file name (with extension name) in which the data would be input.
*           default is empty which means all file.
*       delm: specify the delimiter for dlm type files. value with quote.
* Since some punctuations are legal char in PC file name/ excel sheet name/access table name,
* using of libref + proc copy or data step or others may case illegal dataset name problem
 * *****************************************************************************************************/
%macro ReadData(path=&pdir.data, lib=ori, ext=, file=, delm= ) /minoperator;
    %local filrf rc pid  i j  filenum expnum relnum typelist txtfile hastxt
                fullnamelist typelist namelist fullname type name suff ;
    %let typelist="sas7bdat" "xpt" "xls" "xlsb" "xlsm" "xlsx" "mdb" "accdb";
    %let txtfile="txt" "csv" "dat" "data" "asc";
    /*read the name of all files*/
    %let rc=%sysfunc(filename(filrf,&path));
    %let pid=%sysfunc(dopen(&filrf));
    %if &pid eq 0 %then
        %do;
            %put Directory &path cannot be open or does not exist;
            %return;
        %end;
    %else 
        %do; 
            %let expnum=%sysfunc(dnum(&pid));
            data work.rd_rawfiles;
                length fullname filename $255 extname type $10 ;
                %do i=1 %to &expnum;
                    fullname="%qsysfunc(dread(&pid, &i))";
                    extname="%scan(%qsysfunc(dread(&pid, &i)),-1,.)";
                    if fullname ne extname then 
                        do; 
                            filename=substr(fullname, 1, length(fullname)-length(extname)-1);
                            if lowcase(extname) not in (&typelist &txtfile) then 
                                put "WARNING: A new extion name was found. File name is " fullname;
                        end;
                    else do;
                        call missing(extname);
                        filename=fullname;
                    end;
                    select (lowcase(extname));
/*                        when ("txt", " ") type="tab";*/
                        when ("dat", "data", "asc", "txt", " ") type="dlm";
                        otherwise type=lowcase(extname);
                    end;
                    output;
                %end;
                stop;
            run;
        %end;

    /*filter the files basing on &ext and &files*/
    %if %superq(ext) ne or %superq(file) ne %then
        %do;
            data work.rd_rawfiles;
                set work.rd_rawfiles;
                %if %superq(file) ne %then
                    %do;
                        %let file=%upcase(&file);
                        %if %superq(ext) = %then
                            if upcase(filename) = %upcase("&file") or upcase(fullname) = %upcase("&file") 
                                        then output%str(;) ;
                        %else
                            %do;
                                %let ext=%upcase(&ext);
                                %strtran(ext)
                                if upcase(extname) in (&ext)  and 
                                        (upcase(filename) = %upcase("&file") or upcase(fullname) = %upcase("&file")) 
                                        then output;
                            %end;
                    %end;
                %else
                    %do;
                        %let ext=%upcase(&ext);
                        %strtran(ext)
                        if upcase(extname) in (&ext) then output;
                    %end;
            run;
        %end;

        data work.rd_rawfiles;
            length temp temp2 $255;
            set work.rd_rawfiles end=eof;
           /*transform the illegal charactor to single _*/
           filename=prxchange("s/[^a-z_0-9]/_/i", -1, trim(filename));
           filename=prxchange("s/[_]+/_/i", -1, filename);

           if length(filename) >32 then
                do;
                    i=1;
                    do until(missing(temp));
                        temp=scan(filename, i, "_");
                        temp2=cats(temp2, propcase(temp));
                        i=i+1;
                    end;
                        if length(temp2) >32 then
                            do;
                                filename=substr(temp2, 1 , 32);
                                put "WARNING- The length of the file " fullname " is over 32 and has been truncated to " filename;
                            end;
                        else
                            do;
                                filename=temp2;
                                put "WARNING- The length of the file " fullname " is over 32.  The character '_' has been removed";
                            end;
                end;
            if extname in (&txtfile) then call symputx("hastxt", 1);
            drop temp temp2 i;
            call symputx(cats('rd_fullname', _N_), fullname);
            call symputx(cats('rd_name', _N_), filename);
            call symputx(cats('rd_type', _N_), type);
            if eof then call symputx("filenum", _N_);
        run;
        %let expnum=&filenum;

        %do i=1 %to &filenum;
            %readfile(&&rd_fullname&i, &&rd_name&i, &&rd_type&i);
        %end;

         %if %superq(ext)= and %superq(file) = %then /*read all files condition*/
            %do;
                %LibInfor(&lib)

                proc sql noprint;
                    select count(distinct memname)
                    into :relnum
                    from work.temp; /*the set temp was created by %MetaShort()*/
                quit;

/*                %if &expnum=&relnum %then*/
/*                    %put NOTE: == Total &relnum datasets were created ==;*/
/*                %else*/
/*                    %put WARNING: Total &relnum datasets were created. It is not match with the expect dataset number &expnum;*/
            %end;

        proc datasets lib=work noprint;
           delete re_: temp;
        run;
        quit;

        %put NOTE: == Row data have been read to library &lib ==;
        %if %superq(hastxt) ne  %then
            %put WARNING: There are some text type files inputed. The re-output text files have been exported in outfiles folder for validation;
        %put NOTE: == Macro ReadData runing completed. ==;
%mend ReadData;

%macro readfile(fullname, name, type) /minoperator;
   %local i;
   %if &type in (csv tab dlm) %then
      %do;
           proc import datafile = "&path\&fullname"
                                  out=&lib..&name
                                  dbms=&type
                                  replace;
              getnames=yes;
              guessingrows=max;
              /*a large number will take some time, but it is faster than semi-automatic;*/
              %if &type=dlm %then  %do;
                    %if %superq(delm) ne  %then  delimiter=&delm%str(;) ;
                    %else delimiter=" "%str(;) ;
                %end;
           run;

           proc export data=&lib..&name
                                outfile="&pout\&fullname"
                                dbms=&type
                                replace;
              %if &type=dlm %then  %do;
                    %if %superq(delm) ne  %then  delimiter=&delm%str(;) ;
                    %else delimiter=" "%str(;) ;
                %end;
            run; 
      %end;
    %else %if &type eq sas7bdat %then
        %do;
            libname templb "&path";
            proc datasets noprint;
                copy in=templb out=ori memtype=data;
                select &name;
            run;
            quit;
            libname templb clear;
        %end;
    %else %if &type eq xpt %then
        %do;
            libname templb XPORT "&path\&fullname";
            proc copy in=templb out=ori memtype=data;
            run;
            libname templb clear;
        %end;
   %else %if &type in (xls xlsb xlsm xlsx) %then
      %do;
         libname templb excel "&path\&fullname";

         /*using the p modifier in compress() to remove the punctuation
         *  if the sheets name include invalid char, the set name will be quoted*/
         proc sql noprint;
            select prxchange("s/[_]+/_/i", -1, prxchange("s/[^a-z_0-9]/_/i", -1, 
                    prxchange("s/['\$]//i", -1, trim(memname)))) as setname, 
               case when substr(memname, 1,1)= "'" then memname 
                  else quote(trim(memname)) end as sheetname 
            into :setname1-, :sheetname1-
            from sashelp.vtable
            where libname= "TEMPLB" and memname not contains "FilterDatabase";
            %let num=&sqlobs;
         quit;
 
        %let expnum=%eval(&expnum+&num-1);
         %do i=1 %to &num;
            /*if there is a same name of dataset, then rename */
            %if %sysfunc(exist(&lib..&&setname&i))=1 %then %do;
               %if %length(&&setname&i)>29 %then %truncName(setname&i, 29);
               %let suff=%substr(&fullname, 1,3);
               %let setname&i=&suff._&&setname&i;
               %put WARNING: &&sheetname&i in &fullname was renamed to &&setname&i;
            %end;

            data &lib..&&setname&i;
                set templb.&&sheetname&i..n; /*sheetname has been quoted*/
            run;
         %end;

         libname templb clear;
      %end;
   %else  %if &type in (mdb accdb) %then
      %do;
         libname templb access "&path\&fullname";

         proc sql noprint;
            select prxchange("s/[_]+/_/i", -1, prxchange("s/[^a-z_0-9]/_/i", -1, 
                    trim(memname)))  , quote(strip(memname))
            into :setname1-, :tname1-
            from dictionary.tables
               where  libname= "TEMPLB";
            %let num=&sqlobs;
         quit;

        %let expnum=%eval(&expnum+&num-1);

         %do i=1 %to &num;
            /*The table name could be 64 char in access*/
            %if %length(&&setname&i) > 32 %then %truncName(setname&i);
            %if %sysfunc(exist(&lib..&&setname&i))=1 %then %do;
               %if %length(&&setname&i)>29 %then %truncName(setname&i, 29);
               %let suff=%substr(&fullname, 1,3);
               %let setname&i=&suff._&&setname&i;
               %put WARNING: &&tname&i in &fullname was renamed to &&setname&i;
            %end;

            data &lib..&&setname&i;
                set templb.&&tname&i..n; /*sheetname has been quoted*/
            run;
         %end;

         libname templb clear %str(;);
      %end;
%mend readfile;

