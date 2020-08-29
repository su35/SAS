/* *******************************************************************************
* macro CMCompare: compare the confusion matrix created on two datasets
		tdn: dataset created by proc logistic output statement
		vdn: dataset created by proc logistic score statement out option
		pvar: the variable containing the predicted probabilities in tdn
		target: target variable
* *******************************************************************************/
%macro CMCompare(tdn, pvar, vdn, target);
	options nonotes;
	proc sql;
		create table confmat as
		select "train" as name,
			count(*) as total,
			sum(case when &pvar >=0.5 and &target=1 then 1 else 0 end)/calculated total as tp,
			sum(case when &pvar < 0.5 and &target=0 then 1 else 0 end)/calculated total as tn,	
			sum(case when &pvar >= 0.5 and &target=0 then 1 else 0 end)/calculated total as fp,	
			sum(case when &pvar < 0.5 and &target=1 then 1 else 0 end)/calculated total as fn,
			calculated tp + calculated tn as accuracy,
			calculated fp + calculated fn as error_rate,
			calculated tp/(calculated tp +calculated fn)  as sensitivity,
			calculated tn/(calculated tn +calculated fp) as specificity,
			calculated tp/(calculated tp +calculated fp) as pospv,
			calculated tn/(calculated tn +calculated fn) as negpv
		from &tdn;
		insert into confmat
			select "valid" as name,
			count(*) as total,
			sum(case when f_&target="1" and i_&target="1" then 1 else 0 end)/calculated total as tp,
			sum(case when f_&target="0" and i_&target="0" then 1 else 0 end)/calculated total as tn,
			sum(case when f_&target="0" and i_&target="1" then 1 else 0 end)/calculated total as fp,
			sum(case when f_&target="1" and i_&target="0" then 1 else 0 end)/calculated total as fn,
			calculated tp + calculated tn as accuracy,
			calculated fp + calculated fn as error_rate,
			calculated tp/(calculated tp +calculated fn)  as sensitivity,
			calculated tn/(calculated tn +calculated fp) as specificity,
			calculated tp/(calculated tp +calculated fp) as pospv,
			calculated tn/(calculated tn +calculated fn) as negpv
		from &vdn;
	quit;
	data confmat;
		length name $16;	
		set confmat;
		array t(10) _temporary_ (0 0 0 0 0 0 0 0 0 0);
		array v(10) _temporary_ (0 0 0 0 0 0 0 0 0 0);
		if _N_=1 then do;
			t[1]=tp;
			t[2]=tn;
			t[3]=fp;
			t[4]=fn;
			t[5]=accuracy;
			t[6]=error_rate;
			t[7]=sensitivity;
			t[8]=specificity;
			t[9]=pospv;
			t[10]=negpv;
			output;
		end;
		else do;
			v[1]=tp;
			v[2]=tn;
			v[3]=fp;
			v[4]=fn;
			v[5]=accuracy;
			v[6]=error_rate;
			v[7]=sensitivity;
			v[8]=specificity;
			v[9]=pospv;
			v[10]=negpv;
			output;
			name="shirinkage (%)";
			total=.;
			tp=round((t[1]-v[1])/t[1]*100, 0.1);
			tn=round((t[2]-v[2])/t[2]*100, 0.1);
			fp=round((t[3]-v[3])/t[3]*100, 0.1);
			fn=round((t[4]-v[4])/t[4]*100, 0.1);
			accuracy=round((t[5]-v[5])/t[5]*100, 0.1);
			error_rate=round((t[6]-v[6])/t[6]*100, 0.1);
			sensitivity=round((t[7]-v[7])/t[7]*100, 0.1);
			specificity=round((t[8]-v[8])/t[8]*100, 0.1);
			pospv=round((t[9]-v[9])/t[9]*100, 0.1);
			negpv=round((t[10]-v[10])/t[10]*100, 0.1);
			output;
		end;
	run;

	options notes;
	title "confusion matrix comparing";
	proc print noobs;
	run;
	title;
%mend;
