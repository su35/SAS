/* ***********************************************************************************************
     Name  : sas2txt.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: Batch transform the SAS program to text file.
*    --------------------------------------------------------------------------------------------*
     Parameters : inpath           = the path to which the SAS program needs to be transformed.
                         all                 = whether include the SAS program in subfold.
                         outencoding = encoding of plain text file after transformation.
*   *********************************************************************************************/
%macro sas2txt(inpath, all, outencoding);
    %local _pipfg fold rc;

    %if %superq(inpath)= %then %let inpath=&pdir;
    %else %if %index(%sysfunc(reverse(&inpath)),\) ne 1 %then %let inpath=&inpath.\;
    %if %superq(all)= or &all >0  %then %let _pipfg=/b/s;
    %else %let _pipfg=/b;
    %if %superq(outencoding)= %then %let outencoding=utf8;

    %let fold=%sysfunc(cats(txtcode, %sysfunc(compress(%sysfunc(putn("&sysdate"d, yymmdd10.)), "-"))));
    %if not %sysfunc(fileexist(&inpath.&fold)) %then %let rc=%sysfunc(dcreate(&fold,&inpath));

	filename _pipfile pipe %tslit(dir "&inpath.*.sas" &_pipfg);

	data _pipfile;
		infile _pipfile truncover;
		input fname $char256.;

        /*filter out other type files that the extension name include sas, such as sas7bdat*/
        if length(kscan(fname,-1,'.'))=3 then do;
            /*if &all=0 then the fname doesn't include the path*/
            %if &all=0  %then %do;
                fname=cats("&inpath", fname);
            %end;
            rc=filename("infold", quote(strip(fname)), , "encoding=any  lrecl=30000");

            txtfile=cats("&inpath.&fold\",kscan(fname,-1,'\'), '.txt');
            rc=filename('outfold', quote(strip(txtfile)), ,"lrecl=30000 encoding=utf8;");

            rc=fcopy("infold", "outfold");
        end;
    run;

    filename infold clear;
    filename outfold clear;

    %put  NOTE:  ==The text code files were stored in &inpath.&fold.==;
    %put  NOTE:  ==The macro sas2txt executed completed. ==;
%mend sas2txt;
