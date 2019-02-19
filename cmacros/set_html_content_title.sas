%macro set_html_content_title(text);
Proc template; 
	define
		style styles.customhtml; 
		parent=styles.htmlblue; 
		style contenttitle  from contenttitle/ 
		pretext = text("&text");  
	end; 
run; 
%mend set_html_content_title; 
