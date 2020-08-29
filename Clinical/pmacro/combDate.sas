*---------------------------------------------------------------*;
* combDate.sas is a SAS macro that creates a SDTM --DTC date
* within a SAS datastep when provided the pieces of the date in 
* separate SAS variables.
*
* MACRO PARAMETERsS:
* dtcdate = SDTM --DTC date variable desired
* year = year variable
* month = month variable 
* day = day variable
* hour = hour variable
* minute = minute variable 
* second = second variable
*---------------------------------------------------------------*; 
%macro combDate(dtcdate=, year=, month=, day=, hour=, minute=, second=); 
    %if %superq(second) ne %then 
        &dtcdate = catx("T", catx("-",&year,&month,&day), 
                                        catx(":",&hour,&minute,&second))%str(;);
    %else %if %superq(minute) ne %then 
        &dtcdate = catx("T", catx("-",&year,&month,&day), 
                                        catx(":",&hour,&minute))%str(;);
    %else %if %superq(hour) ne %then 
        &dtcdate = catx("T", catx("-",&year,&month,&day), &hour)%str(;);
    %else %if %superq(day) ne %then 
        &dtcdate = catx("-",&year,&month,&day)%str(;);
    %else %if %superq(month) ne %then 
        &dtcdate = catx("-",&year,&month)%str(;);
    %else %if %superq(year) ne %then 
        &dtcdate = catx(&year)%str(;);
    %else call missing(&dtcdate)%str(;);
%mend combDate;
