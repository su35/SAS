/* ***********************************************************************************************
     Name  : setGColor.sas
     Author: Jun Fang 
*    --------------------------------------------------------------------------------------------*
     Purpose: When creating image, the sas applies 12 kind of colors circularly. 
                    If putting several result in one image,  
                    it should be necessary to limit the colors to match the result groupping
*    --------------------------------------------------------------------------------------------*
     Parameters : colors = The list of colors that would be used
*    --------------------------------------------------------------------------------------------*
     Notes: SAS accept natural languages, such as red, black, 
                    and 16 hexadecimal code (with prefix cx or #)
*   *********************************************************************************************/
%macro SetGcolor(colors,backgroud=cx000);
    %local i cnum rep;
    %let cnum=%sysfunc(countw(&colors));
    %let rep=%eval(%sysfunc(floor(12/&cnum))-1);
   
    proc template;
        define style style.gchangecolor;
            parent=Styles.Default;
            style graphcolors from graphcolors / 
            %do i=1 %to &cnum;
                %let color =%scan(&colors, &i);
                "gcdata&i"=&color
                %do j=1 %to &rep;
                    "gcdata%eval(&i+&cnum*&j)"= &color
                %end;
            %end;
            ;
            class color_list / "bgA" = &backgroud;
        end;
    run;
%mend SetGcolor ;

