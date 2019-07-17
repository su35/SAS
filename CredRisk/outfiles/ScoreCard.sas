/***** Automatically Generated Scorecard Code*****/

/* Scorecard Scale : 
/*   Odds of [ 1 : 5 ] at  [ 600 ] Points with PDO of [ 20 ] */ 
/********** START OF SCORING DATA STEP *******/

data ;       
	set ; 
/*********************************************/
/***************Base Points********************/
Points=529 ;
/***********  Variable : duration_month     *************/
      IF duration_month LE (8.5) then  Points=Points +(48);
      IF duration_month LE (11.5) then  Points=Points +(7);
      IF duration_month LE (12.5) then  Points=Points +(4);
      IF duration_month LE (15.5) then  Points=Points +(0);
      IF duration_month LE (19) then  Points=Points +(2);
      IF duration_month LE (26.5) then  Points=Points +(-13);
      IF duration_month GT (47.5) then  Points=Points +(-34);
/***********  Variable : Credit_history     *************/
      IF Credit_history in ( "1" "2" ) then  Points=Points +(-21);
      IF Credit_history in ( "4" ) then  Points=Points +(-3);
      IF Credit_history in ( "3" ) then  Points=Points +(-1);
      IF Credit_history in ( "5" ) then  Points=Points +(13);
/***********  Variable : Purpose     *************/
      IF Purpose in ( "5" "10" "11" ) then  Points=Points +(-16);
      IF Purpose in ( "7" ) then  Points=Points +(-15);
      IF Purpose in ( "1" ) then  Points=Points +(-7);
      IF Purpose in ( "3" ) then  Points=Points +(1);
      IF Purpose in ( "4" "6" ) then  Points=Points +(11);
      IF Purpose in ( "2" "9" ) then  Points=Points +(13);
/***********  Variable : checking_account     *************/
      IF checking_account = (1) then  Points=Points +(30);
      IF checking_account = (2) then  Points=Points +(-26);
      IF checking_account = (3) then  Points=Points +(-7);
      IF checking_account = (4) then  Points=Points +(22);
/***********  Variable : employ_status     *************/
      IF employ_status = (1) then  Points=Points +(-7);
      IF employ_status = (2) then  Points=Points +(-13);
      IF employ_status = (3) then  Points=Points +(-1);
      IF employ_status = (4) then  Points=Points +(14);
      IF employ_status = (5) then  Points=Points +(6);
/***********  Variable : residence_time     *************/
      IF residence_time = (1) then  Points=Points +(15);
      IF residence_time = (2) then  Points=Points +(-12);
      IF residence_time = (3) then  Points=Points +(13);
      IF residence_time = (4) then  Points=Points +(0);
run;

/*************END OF SCORING DATA STEP *******/
