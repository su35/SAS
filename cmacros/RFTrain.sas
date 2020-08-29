/* **************************************************************************************************
** RFTrain.sas: modeling by random forest approach
** tdn: the training dataset
** pdn: the variable description dataset, the default is vars
** treenum: the number of trees, the default is 50 
** treesize: the size of each tree(number of variables), the default is square root of the variables 
** obs: obs for each single tree, the default is 0.6 (60%)
** vlist: specify the variables included in the model. if not assigned then including all variable
** method: the selected method, the default is hpsplit. if any value is assigned, then split.
** pth: the output path, the default is the outfile fold under project fold 
** **************************************************************************************************/
%macro RFTrain(tdn, pdn=vars, treenum=50, treesize=, obs=0.6, vlist=, pth=, method=, criterion=,
    leafsize=, maxbranch=, maxdepth=, exhaustive=, assess=, splitsize=, subtree= );
    %if %superq(tdn)= or %superq(pdn)= %then %do;
        %put ERROR: == The train dataset, parameter dataset, and target variable are required. ==;
        %return;
    %end;
    %if %superq(pth)= %then %do;
        data _null_;
            if fileexist("&pdir.RFRule")=0 then NewDir=dcreate("RFRule","&pdir");
        run;
        %let pth=&pdir.RFRule\;
    %end;
    %if %superq(method)= %then %let method=HPSPLIT;
    %local i j var where;

    %let where=exclude is missing;
    %if %superq(vlist) ^= %then %do;
        %parsevars(&tdn, vlist)
        %strtran(vlist)
        %let where=&where and variable in (&vlist);
    %end;

    /*get the target variable and the level which need in decision tree*/
    proc sql noprint;
        select  variable, %if method=HPSPLIT %then ifc(class="nominal" or class="binary", "nom", "int");
                            %else class;
        into :target, :tlevel
        from &pdn
        where target not is missing;
    quit;

    /*get the variables that would be included in model*/
    proc sort data=vars out=RFVarImportn(keep=variable);
        by variable;
        where &where;
    run;

    /*get the number of variables that a decision tree would included*/
    %if %superq(treesize)= %then %do;
        data _null_;
            set RFVarImportn nobs=obs;
            call symputx("treesize", ceil(sqrt(obs)));
        run;
    %end;


    %do i=1 %to &treenum;
        /*select variables (excluding target variable) randomly for each single tree*/
        proc surveyselect data=&pdn(where=(&where)) 
                out=work.rft_tvar sampsize=&treesize noprint;
        quit;

        /* if the method is hpsplit, then change the class to fit the hpsplit*/
        %if method=HPSPLIT %then %do;
            data work.rft_tvar;
                set work.rft_tvar;
                if class="nominal" or class="binary" then class="nom";
                else class="int";
            run;
        %end;

        proc sql noprint;
            select distinct class, count(distinct class)
            into :classlist separated by ' ', :classn
            from work.rft_tvar;

            select 
                %do j= 1 %to &classn;
                    %let class&j=%scan(&classlist, &j);
                    case when class="&&class&j" then variable else '' end
                    %if &j < &classn %then , ;
                %end;
                into 
                %do j=1 %to &classn;
                    :&&class&j separated by ' '
                    %if &j < &classn %then , ;
                %end;
            from work.rft_tvar;
        quit;

        /*select obs randomly for each single tree*/
        data work.rft_tree;
            set &tdn.;
            x=ranuni(0);
            if x<=&obs;
        run;

        /*create decision tree*/
        ods exclude all;
        %if method=HPSPLIT %then %do;
            proc hpsplit data=work.rft_tree
                %if %superq(maxbranch)^= %then maxbranch=&maxbranch;
                %if %superq(leafsize)^= %then minleafsize=&leafsize;
                %if %superq(maxdepth)^= %then maxdepth= &maxdepth;
                ;
                %if %superq(criterion)^= %then criterion &criterion%str(;);
                code file="&pth.&pname._rule&i..txt";
                %do j=1 %to &classn;
                    %if %superq(&&class&j) ne %then input  &&&&&&class&j/ level=&&class&j%str(;) ;
                %end;
                target &target/level=&tlevel;
                output Importance=work.rft_importance;
            run;

            data work.rft_importance;
                set work.rft_importance;
                where itype="Import";
                drop _criterion_  _obsmiss_ _obsused_  _obsvalid_  _obstmiss_ itype  
                        _treenum_;
            run;

            proc transpose data=work.rft_importance 
                                out=work.rft_importance name=variable;
                var _all_;
            run;
        %end;
        %else %do;
            proc split data=work.rft_tree outleaf=work.rft_leaf  outtree=work.rft_tree
                outimportance=work.rft_importance(keep= name importnc
                    rename=(name=variable importnc=importn&i)) 
                         outmatrix=work.rft_matrix outseq=work.rft_seq 
                %if %superq(criterion)^= %then criterion=&criterion;
                %if %superq(assess)^= %then assess=&assess; 
                %if %superq(maxbranch)^= %then maxbranch=&maxbranch;
                    %else maxbranch=3;
                %if %superq(maxdepth)^= %then maxdepth=&maxdepth;
                %if %superq(exhaustive)^= %then exhaustive=&exhaustive;
                %if %superq(leafsize)^= %then leafsize=&leafsize;
                    %else leafsize=5;
                %if %superq(splitsize)^= %then splitsize=&splitsize;
                %if %superq(subtree)^= %then subtree=&subtree;
                ;
                code file="&pth.&pname._rule&i..txt";
                %do j=1 %to &classn;
                    %if %superq(&&class&j) ne %then 
                            input  &&&&&&class&j/ level=&&class&j%str(;) ;
                %end;
                target &target/level=&tlevel;
            run;
        %end;
        ods select all;

        proc sort data=work.rft_importance%if method=HPSPLIT 
                                    %then(rename=(col1=importn&i)); ;
            by variable;
        run;

        /*combine the importance*/
        data RFVarImportn;
            merge RFVarImportn work.rft_importance;
            by variable;
        run;
    %end;

    data RFVarImportn;
        set RFVarImportn;
        importance=mean(of importn1-importn%eval(&i-1));
        keep variable importance;
    run;

    proc datasets lib=work noprint;
       delete rft_: ;
    run;
    quit;

    %put  NOTE:  ==The macro RFTrain executed completed. ==;
    %put  NOTE:  ==The score files were stored in &pth. ==;
    %put  NOTE:  ==The variable importance stored in RFVarImportn. ==;
%mend;

