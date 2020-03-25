/*get the information of installed component*/
%macro component();
	%let sashome = %sysget(SASHOME);
	data work.sascompt(drop=hotfix order);
		length component $ 64 order $ 32 custver  keyname $ 16 hotfix section $ 8;
		retain component custver section keyname;
		retain key 0;
		drop section keyname key;
		label component = 'COMPONENT';
		infile "C:\Program Files\SASHome\deploymntreg\registry.xml";
		input;

		if index(_infile_,'</Key>') then
			do;
				key+-1;

				if key=4 then output;
			end;
		else if index(_infile_,'<Key ') then
			do;
				key+1;
				keyname = scan(_infile_,2,'"');

				if key=2 then
					section = keyname;
			end;
		else if section = 'INSTALL' then
			do;
				if key=5 then
					do;
						if index(_infile_,'name="order"') then
							do;
								link INNAME;
								order=name;
							end;
						else if index(_infile_,'name="displayname"') then
							do;
								link INNAME;
								component=tranwrd(name,'&amp;','&');
							end;
					end;
				else if key=7 then
					do;
						if index(_infile_,'name="displayname"') then
							if index(_infile_,'data="Hotfix ') then
							do;
								link INNAME;
								hotfix = substr(name,8);
							end;
						else
							do;
								link INNAME;
								custver=name;
							end;
					end;
			end;

		return;
	INNAME:
		length name $ 64;
		drop name;
		inname=index(_infile_,'data="');
		drop inname;
		name=scan(substr(_infile_,inname),2,'"');
		return;
	run;
%mend component;
