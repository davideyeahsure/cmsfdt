#!/usr/bin/perl

use strict;
use DBI;
use CGI qw/:standard/;
use CGI::Cookie;
use Config::General;
use Date::Format;
use Date::Parse;
use URI::Find;
use Mail::SpamAssassin;

require 'cmsfdtcommon.pl';

my $myself=script_name();
my $query= new CGI();
my $clientip=$query->remote_host();
my $today=time2str("%Y-%m-%d",time);
my $dbh=dbconnect("./cms50.conf");

my $emoticonsdir=getconfparam('emoticonsdir',$dbh);
my $debug=getconfparam('debug',$dbh);

# Get parameters from the query
my $subject='';
my $hostid=$query->param('hostid');
my $groupid=$query->param('groupid');
my $documentid=$query->param('documentid');
my $commentid=$query->param('commentid');
my $parentid=$query->param('parentid');
my $mode=$query->param('mode');
my $username=$query->param('username');
my $comment=$query->param('comment');
my $spamscore='';

my $approved;

# userid, name and icon
my $userid;
my $user;
my $icon;
my $isroot;
my $sth;

# get the info about the user
($userid,$user,$icon,$isroot) = getloggedinuser($dbh);

# if the user isn't logged in, check if the 'anonymous' user does exists
if( $userid eq 'NONE' ) {

	my $q="select count(*) from users where email like 'anonymous%'";
	my $r=$dbh->prepare($q);
	$r->execute();
	my ($c)=$r->fetchrow_array();
	if( $c == 0 ) {
		print "<script>\n";
		print "window.alert(\"";
		print "Sorry, posting anonymously is not possible in this system. You'll have to login.";
		print "\");\n";
		print "window.close();\n";
		print "</script>\n";
	}

}

# show the header.
printheader($dbh);

# If the user hasn't logged in, he can post but warn him.
if($userid eq 'NONE' && $mode eq '') {

	print "<div class='warning'>\n";
	print "<b>Warning!</b>:\n";
	print "You are posting as 'Anonymous'. \n";
	print "If you want to post more than once, maybe is better if you ";
	print "login or register.</div>\n";

	$userid='anonymous@localhost';
	$user='';
	$username='Anonymous coward';
	$icon='user.png';
	$isroot=0;	# definitively NOT ROOT.

}

if($userid eq 'NONE' ) {
	$userid='anonymous@localhost';
}

if( $user eq '' ) {
	$username='Anonymous coward';
}

if( $userid ne 'NONE' && $userid ne 'anonymous@localhost' && $username eq '') {
	$username=$user;
}

# get the info about the current document
my $q=(q{
	select 
	dc.title as title, d.author as author, d.moderator as moderator, d.comments as comments, d.moderated as moderated
	from
	documents d, documentscontent dc 
	where
	d.hostid=dc.hostid and d.groupid=dc.groupid and d.documentid=dc.documentid and
	d.hostid=? and d.groupid=? and d.documentid=?
	});

$sth=$dbh->prepare($q);
$sth->execute($hostid,$groupid,$documentid);
my $document=$sth->fetchrow_hashref();

if( ! $document ) {
	print "Error retrieving the document!";
	exit;
}

if( ! $document->{'comments'} ) {
	print "The document does not accept comments anymore!\n";
	exit;
}

# no quote to begin with
my $quote='';

# show the title
if($commentid ne '' && $mode ne 'doedit' ) {

	if( $mode eq 'edit' ) {

		# editing
		printcommenttitle("Editing comment on \"".
		$document->{'title'}."\"",$user,
		$icon,$dbh);

		# load the whole comment
		my $q="select username,content,title from comments ".
		" where hostid=? and groupid=? and documentid=? and commentid=? and parentid=?";
		my $x=$dbh->prepare($q);
		$x->execute($hostid,$groupid,$documentid,$commentid,$parentid);

		($username,$quote,$subject)=$x->fetchrow_array();

	} else {

		printcommenttitle("Answering on \"".
		$document->{'title'}."\"",$user,$icon,$dbh);

		# load the comment as quote.
		my $q="select content,username from comments where hostid=? and groupid=? ".
		"and documentid=? and commentid=? and parentid=?";
		my $x=$dbh->prepare($q);
		$x->execute($hostid,$groupid,$documentid,$commentid,$parentid);
		($quote,$subject)=$x->fetchrow_array();

		# now get rid of most of the junk
		$quote="<p class='quoted'>".$quote;
		$quote=~s/--.*/<\/p>/i;
		$quote.="<p></p>";	# this is to close the quote
		$subject="@ ".$subject;
	}

} else {

	printcommenttitle("Posting on \"".$document->{'title'}."\"",
		$user,$icon,$dbh);
}

# get the signature for the user (if the user is)
my $sign='';
my $q="select signature from users where email=?";
my $x=$dbh->prepare($q);
$x->execute($userid);
if( $x->rows > 0 ) {
	($sign)=$x->fetchrow_array();
}

# no sign? use the user's name
if( $sign eq '' ) {
	$sign=$username;
}

if( $debug ) {
	print "Found signature: $sign\n";
}

# do the insert?
if($mode eq 'add') {

	my $res;

	# checking the comment
	my $spam=checkthecomment();

	# If I am root, the moderator or the forum is not moderated, and the post
	# is not spam, it is automatically approved.
	if( (! $document->{'moderated'} || 
		$userid eq $document->{'moderator'} || 
		$userid eq $document->{'author'} || $isroot ) && ! $spam ) {
		$approved=1;
	} else {
		$approved=0;
	}

	# search the correct commentid: the commentid is ALWAYS incremented.
	# yes, I could have used an auto-increment, but they don't work very
	# well with InnoDB tables.
	my $q="select max(commentid) from comments where hostid=? and documentid=? and groupid=?";
	$sth=$dbh->prepare($q);
	$sth->execute($hostid,$documentid,$groupid);
	my ($pid)=$sth->fetchrow_array();
	$pid++;

	# Am I answering an already existing post?
	if( $commentid ne '') {

		# the parent id become the commentid of the old comment.

		$q=(q{
		insert into comments
		(hostid,groupid,documentid,commentid,parentid,title,content,author,
		username,clientip,approved,spam,spamscore)
		values
		(?,?,?,?,?,?,?,?,?,?,?,?,?)
		});

		$sth=$dbh->prepare($q);
		$res=$sth->execute($hostid,$groupid,$documentid,$pid,$commentid,
			$subject,$comment,$userid, $username,$clientip,
			$approved,$spam,$spamscore);

	} else {

		# the parent id is the same commentid!
		$q=(q{
		insert into comments
		(hostid,groupid,documentid,commentid,parentid,content,author,
		username,clientip,approved,title,spam,spamscore)
		values
		(?,?,?,?,?,?,?,?,?,?,?,?,?)
		});

		$sth=$dbh->prepare($q);
		$res=$sth->execute($hostid,$groupid,$documentid,$pid,$pid,$comment,$userid,
		$username,$clientip,$approved,$subject,$spam,$spamscore);
	}

	if( ! $res ) {
		print "<script>\n";
		print "window.alert(\"";
		print "Error during the processing of your comment.";
		print "\");\n";
		print "window.opener.location.reload();\n";
		print "window.close();\n";
		print "</script>\n";
	} else {
		if( ! $approved ) {
			print "<script>\n";
			print "window.alert(\"";
			print "Your comment has been posted, since the topic is moderated, ";
			print "the moderator need to approve the comment.";
			print "\");\n";
			print "window.opener.location.reload();\n";
			print "window.close();\n";
			print "</script>\n";
		} else {
			print "<script>\n";
			print "window.alert('";
			print "Your comment has been posted.";
			print "');\n";
			print "window.opener.location.reload();\n";
			print "window.close();\n";
			print "</script>\n";
		}
	}

	print "</body></html>\n";
	exit;

} elsif ($mode eq 'doedit' )  {

	# edit the comment

	# checking the comment
	my $spam=checkthecomment();

	my $q=(q{
		update comments set content=?,spam=?
		where
		hostid=? and groupid=? and documentid=? and
		commentid=? and parentid=?
		});

	$sth=$dbh->prepare($q);
	$sth->execute($comment,$spam,$hostid,$groupid,$documentid,$commentid,$parentid);

	print "<script>\n";
	print "window.alert('";
	print "Your comment has been posted.";
	print "');\n";
	print "window.opener.location.reload();\n";
	print "window.close();\n";
	print "</script>\n";
	print "</body></html>\n";
	exit;

} else {

	# show the input form
	print "<hr>\n";
	print "<form method='post' action='".$myself."' name='addpost'>\n";
	print "<input type='hidden' name='hostid' value='".$hostid."'>\n";
	print "<input type='hidden' name='groupid' value='".$groupid."'>\n";
	print "<input type='hidden' name='documentid' value='".$documentid."'>\n";
	print "<input type='hidden' name='commentid' value='".$commentid."'>\n";
	print "<input type='hidden' name='parentid' value='".$parentid."'>\n";
	if( $mode eq 'edit' ) {
		print "<input type='hidden' name='mode' value='doedit'>\n";
	} else {
		print "<input type='hidden' name='mode' value='add'>\n";
	}
	print "<table width='100%' border='0' cellspacing='0' ";
	print "cellpadding='3px' bgcolor='lightgrey'>\n";
	print "<tr>\n";
	print "<td>Author:</td>\n";
	print "<td>\n";
	print "<input type='text' name='username' size='50' value='";
	print $username;
	print "'>\n";
	print "</td></tr>\n";
	print "<tr>\n";
	print "<tr valign=top>";
	print "<td>Message:</td>";
	print "<td>\n";
	print "<textarea name='comment' cols='100%' rows='10'>\n";
	if($quote ne '') {
		print $quote;
	}
	print "</textarea>\n";
	# start the editor
	print "<script type='text/javascript'>\n";
	print "CKEDITOR.on( 'instanceReady', function(ev)\n";
	print "{ev.editor.dataProcessor.writer.setRules('p',{indent: false, breakBeforeOpen: false, breakAfterOpen: false,";
	print "breakBeforeClose: false, breakAfterClose:false});\n";
	print "})\n";
	print "CKEDITOR.replace('comment',\n";
	if( $isroot ) {
		print "{ toolbar: [['Source','Bold','Italic','Underline','Smiley']], startupMode: 'wysiwyg', width: '90%', ";
	} else {
		print "{ toolbar: [['Bold','Italic','Underline','Smiley']], startupMode: 'wysiwyg', width: '90%', ";
	}
	print "height:'200',";
	print "keystrokes: [[ CKEDITOR.CTRL+66, 'bold' ],[ CKEDITOR.CTRL+73, 'italic' ],[ CKEDITOR.CTRL+85, 'underline' ],[CKEDITOR.CTRL+83,'smiley']";
	if( $isroot ){
		print ",[CKEDITOR.CTRL+74,'image']";
	}
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

printfooter();

# end page
print "</body>\n";
print "</html>\n";

sub checkthecomment
{
	# do some basic check on the comment and the subject.
	my $s;

	# check the username
	$s=$username;

	$s=~s/\<a .*\>//ig;
	$s=~s/<\/?script>//ig;
	$s=~s/<//g;
	$s=~s/>//g;
	$username=$s;

	# now the comment itself...

	# no signature if I am in editing
	if( $mode ne 'doedit' && $sign ne '') {
		$s=$comment."-- ".$sign;
	} else {
		$s=$comment;
	}

	# reset comment
	$comment=$s;

	# build a "mesage"
	$s="From: ".$username." <".$userid.">\n";
	$s.="Subject: a comment posted on my site\n\n".$comment;

	# now feed everything to SpamAssassin and let's see what he sais...
	my $spampref='./user_prefs';
	my $spamtest=Mail::SpamAssassin->new({userprefs_filename=>$spampref});
	my $status=$spamtest->check_message_text($s);

	if( $comment eq '' || $status->is_spam() ) {

		#subject or comment were some junk
		$spamscore=$status->get_names_of_tests_hit();
		return 1;
	}
	return 0;
}
