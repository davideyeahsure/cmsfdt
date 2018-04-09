function openwindow(link,title,width,height)
{
	window.open(link,title,
	'scrollbars=1,location=0,toolbar=no,menubar=no,status=0,width='+width+
	',height='+height+',resizable=yes');
}

function execlink(link)
{
	window.location=link;
}

function closeandrefresh()
{
	window.close();
	window.opener.location.reload();
}

function askconfirm(text,ifyes)
{
	var answer=confirm(text);
	if( answer) {
		window.location=ifyes;
	}
}

function askyesorno(text,ifyes,ifno)
{
	var answer=confirm(text);
	if( answer) {
		window.location=ifyes;
	} else {
		window.location=ifno;
	}
}
