$(document).ready(function(){
/*	$("tr:first-child:not(:contains('#160;'))").children().addClass("bold");*/
	$("td:contains('&#160;')").addClass("ind").html(function(){
		var cont = $(this).html();
		cont=cont.replace('&amp;#160;',"");
		return cont;
	});
});
