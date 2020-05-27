%macro stripe(sdn, tdn); 
 
   %let numobs = 0;               
   %let dsid = %sysfunc(open(&sdn)); 
   %if (&did eq 0) %then  
   %do;  
      %put %sysfunc(sysmsg()); 
      %return; 
   %end; 
   %do;  
      %let numobs = %sysfunc(attrn(&dsid, NLOBS)); 
      %let dsid = %sysfunc(close(&dsid)); 
   %end;
 
   %if (&numobs eq 0) %then %do;
			%put "There is no recode in &sdn";
      %return; 
		%end;
 
   %let numCPU = &sysncpu;    
 
   %let numObsPerSession = %eval(&numobs / &numCPU);  
 
   options sascmd="!sascmd";  
   
   %let firstobs = 1;        
   %let obs = &numObsPerSession; 
 
   %do i = 1 %to &numCPU;   
 
      signon session&i;  
 
      %syslput session = &i / remote = session&i;  
      %syslput firstobs = %str(firstobs = &firstobs) /  
               remote = session&i;   
 
      %if (&i eq &numCPU) %then              
         %syslput obs = %str() / remote = session&i;  
      %else  
         %syslput obs = %str(obs=&obs) / remote = session&i;  
 
      rsubmit session&i wait=no   
                        inheritlib = (work = pwork 
                                      big = big);  
 
         data pwork.subset&session;       
            set big.bigData (&firstobs &obs);  
            newVar = int(ranuni(_n_) * 1000); 
         run; 
 
      endrsubmit; 
 
      %let firstobs = %eval(&firstobs + &numObsPerSession);   
      %let obs = %eval(&obs + &numObsPerSession);  
 
     %end; /* do i - loop through processors/sessions */ 
 
        waitfor _all_        
     %do i = 1 %to &numCPU; 
        session&i 
     %end; 
     ; 
         
   signoff _all_;   
 
   %do i = 2 %to &numCPU;       
      proc append base = subset1 
                  data = subset&i; 
      run; 
   %end; /* do i - loop through processors/sessions */ 
 
%mend stripe; 