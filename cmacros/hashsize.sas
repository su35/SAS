/* hashsize.sas */

options fullstimer msglevel=i nosource;

/* beginning of macro definition */
%macro hash_test /parmbuff ;
  %let parmlst = %upcase(&syspbuff);
   /* %put Syspbuff contains: &parmlst; */
   %let i=1;
   %let parmpair=%scan(&parmlst,&i);
   %do %while(&parmpair ne );
      %put &parmpair;
      %let kw = %scan(&parmpair,1,'=');
      %let val = %scan(&parmpair,2,'=');
      %let &kw = &val;
      %let i=%eval(&i+1);
      %let parmpair=%scan(&parmlst,&i);
   %end;
/* validate parameters */
  %let err = 0;
  %if %symexist(KEYCNT)  %then %do; 
    %do i = 1 %to &keycnt;
      %if not(%symexist(K&i.LEN)) %then %do;
        %put ERROR: K&i.Len not defined;
        %let err = 1;
      %end;
      %if %symexist(K&i.TYP) %then %do;
        %if &&&K&i.TYP = C  %then
          %let K&i.TYP = $;
        %else %if  &&&K&i.TYP = N %then
          %let K&i.TYP =  ;
      %end;
      %else %do;
        %put ERROR: K&i.Typ not defined;
        %let err = 1;
      %end;
    %end;
  %end;
  %else %do;
    %put ERROR: Hash table KEY not defined;
    %let err = 1;;
  %end;
  %if %symexist(DATACNT)  %then %do; 
    %do i = 1 %to &datacnt;
      %if not(%symexist(D&i.LEN)) %then %do;
        %put ERROR: D&i.Len not defined;
        %let err = 1;
      %end;
      %if %symexist(D&i.TYP) %then %do;
        %if &&&D&i.TYP = C  %then
          %let D&i.TYP = $; 
        %else %if &&&D&i.TYP = N %then
          %let D&i.TYP =  ; 
      %end;
      %else %do;
        %put ERROR: D&i.Typ not defined;
        %let err = 1;
      %end;
    %end;
  %end;
  %else %do;
    %put ERROR: Hash table DATA not defined;
    %let err = 1;;
  %end;
  %if  not(%symexist(ROWS)) %then %do;
    %put ERROR: Hash table ROWS not defined;
    %let err = 1;;
  %end;
  %if &err = 1 %then %return;
/* continue with valid parameters */
  %PUT NOTE: Valid parameters:;
  /* %put  _user_; */

data hashtable(drop=i) ;
length 
%do i = 1 %to &keycnt;
  k&i &&&k&i.typ&&&k&i.len /* no semi-colon */ 
%end;
%do i = 1 %to &datacnt;
  d&i  &&&d&i.typ&&&d&i.len /* no semi-colon */
%end;
;
do i=1 to &rows. ;
%do i = 1 %to &keycnt;
  %if &&&k&i.typ = $ %then %do;
    k&i = put(i,best.) ; 
  %end;
  %else %do;
    k&i = i;
  %end;
%end;
%do i = 1 %to &datacnt;
  %if &&&d&i.typ = $ %then %do;
    d&i = put(i,best.) ; 
  %end;
  %else %do;
    d&i = i;
  %end;
%end;
  output ;
end ;
run ;
%put ; %put XMLRMEM available = %sysfunc(inputn(%sysfunc(getoption(xmrlmem)),28.),comma28.) ; 
      data _NULL_;
	  length firstmem lastmem 8  /* no semi-colon here */
%do i = 1 %to &keycnt;
  k&i &&&k&i.typ&&&k&i.len /* no semi-colon */ 
%end;
%do i = 1 %to &datacnt;
  d&i  &&&d&i.typ&&&d&i.len /* no semi-colon */
%end;
;
firstmem = input(getoption('xmrlmem'),20.);

if _N_ = 1 then do;
    hexp =  int(log2(&rows)) +1;
   declare hash h(dataset: "hashtable",hashexp:hexp) ;
   rc = h.defineKey(    /* no semi-colon */
%do i = 1 %to &keycnt;
  %if &i gt 1 %then %str(,);
  "k&i"  /* no semi-colon */ 
%end;
) ;
            rc = h.defineData(
%do i = 1 %to &datacnt;
  %if &i gt 1 %then %str(,);
  "d&i"   /* no semi-colon */
%end;
) ;  
  rc = h.defineDone() ;
  call missing(
%do i = 1 %to &keycnt;
  %if &i gt 1 %then %str(,);
  k&i  /* no semi-colon */ 
%end;
%do i = 1 %to &datacnt;
  , d&i   /* no semi-colon */
%end;
);
end ;
      lastmem = input(getoption('xmrlmem'),20.);
      Hash_Size = h.item_size * &rows ;  /* sas 9.2 */
      Hash_Size_row = h.item_size ;  /* sas 9.2 */
      put 'Actual table size:' hash_size comma30. ' bytes' /
          'Row          size:' hash_size_row comma30. ' bytes' /
          'Optimal   HASHEXP:' hexp comma30. /
;
%mend;
/* end of macro definition */

 options nomprint nosymbolgen nomlogic nonotes source;

/* remove the asterisk in front of the macro call you want to run */

/* 3K rows, 1 key variable, $4, 2 data variables, 1 numeric, 1 $10 */
%hash_test (rows=3000,keycnt=1,datacnt=2,
            K1LEN=4,K1TYP=C,
            d1len=8,d1typ=n,d2len=10,d2typ=c); run;
/* 30K rows, 3 key variables, numeric, no data variables */
%hash_test(rows=30000,keycnt=3,
           k1len=8,k1typ=n,
           k2len=8,k2typ=n,
           k3len=8,k3typ=n,
           datacnt=0
           ) ; run;
/* 30K rows, 3 key variables, numeric, 1 data variable, $1 */
%hash_test(rows=30000,keycnt=3,
           k1len=8,k1typ=n,
           k2len=8,k2typ=n,
           k3len=8,k3typ=n,
           datacnt=1,d1len=1,d1typ=c
           ) ; run;
/* 5K rows, 1 key variable, numeric, 1 data variable, $84 */
%hash_test(rows=5000,keycnt=1,
           k1len=8,k1typ=n,
           datacnt=1,d1len=84,d1typ=c
           ) ; run;