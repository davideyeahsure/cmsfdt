#!/usr/bin/perl

use strict;
use DBI;
use CGI qw/:standard/;
use CGI::Cookie;
#use Shell qw(dig);
use Config::General;
use Date::Format;
use Date::Parse;
use URI::Find;
use Mail::SpamAssassin;

require './cmsfdtcommon.pl';

my $myself=script_name();
my $query= new CGI();
my $clientip=$query->remote_host();
my $today=time2str("%Y-%m-%d",time);
my $dbh=dbconnect("./cms50.conf");

my $emoticonsdir=getconfparam('emoticonsdir',$dbh);
my $debug=getconfparam('debug',$dbh);

# Get parameters from the query
my $realname=$query->param('realname');
my $username=$query->param('username');
my $age=$query->param('age');
my $type=$query->param('type');
my $contact=$query->param('contact');
my $location=$query->param('location');
my $why=$query->param('why');
my $comment=$query->param('comment');
my $mode=$query->param('mode');

# initialize page
print $query->header(
	-type=>'text/html',
	-expires=>'0m',
	-status=>'200 OK',
	-charset=>'iso-8859-15'
);

# start page
print "<!doctype html public \"-//W3C//DTD HTML 4.01 Transitional//EN\"";
print "\"http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd\">\n";
print "<html>\n";
print "<!-- this document was produced with the (in)famous Cms FDT v. 5.0 -->\n";
print "<!-- by D.Bianchi (c) 2008-averyfarawaydate -->\n";
print "<!-- see http://www.soft-land.org/ -->\n";
print "<head>\n";
print "<title>Registration request</title>\n";
print "<meta http-equiv='Content-type' content='text/html;charset=iso-8859-15' />\n";
print '<meta name="google-site-verification" content="r33YyzPGlgNzbUz6eNHHsApaDLICEOgZ3vl2GRugvZU" />'."\n";
print "</head>\n";
print "<body>\n";

# do the insert?
if($mode eq 'add') {

	my $res;

	# check if the userid already exsists in the system
	my $q='select count(userid) from registrationrequests where userid=?';

	my $sth=$dbh->prepare($q);
	$sth->execute($username);
	my ($exist)=$sth->fetchrow_array();
	if( $exist > 0 ) {
		# sorry, already there!
		print "<h3>Username already present!</h3>\n";
		print "It appears that somebody already registered with that username, if that is YOUR username, maybe you already\n";
		print "registered, if so, you either are already playing with us or not... if this is an error,  please drop us a\n";
		print "<a href='mailto:pickaxe04mc\@gmail.com'>mail</a>. Thanks.</p>\n";
	} else {

		# ok, I can add it.
		$q='insert into registrationrequests (realname,username,age,type,contact,location,why,comment) values (?,?,?,?,?,?,?,?)';
		$sth=$dbh->prepare($q);
		$res=$sth->execute( $realname, $username, $age, $type, $contact, $location, $why, $comment);

		if( ! $res ) {
			print "<script>\n";
			print "window.alert(\"";
			print "Error during the insertion! Something went wrong!";
			print "\");\n";
			print "window.opener.location.reload();\n";
			print "window.close();\n";
			print "</script>\n";
		} else {
			print "<script>\n";
			print "window.alert(\"";
			print "We have received your request and we'll review it as soon as possible.";
			print "\");\n";
			print "window.opener.location.reload();\n";
			print "window.close();\n";
			print "</script>\n";
		}
	}

	print "</body></html>\n";
	exit;

} else {

	# show the input form
	print "<h3>Fill in the form</h3>\n";
	print "<hr>\n";
	print "<form method='post' action='".$myself."' name='addpost'>\n";
	print "<input type='hidden' name='mode' value='add'>\n";
	print "<table width='100%' border='0' cellspacing='0' ";
	print "cellpadding='3px' bgcolor='lightgrey'>\n";
	print "<tr>\n";
	print "<td>Real name:</td>\n";
	print "<td>\n";
	print "<input type='text' name='realname' size='50' value='";
	print $realname;
	print "'>\n";
	print "</td></tr>\n";
	print "<tr>\n";

	print "<tr>\n";
	print "<td>In-game name:</td>\n";
	print "<td>\n";
	print "<input type='text' name='username' size='50' value='";
	print $username;
	print "'>\n";
	print "</td></tr>\n";
	print "<tr>\n";

	print "<tr>\n";
	print "<td>Age:</td>\n";
	print "<td>\n";
	print "<input type='text' name='age' size='4' value='";
	print $age;
	print "'>\n";
	print "</td></tr>\n";
	print "<tr>\n";

	print "<tr>\n";
	print "<td>Location:</td>\n";
	print "<td>\n";
	print "<input type='text' name='location' size='50' value='";
	print $age;
	print "'>\n";
	print "</td></tr>\n";
	print "<tr>\n";

	print "<tr>\n";
	print "<td>E-mail or skype handler:<br><i>Is it ok if you don't have skype, but we need a way to contact you<\i></td>\n";
	print "<td>\n";
	print "<input type='text' name='contact' size='50' value='";
	print $age;
	print "'>\n";
	print "</td></tr>\n";
	print "<tr>\n";

	print "<tr>\n";
	print "<td>Type of player:</td>\n";
	print "<td>\n";
	print "<input type='text' name='type' size='80' value='";
	print $type;
	print "'>\n";
	print "</td></tr>\n";
	print "<tr>\n";

	print "<tr>\n";
	print "<td>Why do you want to join?</td>\n";
	print "<td>\n";
	print "<textarea name='why' cols='100%' rows='10'>\n";
	print $why;
	print "</textarea>\n";
	print "</td></tr>\n";
	print "<tr>\n";

	print "<tr valign=top>";
	print "<td>Comment:</td>";
	print "<td>\n";
	print "<textarea name='comment' cols='100%' rows='10'>\n";
	print "</textarea>\n";

	# start the editor
	print "<script type='text/javascript'>\n";
	print "CKEDITOR.on( 'instanceReady', function(ev)\n";
	print "{ev.editor.dataProcessor.writer.setRules('p',{indent: false, breakBeforeOpen: false, breakAfterOpen: false,";
	print "breakBeforeClose: false, breakAfterClose:false});\n";
	print "})\n";
	print "CKEDITOR.replace('comment',\n";
	print "{ toolbar: [['Bold','Italic','Underline','Smiley']], startupMode: 'wysiwyg', width: '90%', ";
	print "height:'200',";
	print "keystrokes: [[ CKEDITOR.CTRL+66, 'bold' ],[ CKEDITOR.CTRL+73, 'italic' ],[ CKEDITOR.CTRL+85, 'underline' ],[CKEDITOR.CTRL+83,'smiley']";
	print "]});\n";
	print "</script>\n";
	print "</td>\n";
	print "</tr>\n";
	print "<tr height='20pt'>\n";
	print "<td> &nbsp; </td>\n";
	print "<td align='left'>\n";
	print "<input type='submit' name='ok' value='Ok'>";
	print "<input type='button' name='cancel' value='Cancel' onclick='javascript:window.close()'>";
	print "</td>\n";
	print "</tr>\n";
	print "</table>\n";
	print "</form>\n";
}

# end page
print "</body>\n";
print "</html>\n";
exit;
