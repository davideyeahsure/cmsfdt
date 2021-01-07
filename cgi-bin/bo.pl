#!/usr/bin/perl
#
# Backend for the CMS FDT V.5.1.1 - Jan 2021
#

use strict;
use DBI;
use CGI qw/:standard/;
use CGI::Cookie;
use Config::General;
use Date::Format;
use Date::Parse;
use Digest::MD5  qw(md5 md5_hex md5_base64);
use XML::RSS;
use File::Temp qw/tempfile/;

# load common lib
require 'cmsfdtcommon.pl';

my $today=time2str("%Y-%m-%d %H:%M",time);
my $myself=script_name();
my $query=CGI->new;

my $preferredlang;
my $dbh=dbconnect('./cms50.conf');

# now get other parameters from the db
my $iconsdir=getconfparam('iconsdir',$dbh);
my $avatardir=getconfparam('avatardir',$dbh);
my $forumdir=getconfparam('forumdir',$dbh);
my $defavatar=getconfparam('defavatar',$dbh);
my $debug=getconfparam('debug',$dbh);
my $css="/".getconfparam('cssdir',$dbh)."/".getconfparam('css',$dbh);
$css=~s/\/\//\//g;
my $deflang=getconfparam('deflang',$dbh);
my $preview=getconfparam('preview',$dbh);
my $postnew=getconfparam('postnew',$dbh);
my $deftpl=getconfparam('deftpl',$dbh);
my $defgroup=getconfparam('defsection',$dbh);
my $defdoc=getconfparam('defdoc',$dbh);
my $defnotfound=getconfparam('defnotfound',$dbh);
my $imgmaxsize=getconfparam('imgmaxsize',$dbh);
my $dateformat=getconfparam('dateformat',$dbh);

# maximum size of picture to upload:
$CGI::POST_MAX=$imgmaxsize*1024;

my $userremoveicon=$iconsdir."/".getconfparam('userremoveicon',$dbh);
my $useraddicon=$iconsdir."/".getconfparam('useraddicon',$dbh);
my $disableicon=$iconsdir."/".getconfparam('disableicon',$dbh);
my $upicon=$iconsdir."/".getconfparam('upicon',$dbh);
my $downicon=$iconsdir."/".getconfparam('downicon',$dbh);
my $delicon=$iconsdir."/".getconfparam('delicon',$dbh);
my $addicon=$iconsdir."/".getconfparam('addicon',$dbh);
my $faddicon=$iconsdir."/".getconfparam('folderadd',$dbh);
my $commaddicon=$iconsdir."/".getconfparam('commaddicon',$dbh);
my $commdelicon=$iconsdir."/".getconfparam('commdelicon',$dbh);
my $copyicon=$iconsdir."/".getconfparam('copyicon',$dbh);
my $enableicon=$iconsdir."/".getconfparam('enableicon',$dbh);
my $publishicon=$iconsdir."/".getconfparam('publishicon',$dbh);
my $unpublishicon=$iconsdir."/".getconfparam('unpublishicon',$dbh);
my $accepticon=$iconsdir."/".getconfparam('accepticon',$dbh);
my $selecticon=$iconsdir."/".getconfparam('selecticon',$dbh);
my $icon404=$iconsdir."/".getconfparam('404icon',$dbh);
my $lockicon=$iconsdir."/".getconfparam('lockicon',$dbh);
my $unlockicon=$iconsdir."/".getconfparam('unlockicon',$dbh);
my $rssicon=$iconsdir."/".getconfparam('rssicon',$dbh);
my $genrssicon=$iconsdir."/".getconfparam('genrssicon',$dbh);
my $editicon=$iconsdir."/".getconfparam('editicon',$dbh);
my $replyicon=$iconsdir."/".getconfparam('replyicon',$dbh);
my $pviewicon=$iconsdir."/".getconfparam('pviewicon',$dbh);
my $spamicon=$iconsdir."/".getconfparam('spamicon',$dbh);

# Get parameters from the query
my $hostid=$query->param('hostid');
my $mode=$query->param('mode');
my $groupid=$query->param('groupid');
my $documentid=$query->param('documentid');
my $history=$query->param('history');
my $link=$query->param('link');
my $language=$query->param('language');
my $current=$query->param('current');
my $templateid=$query->param('templateid');
my $textid=$query->param('textid');
my $seluser=$query->param('seluser');
my $fragid=$query->param('fragid');
my $msgid=$query->param('msgid');
my $type=$query->param('type');
my $email=$query->param('email');
my $rssid=$query->param('rssid');
my $cssid=$query->param('cssid');
my $rollout=$query->param('rollout');

# Generate the rss feed: without login
if( $mode eq 'genrss' && $rssid eq 'ALL' ) {
	genallrss();
	print $query->header(
		-type => 'text/plain',
		-expires=> '+1h'
	);
	print "ALL Rss done\n";
	exit;
}

# for pagination
my $begin=$query->param('begin');
my $end=$query->param('end');

# if no 'current' section, I start at hosts
if ( $current eq 'undefined' || $current eq '' ) {
	$current='hosts';
}

# current user
my $user;
my $icon;
my $isroot;
my $userid;
my $issuperuser;
my $curgroup;

my $author;
my $moderator;
my $msg;

# If logout...
if( $mode eq 'logout' ) {
	logout($dbh);
}

# if login, perform the login
if( $mode eq 'login' ) {
	login($query->param('email'),$query->param('password'),'none',$dbh,$query);
}

# if download, just get back the content of the document/template whatever
if( $mode eq 'download' ) {

	# get the current user
	($userid,$user,$icon,$isroot) = getloggedinusernoset($dbh);

	if( $current eq 'css' && checkuserrights('root')) {
		printcontentcss($cssid);
	}
	if( $current eq 'documents' && checkuserrights('doc',$hostid,$groupid,$documentid)) {
		printcontentdoc($hostid,$groupid,$documentid,$language);
	}
	if ( $current eq 'templates' && checkuserrights('host',$hostid)) { 
		printcontenttpl($hostid,$templateid,$language);
	}
	if ( $current eq 'fragments' && checkuserrights('host',$hostid)) { 
		printcontentfragment($hostid,$fragid,$language);
	}
	exit;
}

# update the cookie and output the content-header
($userid,$user,$icon,$isroot,$preferredlang) = getloggedinuser($dbh);

if( $userid eq 'NONE' ) {
	# Call directly the 'LOGIN' function to show the login screen.
	$hostid='';
	$groupid='';
	$current='';
	$documentid='';
	$mode='';
}

# expand/contract documents' display
if( $mode eq 'expand' ) {
	my $id='@'.$query->param('parentid').'@';
	if( $history =~ /$id/ ) {
		$history =~ s/$id//;
	} else {
		$history.=$id;
	}
	$mode='';
	$current='documents';
}

# check if the user is the host owner or group owner
my $ishostowner='no';
my $isgroupowner='no';

if( $hostid ) {
	my $qq='select owner from hosts where hostid=?';
	my $rr=$dbh->prepare($qq);
	$rr->execute($hostid);
	my ($cc)=$rr->fetchrow_array();
	if( $cc eq $userid ) {
		$ishostowner='yes';
	}
}

if( $groupid && $hostid ) {
	my $qq='select owner from groups where hostid=? and groupid=?';
	my $rr=$dbh->prepare($qq);
	$rr->execute($hostid,$groupid);
	my ($cc)=$rr->fetchrow_array();
	if( $cc eq $userid ) {
		$isgroupowner='yes';
	}
}

# if I have a documentid, get the author/moderator
if( $hostid ne '' && $groupid ne '' && $documentid ne '' && $language ne '' ) {
	# get the author/moderator
	my $q="select author,moderator from documents where hostid=? and groupid=? and documentid=?";
	my $r=$dbh->prepare($q);
	$r->execute($hostid,$groupid,$documentid);
	($author,$moderator)=$r->fetchrow_array();
}

# if I have a comment, the same as before...
if( $hostid ne '' && $groupid ne '' && $documentid ne '' && $current eq 'comments' ) {
	# get the author/moderator
	my $q="select author,moderator from documents where hostid=? and groupid=? and documentid=?";
	my $r=$dbh->prepare($q);
	$r->execute($hostid,$groupid,$documentid);
	($author,$moderator)=$r->fetchrow_array();
}

# Display functions that handle sub-parts of a window.
# show host's aliases
if( $mode eq 'showhostaliases' ) {
	showhostaliases($hostid,'');
	exit;
}

# Remove host alias
if( $mode eq 'delhostalias' ) {
	if( checkuserrights('host') ) {
		my $alias=$query->param('alias');
		my $msg=delhostalias($hostid,$alias);
		showhostaliases($hostid,$msg);
	}
	exit;
}

# Add a new alias for an host
if( $mode eq 'addhostalias' ) {

	if( checkuserrights('host'))  {
		my $alias=$query->param('alias');
		my $msg=addhostalias($hostid,$alias);
		showhostaliases($hostid,$msg);
	}
	exit;
}

# show document's icons
if( $mode eq 'showdocicons' ) {
	showdocumenticons();
	exit;
}

# Remove an existing link
if( $mode eq 'dellink' ) {
	if( checkuserrights('doc') ) {
		my $msg=removealink($hostid,$groupid,$documentid,$link);
		showdoclinks($hostid,$groupid,$documentid,$msg);
	}
	exit;
}

# Add a new link
if( $mode eq 'addlink' ) {
	if( checkuserrights('doc') ) {
		my $msg=addalink($hostid,$groupid,$documentid,$link);
		showdoclinks($hostid,$groupid,$documentid,$msg);
	}
	exit;
}


# show document's links
if( $mode eq 'showdoclinks' ) {
	showdoclinks($hostid,$groupid,$documentid,'');
	exit;
}

# reset a user's password - only for root
if( $mode eq 'resetpwd' && $isroot ) {
	resetpwd($email,$dbh,$deflang);
}


# Real functions
#
if( $mode eq 'delete' ) {

	# checl the user's rights
	if( $current eq 'documents' && checkuserrights('doc')) {
		deldocument();
	} elsif ( $current eq 'groups' && checkuserrights('host')) {
		delgroup();
	} elsif ( $current eq 'hosts' && checkuserrights('root')) {
		delhost();
	} elsif ( $current eq 'templates' && checkuserrights('host')) {
		deltemplate();
	} elsif ( $current eq 'fragments' && checkuserrights('host')) {
		delfragment();
	} elsif ( $current eq 'comments' && checkuserrights('comm')) {
		delcomment();
	} elsif ( $current eq 'users' && checkuserrights('root')) {
		deluser();
	} elsif ( $current eq 'texts' && checkuserrights('host')) {
		deltext();
	} elsif ( $current eq 'images' && hasadoc($userid)) {
		delimage();
	} elsif ( $current eq 'config' && checkuserrights('root')) {
		delconfig();
	} elsif ( $current eq 'feed' && checkuserrights('host')) {
		delrss();
	} elsif ( $current eq 'css' && checkuserrights('root')) {
		delcss();
	}
}

if( $mode eq 'edit' || $mode eq 'add' || $mode eq 'copy' ) {

	if( $current eq 'documents' && checkuserrights('doc',$hostid,$groupid,$documentid) ) {
		$msg=doeditdocument();
		# go back to the display of the document's edit window!
		if( $msg eq '' ) {
			$mode='editdoc';
		} else {
			$mode='adddoc';
		}
	} elsif ( $current eq 'groups' && checkuserrights('group',$hostid,$groupid) ) {
		doeditgroup();
	} elsif ( $current eq 'hosts' && checkuserrights('host',$hostid) ) {
		doedithost();
	} elsif ( $current eq 'templates' && checkuserrights('host',$hostid) ) {
		doedittemplate();
		$mode='edittpl';
	} elsif ( $current eq 'fragments' && checkuserrights('host',$hostid) ) {
		doeditfragment();
	} elsif ( $current eq 'texts' && checkuserrights('host',$hostid) ) {
		doedittext();
	} elsif ( $current eq 'feed' && checkuserrights('host',$hostid) ) {
		doeditrss();
	} elsif ( $current eq 'images' && hasadoc($userid) ) {
		doeditimage();
	} elsif ( $current eq 'config' && checkuserrights('root') ) {
		doeditconf();
	} elsif ( $current eq 'css' && checkuserrights('root') ) {
		doeditcss();
	}
}

# now show the header
printheader($dbh,$msg);

if( $debug ) {
	print "Userid: $userid IsRoot: $isroot IsHostowner: $ishostowner<br>\n";
	print "Author: $author, Moderator: $moderator, GroupOwner: $isgroupowner<br>\n";
	print "Current: $current Hostid: $hostid Groupid: $groupid Documentid: $documentid Language: $language Mode: $mode <br>\n";
}

# Generate the rss feed: without login
if( $mode eq 'genrss' ) {
	# generate RSS feed...
	if( $query->param('rssid') eq 'ALL' ) {
		genallrss();
		exit;
	} elsif ($query->param('rssid') eq '-ALL' ) {
		genallrss();
	} else {
		genrssfeed( $query->param('hostid'), $query->param('rssid') , 1);
	}
}

# Now let's do something userfull...

# Copy css
if( $mode eq 'copycss' && $isroot ) {
	# show edit window.
	copycss($query->param('cssid'));
	exit;
}

# Edit css
if( $mode eq 'editcss' && $isroot ) {
	# show edit window.
	editcss($query->param('cssid'));
	exit;
}

# Copy image 
if( $mode eq 'copyimage' && hasadoc($userid) ) {
	# show edit window.
	copyimage($hostid,$query->param('imageid'));
	exit;
}

# Edit image 
if( $mode eq 'editimage' && hasadoc($userid) ) {
	# show edit window.
	editimage($hostid,$query->param('imageid'));
	exit;
}

# Add an image
if( $mode eq 'addimage' && hasadoc($userid) ) {
	# show the add an image window
	addaimage($hostid,'NEW');
	exit;
}


# Copy configuration paramtere
if( $mode eq 'copyconf' && $isroot ) {
	# show edit window.
	copyconf($query->param('paramid'));
	exit;
}

# Edit configuration parameters
if( $mode eq 'editconf' && $isroot ) {
	# show edit window.
	editconf($query->param('paramid'));
	exit;
}

# Copy rss feeds
if( $mode eq 'copyrss' && checkuserrights('host')) {
	# show edit window.
	copyrss($hostid,$rssid);
	exit;
}

# Editing the RSS feeds
if( $mode eq 'editrss' && checkuserrights('host')) {
	# show edit window.
	editrss($hostid,$rssid);
	exit;
}

# Add an RSS feed
if( $mode eq 'addrss' && checkuserrights('host') ) {
	# show the add a rss
	addarss($hostid,'NEW');
	exit;
}

# Editing generic texts
if( $mode eq 'edittext' && checkuserrights('host')) {
	# show edit window.
	edittext($hostid,$textid,$language);
	exit;
}

# Add a description text
if( $mode eq 'addtext' && checkuserrights('host')) {
	# show the add a text
	addatext($hostid,$textid);
	exit;
}


# copy generic texts
if( $mode eq 'copytext' && checkuserrights('host')) {
	# show edit window.
	copytext($hostid,$textid,$language);
	exit;
}

# Editing templates
if( $mode eq 'edittpl' && checkuserrights('host')) {
	# show edit window.
	edittemplate($hostid,$templateid);
	exit;
}

# copy templates
if( $mode eq 'copytpl' && checkuserrights('host')) {
	# show edit window.
	copytemplate($hostid,$templateid);
	exit;
}

# Editing hosts
if( $mode eq 'edithost' && checkuserrights('host')) {
	# show edit window.
	edithost($hostid);
	exit;
}

# Copy hosts
if( $mode eq 'copyhost' && checkuserrights('root')) {
	# show copy window.
	copyhost($hostid);
	exit;
}

# Editing groups
if( $mode eq 'editgroup' && checkuserrights('group',$hostid,$groupid)) {
	# show edit window.
	editgroup($hostid,$groupid);
	exit;
}

# Copy groups
if( $mode eq 'copygroup' && checkuserrights('host')) {
	# show copy window.
	copygroup($hostid,$groupid);
	exit;
}

# Editing Fragments
if( $mode eq 'editfrag' && checkuserrights('host')) {
	# show edit window.
	editfragment($hostid,$fragid,$language);
	exit;
}

# Copy fragment
if( $mode eq 'copyfrag' && checkuserrights('host')) {
	# show copy window.
	copyfragment($hostid,$fragid,$language);
	exit;
}


# Editing documents
if( $mode eq 'editdoc' && checkuserrights('doc')) {
	# show edit window.
	editdocument($hostid,$groupid,$documentid,$language,$msg);
	exit;
}

# Adding an host
if( $mode eq 'addhost' && checkuserrights('root')) {
	# show the add an host form
	addanhost($hostid);
	exit;
}

# Adding a css
if( $mode eq 'addcss' && checkuserrights('root')) {
	# show the add a css form
	addacss();
	exit;
}

# Adding a group
if( $mode eq 'addgroup' && checkuserrights('host')) {
	# show the add a group form
	addagroup($hostid,$groupid);
	exit;
}

# Adding a template
if( $mode eq 'addtpl' && checkuserrights('host')) {
	# show the add a template form
	addatemplate($templateid);
	exit;
}

# Adding a fragment
if( $mode eq 'addfrag' && checkuserrights('host')) {
	# show the add a template form
	addafrag('NEW');
	exit;
}

# Adding a configuration parameter
if( $mode eq 'addconf' && checkuserrights('root') ) {
	# show the add a config param
	addaparam('NEW');
	exit;
}

# Adding or copying a document can be done if the user is the author/owner of the current group.
if( $mode eq 'adddoc' && checkuserrights('group') ) {
	addadocument($hostid,$groupid);
	exit;
}

if( $mode eq 'copydoc' && checkuserrights('group') ) {
	copydocument($hostid,$groupid,$documentid);
	exit;
}

# import of a document
if( $mode eq 'import' && checkuserrights('group') ) {
	importdocument($hostid,$groupid);
	exit;
}

# import of a document
if( $mode eq 'doimport' && checkuserrights('group') ) {
	doimportdocument($hostid,$groupid);
	exit;
}


# "Toggling" functions, changes the 'state' of one of the flag on
# a record.

if( $mode eq 'spam' && $current eq 'comments' && checkuserrights('comm')) {
	# toggle spam flag on comments
	togglespam();
}

if( $mode eq 'togroot' && checkuserrights('root') ) {
	# toggle root on a user - this can only be done by root - definitively!
	toggleroot();
}

# Publish/unpublis document or comment - this can be done by the owner/author of a document or the superuser
if( $mode eq 'togapproved' ) {
	if( $current eq 'users' && $isroot ) {
		toggleapprove();
	}
	if( $current eq 'comments' && checkuserrights('comm')) {
		toggleapprove();

		# call the display of the comment again
		showasinglecomment2();
		exit 0;
	}
	if( $current eq 'documents' && checkuserrights('doc') ) {
		toggleapprove();
	}
}

# Toggle inclusion in lists on documents
if( $mode eq 'togdisplay' && checkuserrights('doc')) {
	toggledisplay();
}

# Toggle comments on documents, this can be done by the moderator
if( $mode eq 'togcomment' && checkuserrights('comm')) {
	togglecomment();
}

# Begin display functions...
#
# Now, to avoid problems, I'm going to reload the page without the
# pesky parameters...
if( $mode ne '' ) {
	if( $current eq 'comments' && $mode eq 'togcomment' ) {
		# zap the document id
		print "<script>\n";
		print "window.location='".$myself."?current=".$current."&amp;hostid=".$hostid."&amp;groupid=".$groupid."#".$groupid."'";
		print "</script>\n";
		$documentid='';
	} elsif( $current eq 'documents' && ( $mode eq 'togapproved' || $mode eq 'togdisplay' || $mode eq 'edit' ) ) {
		if( $mode ne 'edit' ) {
			# Call the 'expand' function to re-display the previous block
			my $id='@'.$query->param('parentid').'@';
			if( $history =~ /$id/ ) {
				$history =~ s/$id//;
			} else {
				$history.=$id;
			}
		}
		# do nothing, this allow me to reload the previous window
		$mode='';

	} elsif ($current eq 'groups' && ($mode eq 'edit' || $mode eq 'delete') ) {
		$current='documents';
		print "<script>\n";
		print "window.location='".$myself."?current=".$current.
		"&amp;hostid=".$hostid."&amp;groupid=".$groupid."&amp;documentid=".$documentid."&amp;templateid=".
		$templateid."';\n";
		print "</script>\n";
	} elsif ($current eq 'templates' && $mode eq 'edittpl' ) {
		# do nothing, this allow me to reload the 'edit' window.
	} elsif ($current eq 'users' && $mode eq 'search' ) {
		# just pass the call to the users function
	} else {
		print "<script>\n";
		print "window.location='".$myself."?current=".$current.
		"&amp;hostid=".$hostid."&amp;groupid=".$groupid."&amp;documentid=".$documentid."&amp;templateid=".
		$templateid."&amp;history=".$history."';\n";
		print "</script>\n";
	}
}


# Am I in the 'manage comments' mode?
my $extra;
if( $hostid && $documentid && $current eq 'comments' ) {
	$extra='1';
}

# Display the title
printtitle();

# Show current commands
showc();

# Now display the current data.
# I repeate the checking here so I don't display wrong things
if( $current eq 'documents' ) {
	showroot($hostid,0,$history);
	showgroups($hostid,0,$history);
} elsif( $current eq 'hosts' ) {
	showhosts();
} elsif( $current eq 'templates' && checkuserrights('host')) {
	showtemplates($hostid);
} elsif( $current eq 'fragments' && checkuserrights('host')) {
	showfragments($hostid);
} elsif( $current eq 'comments' ) {
	showcomments($hostid,$groupid,$documentid);
} elsif( $current eq 'users' && checkuserrights('root')) {
	showusers($userid);
} elsif( $current eq 'feed' && checkuserrights('host')) {
	showrss($hostid,$rssid);
} elsif( $current eq 'config' && checkuserrights('root')) {
	showconfig();
} elsif( $current eq 'images' && hasadoc($userid)) {
	showimages();
} elsif( $current eq 'texts' && checkuserrights('host')) {
	showtexts($hostid,$textid);
} elsif( $current eq 'css' && checkuserrights('root')) {
	showcss();
}

# End of the page
closehtml($msg);
exit;

# =============== Utility functions
# Note: in most of these functions I repeat the check who-can-do-what, just to
# be super-safe.

# Remove a css
sub delcss
{
	# do I have the rights?
	if( ! checkuserrights('root')) {
		print "<script>\n";
		print "alert(\"You don't have the rights to do that.\");\n";
		print "</script>\n";
		return;
	}

	my $cssid=$query->param('cssid');
	my $basdir=getconfparam('base',$dbh);
	my $cssdir=getconfparam('cssdir',$dbh);
	my $qq='select filename from css where cssid=?';
	my $r=$dbh->prepare($qq);
	$r->execute($cssid);
	my ($f)=$r->fetchrow_array();
	$r->finish();

	# remove the CSS from ALL THE DOCUMENTS, Groups, hosts and so on.
	my @q=(
	"update documents set cssid='default.css' where cssid=?",
	"update groups set cssid='default.css' where cssid=?",
	"update hosts set cssid='default.css' where cssid=?",
	"delete from css where cssid=?"
	);

	foreach $qq (@q) {


		$r=$dbh->prepare($qq);
		if( ! $r->execute($cssid) ) {
			print "<script>\n";
			print "alert('Error removing CSS!');\n";
			print "</script>\n";
			print STDERR "ERROR: Can't delete the CSS $qq !\n";
			return;
		}
		$r->finish();
	}

	# ok, now zap it from the disk
	$f=$basdir."/".$cssdir."/".$f;
	$f=~s/\/\//\//g;
	`unlink $f`;

	print "<script>\n";
	print "alert('CSS ".$cssid." removed.');\n";
	print "</script>\n";

	return;

}

# Remove an rssid
sub delrss
{
	# do I have the rights?
	if( ! checkuserrights('host')) {
		print "<script>\n";
		print "alert(\"You don't have the rights to do that.\");\n";
		print "</script>\n";
		return;
	}
	
	# remove the rss from all the documents
	my $q="update documents set rssid='' where hostid=? and rssid=?";
	my $rsh=$dbh->prepare($q);
	$rsh->execute($hostid,$rssid);

	# well, let's do it then
	$q="delete from rssfeeds where hostid=? and filename=?";
	$rsh=$dbh->prepare($q);
	$rsh->execute($hostid,$rssid);

	print "<script>\n";
	print "alert('Feed ".$rssid ." removed.');\n";
	print "</script>\n";

}

# Remove a fragment
sub delfragment
{

	if( ! checkuserrights('host') ) {
		print "<script>\n";
		print "alert(\"You don't have the rights to do that.\");\n";
		print "</script>\n";
		return;
	}

	# well, let's do it then
	my $q="delete from fragments where fragid=? and language=?";
	my $rsh=$dbh->prepare($q);
	if( $rsh->execute($fragid,$language) ) {
		print "<script>\n";
		print "alert('Fragment ".$fragid ." (".$language.") removed.');\n";
		print "</script>\n";
	} else {
		print "<script>\n";
		print "alert('Error: ".$dbh->{mysql_error}."');\n";
		print "</script>\n";
	}
}

# Remove a template from the system (if the user can)
sub deltemplate
{
	if( ! checkuserrights('host')) {
		print "<script>\n";
		print "alert(\"You don't have the rights to do that.\");\n";
		print "</script>\n";
		return;
	}

	# check if the template is used somewhere...
	my $q='select count(*) from documents where template=? and hostid=?';
	my $rsh=$dbh->prepare($q);
	$rsh->execute($templateid,$hostid);
	my ($n)=$rsh->fetchrow_array();

	if( $n > 0 ) { 
		print "<script>\n";
		print "alert(\"The template is in use by $n documents, so he can't be removed.\");\n";
		print "</script>\n";
		return;
	}

	# well, let's do it then
	$q="delete from templates where title=? and hostid=?";
	$rsh=$dbh->prepare($q);
	if( $rsh->execute($templateid,$hostid) ) {
		print "<script>\n";
		print "alert('Template ".$templateid." has been removed.');\n";
		print "</script>\n";
	} else {
		print "<script>\n";
		print "alert('Error: ".$dbh->{mysql_error}."');\n";
		print "</script>\n";
	}
}

# Remove a group and all the associated documents
sub delgroup
{
	if( ! checkuserrights('host')) {
		print "<script>\n";
		print "alert(\"You don't have the rights to do that.\");\n";
		print "</script>\n";
		return;
	}

	my $q='delete from comments where hostid=? and groupid=?';
	my $rsh=$dbh->prepare($q);
	$rsh->execute($hostid,$groupid);
	$q='delete from links where hostid=? and groupid=?';
	$rsh=$dbh->prepare($q);
	$rsh->execute($hostid,$groupid);
	$q='delete from documents where hostid=? and groupid=?';
	$rsh=$dbh->prepare($q);
	$rsh->execute($hostid,$groupid);
	$q='delete from groups where hostid=? and groupid=?';
	$rsh=$dbh->prepare($q);
	$rsh->execute($hostid,$groupid);

	print "<script>\n";
	print "alert('Group ". $groupid." AND ALL THE DOCUMENTS AND ASSOCIATED COMMENTS removed.');\n";
	print "</script>\n";
}

# Remove a whole HOST (!) and all the attached elements
sub delhost
{
	if( ! checkuserrights('root')) {
		print "<script>\n";
		print "alert(\"You don't have the rights to do that.\");\n";
		print "</script>\n";
		return;
	}

	# Table to zap
	my @q=qw(
		hostaliases
		comments
		documentscontent
		links
		documents
		groups
		templates
		fragments
		images
		rssfeeds
		hosts
		);

	my $rsh;
	my $x;
	foreach my $table (@q) {
		$x="delete from $table where hostid=?";
		$rsh=$dbh->prepare($x);
		$rsh->execute($hostid);
	}

	# Now remove the Images,RSS and other directories
	my $base=getconfparam('base',$dbh);
	my $destdir=getconfparam('imgdir',$dbh);
	my $imagedir=$base."/".$destdir."/".$hostid."/";
	$imagedir=~s/\/\//\//g;
	$imagedir=~s/\/$//;

	# if the directory does exists,  remove it
	if( checkdir($imagedir) eq '' ) {
		`rm -fr $imagedir`;
	}

	# remove the whole rss dir
	my $rssdir=$base."/".getconfparam('rssfeeddir',$dbh)."/".$hostid;
	$rssdir=~s/\/\//\//g;

	# if the directory does exists,  remove it
	if( checkdir($rssdir) eq '' ) {
		`rm -fr $rssdir`;
	}

	print "alert('Host ". $hostid." AND ALL THE ASSOCIATED DOCUMENTS, GROUPS AND SO ON removed.');\n";
	print "</script>\n";

	# reset the hostid
	$hostid='';
}

# Remove a document from the system (if the user can)
sub deldocument
{
	if( ! checkuserrights('group') ) {
		print "<script>\n";
		print "alert(\"You don't have the rights to do that.\");\n";
		print "</script>\n";
		return;
	}

	# let's zap all the links first
	my $q='delete from links where hostid=? and groupid=? and documentid=?';
	my $rsh=$dbh->prepare($q);
	$rsh->execute($hostid,$groupid,$documentid);
	
	# let's also zap all the comments for the document
	$q='delete from comments where hostid=? and groupid=? and documentid=?';
	$rsh=$dbh->prepare($q);
	$rsh->execute($hostid,$groupid,$documentid);

	# let's zap the content now
	$q='delete from documentscontent where hostid=? and groupid=? and documentid=?';
	$rsh=$dbh->prepare($q);
	$rsh->execute($hostid,$groupid,$documentid);

	# and dulcis in fundo, the document itself
	$q='delete from documents where hostid=? and groupid=? and documentid=?';
	$rsh=$dbh->prepare($q);
	if( $rsh->execute($hostid,$groupid,$documentid) ) {
		print "<script>\n";
		print "alert('Document removed.');\n";
		print "</script>\n";
	} else {
		print "<script>\n";
		print "alert('Error: ".$dbh->{mysql_error}."');\n";
		print "</script>\n";
	}
}

# Display functions 

# Show all the CSS
sub showcss
{

	# If I'm not root, bug off
	if( ! checkuserrights('root') ) {
		return;
	}

	my $q="select cssid, filename, description, to_char(updated,'".$dateformat."') as updated,".
	"to_char(created,'".$dateformat."') as created from css order by description";

	my $r=$dbh->prepare($q);
	$r->execute();

	# table header
	print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' ";
	print "cellpadding='5pt'>";
	print "<thead>\n";
	print "<th align='left'>\n";
	print "Description";
	print "</th>\n";
	print "<th align='left'>\n";
	print "Created";
	print "</th>\n";
	print "<th align='left'>\n";
	print "Updated";
	print "</th>\n";
	print "<th align='center'> &nbsp; </td>\n";
	print "</thead>\n";
	print "<tbody>\n";

	my $edithis="";
	my $color=0;
	my $editwidth=getconfparam('css-fw',$dbh);
	my $editheight=getconfparam('css-fh',$dbh);

	while (my $t=$r->fetchrow_hashref() ) {

		# I build it here, so I don't have to rewrite it every time
		if( $isroot ) {
			$edithis="javascript:openwindow(\"$myself?mode=editcss&amp;".
			"cssid=". $t->{'cssid'}. "\",\"edit\",".$editwidth.",".$editheight.")";
		}

		print "<tr ";
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
		print ">\n";

		print "<td align='left'>";
		print "<a href='".$edithis."'>";
		print $t->{'description'};
		print "</a>\n";
		print "</td>\n";

		print "<td align='left'>";
		print $t->{'created'};
		print "</td>\n";
		print "<td align='left'>";
		print $t->{'updated'};
		print "</td>\n";
		print "<td align='right'>\n";
		my $id="current=css&cssid=".$t->{'cssid'}."&hostid=".$hostid;

		showminicommand2('delete',$delicon,"Delete the css $t->{'cssid'}?",$myself."?mode=delete&".$id,$current);
		showminicommand('copy',$copyicon,$myself."?mode=copycss&".$id,$current,0,0,1);

		print "</td>\n";
		print "</tr>\n";
	}

	print "</table>\n";

	return;

}

# Show all the users
sub showusers
{
	# If I'm not root, bug off
	if( ! checkuserrights('root') ) {
		return;
	}

	my $unconf=$query->param('unconf');
	my $srch=$query->param('srchuser');
	my $q;

	# Count how many users there are on the system...
	if( $unconf eq 'unconf' ) {
		$q="select count(*) from users where password='nopass' or password='disabled'";
	} else {
		$q="select count(*) from users";
	}
	my $r=$dbh->prepare($q);
	$r->execute();
	my ($tot)=$r->fetchrow_array();
	$r->finish();

	# fix begin and end
	if( $begin eq '' ) {
		$begin=0;
	}

	$end=$begin+100;
	if( $end > $tot ) {
		$end=$tot;
	}

	# if only unconfirmed...
	if( $unconf eq 'unconf' ) {
		$q="select email,name,icon,to_char(lastseen,'".$dateformat."') as lastseen, ".
		"to_char(registered,'".$dateformat."') as registered,password,isroot from users ".
		"where password='nopass' or password='disabled' order by email limit 100 ".
		"offset $begin";
	} elsif ($srch ne '') {
		$q="select email,name,icon,to_char(lastseen,'".$dateformat."') as lastseen, ".
		"to_char(registered,'".$dateformat."') as registered,password,isroot from users ".
		"where email like '%".$srch."%' or name like '%".$srch."%' ".
		"order by email limit 100";

	} else {
		$q="select email,name,icon,to_char(lastseen,'".$dateformat."') as lastseen, ".
		"to_char(registered,'".$dateformat."') as registered,password,isroot from users order by email limit 100 ".
		" offset $begin";
	}

	$r=$dbh->prepare($q);
	$r->execute();
	my $defavatar=getconfparam('defavatar',$dbh);
	my $color=0;

	# display the 'pages' links and the 'show only unconfirmed' users
	print "<table width='100%' bgcolor='white' border='0' cellspacing='0'>";
	print "<tr><td>\n";
	print "<form method='post' action='".$myself."'>";
	if( $tot > 100 ) {
		print "Users from ".$begin." to ".$end." of $tot  - ";

		for( my $x=0;$x<$tot;$x+=100 ) {
			print "&nbsp;<a href='".$myself."?current=users&amp;hostid=".$hostid."&amp;begin=".$x."'>";
			print "$x";
			print "</a> ";
		}
	}
	if( $unconf eq 'unconf' ) {
		print " <a href='".$myself."?current=users&amp;hostid=".$hostid ."&amp;unconf=&amp;begin=".$begin."'>";
		print "All users</a>";
	} else {
		print " <a href='".$myself."?current=users&amp;hostid=".$hostid ."&amp;unconf=unconf&amp;begin=".$begin."'>";
		print "Waiting confirmation</a>";
	}

	# show the search box
	print " &nbsp; &nbsp; ";
	print "<input type='hidden' name='current' value='users'>";
	print "<input type='hidden' name='mode' value='search'>";
	print "<input type='text' name='srchuser' value='".$srch."'>";
	print "<input type='submit' value='search'>";
	print "</form>";
	print "</td></tr></table>\n";

	# table header
	print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' ";
	print "cellpadding='5pt'>";
	print "<thead>\n";
	print "<th align='center'>\n";
	print "Icon";
	print "</td>\n";
	print "<th align='left'>\n";
	print "E-mail";
	print "</th>\n";
	print "<th align='left'>\n";
	print "Name";
	print "</th>\n";
	print "<th align='left'>\n";
	print "Registered";
	print "</th>\n";
	print "<th align='left'>\n";
	print "Last login";
	print "</th>\n";
	print "<th align='right'>\n";
	print "# Posts";
	print "</th>\n";
	print "<th align='right'>\n";
	print "# Docs";
	print "</th>\n";
	print "<th align='center'> &nbsp; </td>\n";
	print "</thead>\n";
	print "<tbody>\n";

	my $edithis="";
	my $edituserwidth=getconfparam('edituserwidth',$dbh);
	my $edituserheight=getconfparam('edituserheight',$dbh);

	# loop and display the users
	while( my $x=$r->fetchrow_hashref() ) {

		# I build it here, so I don't have to rewrite it every time
		if( $isroot ) {
			$edithis="javascript:openwindow(\"/cgi-bin/edituser.pl?mode=display&amp;".
			"email=". scrub($x->{'email'},$dbh). "\",\"edit\",".
			$edituserwidth.",".$edituserheight.")";
		}

		print "<tr ";
		if( $x->{'password'} eq 'nopass' || $x->{'password'} eq 'disabled' ) {
			print "bgcolor='yellow'";
		} else {
			if( $color==0 ) {
				print " bgcolor='white' ";
				$color=1;
			} else {
				$color=0;
			}
		}
		print ">\n";

		print "<td align='center'>";
		if( $x->{'icon'} eq '' ) {
			print "<img alt='avatar' src='".$avatardir."/".$defavatar."' width='24'>\n";
		} else {
			print "<img alt='avatar' src='".$avatardir."/".$x->{'icon'}."' width='24'>\n";
		}
		print "</td>\n";
		print "<td align='left'>";
		print "<a href='".$edithis."'>";
		print scrub($x->{'email'},$dbh);
		print "</a>\n";
		print "</td>\n";
		print "<td>";
		print $x->{'name'};
		print "</td>\n";
		print "<td>";
		print $x->{'registered'};
		print "</td>\n";
		print "<td>";
		print $x->{'lastseen'};
		print "</td>\n";

		# compute and show the # of comments for this uses
		print "<td align='right'>";
		my $qq='select count(*) from comments where author=?';
		my $rr=$dbh->prepare($qq);
		$rr->execute($x->{'email'});
		my ($cc)=$rr->fetchrow_array();
		print $cc;
		print "</td>\n";

		# compute and show the # of documents for this uses
		print "<td align='right'>";
		$qq='select count(*) from documents where author=?';
		$rr=$dbh->prepare($qq);
		$rr->execute($x->{'email'});
		($cc)=$rr->fetchrow_array();
		print $cc;
		print "</td>\n";


		print "<td align='right'>\n";
		my $id="current=users&amp;email=".scrub($x->{'email'},$dbh)."&amp;hostid=".$hostid;

		# I can't delete myself...
		if( $x->{'email'} ne $userid ) {
			showminicommand2('delete',$delicon,"Delete the user ".scrub($x->{'email'},$dbh)."?",
			$myself."?mode=delete&".$id,$current);
		}

		if( $x->{'isroot'} ) {
			showminicommand('demote to normal user',$downicon,$myself."?mode=togroot&".$id,$current,0,0,1);
		} else {
			if( $x->{'email'} ne $userid ) {
				showminicommand('promote to root',$upicon,$myself."?mode=togroot&".$id,$current,0,0,1);
			}
		}
		showminicommand('reset password',$lockicon,$myself."?mode=resetpwd&".$id,$current,0,0,1);
		if( $x->{'password'} eq 'nopass' || $x->{'password'} eq 'disabled' ) {
			showminicommand('confirm/enable user',$accepticon,
				$myself."?mode=togapproved&amp;current=users&amp;".$id,$current,0,0,1);
		} else {
			if( $x->{'email'} ne $userid ) {
				showminicommand('disable user',$userremoveicon,$myself.
					"?mode=togapproved&amp;current=users&amp;".$id,$current,0,0,1);
			} 
		}

		print "</td>\n";
		print "</tr>\n";

	}
	print "</tbody>\n";
	print "</table>\n";

}

# show all the images for this host
sub showimages
{

	my $q=(q{
		select 
		i.*,
		u.name as authname
		from images i, users u
		where 
		i.hostid=? and
		i.author=u.email
		order by i.imageid
	});

	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);
	my $thumbdir=getconfparam('thumbdir',$dbh);
	$thumbdir="/img/".$hostid."/".$thumbdir;

	my $color=0;
	print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' cellpadding='5pt'>";
	print "<thead>\n";
	print "<th align='center'>Image</th>\n";
	print "<th align='left'>Filename</th>\n";
	print "<th align='left'>Author</th>\n";
	print "<th align='left'>Update</th>\n";
	print "<th align='left'>Metatag</th>\n";
	print "<th align='left'>Link</th>\n";
	print "<th align='center'> &nbsp; </th>\n";
	print "</thead>\n";
	print "<tbody>\n";

	if( $debug ) {
		print "Showing images ".$q." with hostid=".$hostid."<br>\n";
	}

	my $r=$dbh->prepare($q);
	$r->execute($hostid);

	while( my $x=$r->fetchrow_hashref() ) {

		my $metatag='&lt;!--img='.$x->{'imageid'}."--&gt;";
		my $link="&lt;img src='/img/".$hostid."/".$x->{'filename'}."'&gt;";

		my $show;
		$show="javascript:openwindow(\"".$myself."?mode=editimage&current=$current&";
		$show.="hostid=".$x->{'hostid'}."&imageid=".$x->{'imageid'}."\",\"edit\",".$winw.",".$winh.")'";

		print "<tr ";
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
		print ">\n";

		print "<td align='center' valign='middle'>";
		print "<a href='".$show."'>";
		print "<img src='".$thumbdir."/".$x->{'filename'}."' height='32' border='0' ";
		print "alt='click to edit' title='click to edit'>";
		print "</a>";
		print "</td>\n";
		print "<td>";
		print "<a href='".$show."'>";
		print $x->{'filename'};
		print "</a>\n";
		print "</td>\n";
		print "<td>";
		print $x->{'authname'};
		print "</td>\n";
		print "<td>";
		print $x->{'created'};
		print "</td>\n";
		print "<td>";
		print $metatag;
		print "</td>\n";
		print "<td>";
		print $link;
		print "</td>\n";

		print "<td align='right'>";
		my $id="&current=images&hostid=".$x->{'hostid'}."&imageid=".$x->{'imageid'};
		if( hasadoc($userid) ) {
			showminicommand('copy image',$copyicon,$myself."?mode=copyimage".$id,$current,$winw,$winh,0);
			showminicommand2('remove image',$delicon,"Remove image".$x->{'imageid'}."?",
			$myself."?mode=delete".$id,$current);
		}
		print "</td>\n";
		print "</tr>\n";
	}
	print "</tbody>\n";
	print "</table>\n";

}

# show all the rss feeds
sub showrss
{
	my $hostid=shift;

	my $q="select r.hostid,r.filename,r.title,".
		"to_char(r.lastdone,'".$dateformat."') as lastdone, ".
		"count(documentid) as numdocs ".
		"from rssfeeds r left join documents d on ".
		"r.hostid=d.hostid and r.filename=d.rssid ".
		"where r.hostid=? ".
		"group by r.hostid,r.filename,r.title,r.lastdone ".
		"order by r.filename";

	my $r=$dbh->prepare($q);
	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);

	$r->execute($hostid);

	my $color=0;
	print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' cellpadding='5pt'>";
	print "<thead>\n";
	print "<th align='left'>Title</th>\n";
	print "<th align='left'>Filename</th>\n";
	print "<th align='left'>Last done</th>\n";
	print "<th align='right'># docs</th>\n";
	print "<th align='center'> &nbsp; </th>\n";
	print "</thead>\n";
	print "<tbody>\n";

	while( my $x=$r->fetchrow_hashref() ) {

		my $show;
		$show="javascript:openwindow(\"".$myself."?mode=editrss&amp;current=$current&amp;";
		$show.="hostid=".$x->{'hostid'}."&amp;rssid=".$x->{'filename'}."\",\"edit\",".$winw.",".$winh.")'";

		print "<tr ";
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
		print ">\n";

		print "<td>";
		print "<a href='".$show."'>";
		print $x->{'title'};
		print "</a>\n";
		print "</td>\n";
		print "<td>";
		print $x->{'filename'};
		print "</td>\n";
		print "<td>";
		print $x->{'lastdone'};
		print "</td>\n";
		print "<td align='right'>";
		print $x->{'numdocs'};
		print "</td>\n";

		print "<td align='right'>";
		my $id="&current=feed&hostid=".$x->{'hostid'}."&rssid=".$x->{'filename'};
		showminicommand('copy rss feed',$copyicon,$myself."?mode=copyrss".$id,$current,$winw,$winh,0);
		showminicommand('generate rss feed',$genrssicon,$myself."?mode=genrss".$id,$current,0,0,1);
		showminicommand2('remove rss feed',$delicon,"Remove feed ".$x->{'filename'}."?",$myself."?mode=delete".$id,$current);
		print "</td>\n";
		print "</tr>\n";
	}
	print "</tbody>\n";
	print "</table>\n";

}

# show configuration parameters
sub showconfig
{
	my $q="select paramid,value,description,to_char(updated,'".$dateformat."') as updated from configuration order by paramid";
	my $r=$dbh->prepare($q);
	$r->execute();
	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);

	my $color=0;

	print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' cellpadding='5pt'>";
	print "<thead>\n";
	print "<th width='10%' align='left'>Id</th>\n";
	print "<th width='30%' align='left'>Value</th>\n";
	print "<th width='40%' align='left'>Description</th>\n";
	print "<th width='10%' align='left'>Updated</th>\n";
	print "<th align='center'>&nbsp;</th>\n";
	print "</thead>\n";
	print "<tbody>\n";

	while( my $x=$r->fetchrow_hashref() ) {

		my $show;
		$show="javascript:openwindow(\"".$myself."?mode=editconf&amp;current=$current&amp;";
		$show.="paramid=".$x->{'paramid'}."\",\"edit\",".$winw.",".$winh.")";

		print "<tr ";
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
		print ">\n";

		print "<td>\n";
		print "<a href='".$show."'>\n";
		print $x->{'paramid'};
		print "</a>\n";
		print "</td>\n";
		print "<td>\n";
		print $x->{'value'};
		print "</td>\n";
		print "<td>\n";
		print $x->{'description'};
		print "</td>\n";
		print "<td>\n";
		print $x->{'updated'};
		print "</td>\n";

		print "<td align='center'>\n";
		my $id="&amp;current=config&amp;paramid=".$x->{'paramid'}."&amp;hostid=".$hostid;
		showminicommand2('delete',$delicon,"delete the parameter ".$x->{'paramid'}." ?",
		$myself."?mode=delete".$id,$current);
		showminicommand('copy',$copyicon,$myself."?mode=copyconf".$id,$current,$winw,$winh,0);
		print "</td>\n";
		print "</tr>\n";
	}

	print "<tbody>\n";
	print "</table>\n";

}

# show all the default texts for an host
sub showtexts
{
	my $hostid=shift;

	if( $debug ) {
		print "Selecting all deftexts for host $hostid<br>\n";
	}

	my $q="select * from deftexts where hostid=? order by textid,language";
	my $r=$dbh->prepare($q);
	$r->execute($hostid);

	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);
	my $color=0;

	print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' cellpadding='5pt'>";
	print "<thead>\n";
	print "<th align='left' width='20%'>Id</th>\n";
	print "<th align='left'>Lang</th>\n";
	print "<th align='left'>Content</th>\n";
	print "<th>&nbsp;</th>\n";
	print "</thead>\n";
	print "<tbody>\n";

	while( my $x=$r->fetchrow_hashref() ) {

		my $show;
		if( $isroot ) {
			$show="javascript:openwindow(\"".$myself."?mode=edittext&amp;current=$current&amp;";
			$show.="hostid=".$hostid."&amp;textid=".$x->{'textid'}."&amp;language=".
			$x->{'language'}."\",\"edit\",".
			$winw.",".$winh.")'";
		}

		print "<tr ";
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
		print ">\n";

		print "<td><a href='".$show."'>";
		print $x->{'textid'};
		print "</a></td>\n";
		print "<td>";
		print $x->{'language'};
		print "</td>\n";
		print "<td>";
		print $x->{'content'};
		print "</td>\n";

		print "<td align='right'>\n";
		showminicommand2('delete',$delicon,"Delete the text ".$x->{'textid'}." ?",
		$myself."?mode=delete&amp;hostid=$hostid&amp;current=texts&amp;textid=".$x->{'textid'}.
		"&amp;language=".$x->{'language'},$current);
		showminicommand('copy',$copyicon,
		$myself."?mode=copytext&amp;hostid=$hostid&amp;current=texts&amp;textid=".$x->{'textid'}.
		"&amp;language=".$x->{'language'},$current,$winw,$winh,0);
		print "</td>";
		print "</tr>\n";
	}
	print "</tbody>\n";
	print "</table>\n";

}

# show all the fragments
sub showfragments
{
	my $hostid=shift;

	my $q="select * from fragments where hostid=? order by hostid,fragid,language";
	my $r=$dbh->prepare($q);
	$r->execute($hostid);

	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);
	my $color=0;

	print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' cellpadding='5pt'>";
	print "<thead>\n";
	print "<th align='left'>Id</th>\n";
	print "<th align='left'>Lang</th>\n";
	print "<th>&nbsp;</th>\n";
	print "</thead>\n";
	print "<tbody>\n";
	my $show;

	while( my $x=$r->fetchrow_hashref() ) {

		$show="javascript:openwindow(\"".$myself."?mode=editfrag&amp;current=".$current.
		"&amp;hostid=".$x->{'hostid'}."&amp;fragid=".$x->{'fragid'}."&amp;language=".
		$x->{'language'}."\",\"edit\",".$winw.",".$winh.")";

		print "<tr ";
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
		print ">\n";

		print "<td><a href='".$show."'>";
		print $x->{'fragid'};
		print "</a></td>\n";
		print "<td>";
		print $x->{'language'};
		print "</td>\n";

		print "<td align='right'>\n";
		my $id="&amp;current=fragments&amp;hostid=".$hostid."&amp;fragid=".$x->{'fragid'}."&amp;language=".$x->{'language'};
		showminicommand2('delete',$delicon,"Delete the fragment ".$x->{'fragid'}." ?",
		$myself."?mode=delete".$id,$current);
		showminicommand('copy',$copyicon,$myself."?mode=copyfrag".$id,$current,$winw,$winh,0);
		print "</td>";
		print "</tr>\n";
	}
	print "</tbody>\n";
	print "</table>\n";

}

# show all the hosts
sub showhosts
{
	if( $userid eq 'NONE' ) {
		return;
	}

	my $q="select hosts.hostid, c.description as cssid, hosts.deflang, hosts.owner,".
		"to_char(hosts.created,'".$dateformat."') as created, count(documentid) as documents ".
		"from css c, hosts left join documents on documents.hostid=hosts.hostid where ".
		"hosts.cssid=c.cssid ".
		"group by hosts.hostid, hosts.created, c.description, hosts.deflang, hosts.owner ".
		"order by hosts.hostid";

	my $r=$dbh->prepare($q);
	$r->execute();

	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);
	my $color=0;

	print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' cellpadding='5pt'>";
	print "<thead>\n";
	print "<th align='left'>Hostname</th>\n";
	print "<th align='left'>Created</th>\n";
	print "<th align='left'>Language</th>\n";
	print "<th align='left'>CSS</th>\n";
	print "<th align='left'># Docs</th>\n";
	print "<th>&nbsp;</th>\n";
	print "</thead>\n";
	print "<tbody>\n";

	while( my $x=$r->fetchrow_hashref() ) {

		my $show;
		$show="href='javascript:openwindow(\"".$myself."?mode=edithost&amp;current=$current&amp;";
		$show.="hostid=".$x->{'hostid'}."\",\"edit\",".$winw.",".$winh.")' ";

		print "<tr ";
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
		print ">\n";

		print "<td>\n";
		if( checkuserrights('host',$x->{'hostid'})) {
			print "<a $show>\n";
			print $x->{'hostid'};
			print "</a>\n";
		} else {
			print $x->{'hostid'};
		}
		print "</td>\n";
		print "<td>\n";
		print "$x->{'created'}";
		print "</td>\n";
		print "<td>\n";
		print "$x->{'deflang'}";
		print "</td>\n";
		print "<td>\n";
		print "$x->{'cssid'}";
		print "</td>\n";
		print "<td>\n";
		print "$x->{'documents'}";
		print "</td>\n";

		print "<td align='right'>";
		if( checkuserrights('root') ) {
			showminicommand2('delete',$delicon,"Delete the host ".$x->{'hostid'}.
				" and all the associated documents?",
				$myself."?mode=delete&amp;current=".$current."&amp;hostid=".$x->{'hostid'},$current);
			showminicommand('copy',$copyicon,$myself."?mode=copyhost&amp;current=".$current."&amp;hostid=".$hostid,
				$current,$winw,$winh,0);
		}

		showminicommand('select',$selecticon,
		$myself."?mode=selecthost&amp;current=".$current."&amp;hostid=".$x->{'hostid'},
		$current,0,0,1);
		print "</td>";
		print "</tr>\n";
	}
	print "</tbody>\n";
	print "</table>\n";

}

# show all the templates
sub showtemplates
{
	my $q="select t.hostid,t.title,".
		"to_char(t.updated,'".$dateformat."') as updated,t.isdefault,count(d.documentid) as howmany ".
		"from templates t left join documents d ".
		"on t.hostid=d.hostid and t.title=d.template ".
		"where ".
		"t.hostid=? ".
		"group by t.hostid,t.title,t.updated,t.isdefault ".
		"order by t.hostid,t.title";

	my $r=$dbh->prepare($q);
	$r->execute($hostid);

	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);
	my $color=0;

	print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' cellpadding='5pt'>";
	print "<thead>\n";
	print "<th align='left'>&nbsp;</th>\n";
	print "<th align='left'>Title</th>\n";
	print "<th align='left'>Used</th>\n";
	print "<th align='left'>Updated</th>\n";
	print "<th align='center'></th>\n";
	print "</thead>\n";
	print "<tbody>\n";

	while( my $x=$r->fetchrow_hashref() ) {

		my $show;
		my $id="&amp;hostid=".$hostid."&amp;current=".$current."&amp;templateid=".$x->{'title'};

		$show="href='javascript:openwindow(\"".$myself."?mode=edittpl&amp;current=$current";
		$show.=$id."\",\"edit\",".$winw.",".$winh.")' ";

		print "<tr ";
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
		print ">\n";

		print "<td width='30px'>\n";
		if( $x->{'isdefault'} ) {
			showminicommand('default template',$accepticon,'','',0,0,0);
		} else {
			print "&nbsp;";
		}
		if( $x->{'howmany'} == 0 ) {
			showminicommand('unused',$selecticon,'','',0,0,0);
                }
		print "</td>\n";

		print "<td>\n";
		if( checkuserrights('host') ) {
			print "<a $show>\n";
			print $x->{'title'};
			print "</a>\n";
		} else {
			print $x->{'title'};
		}

		print "</td>\n";

		print "<td>\n";
		print "by ".$x->{'howmany'}." documents";
		print "</td>\n";
		print "<td>\n";
		print "$x->{'updated'}";
		print "</td>\n";

		print "<td align='right'>";
		if( checkuserrights('host') ) {
			# a template can be deleted only if is not used by any document
			if( $x->{'howmany'} == 0 ) {
				showminicommand2('delete',$delicon,"Delete the template ".$x->{'title'}." ?",
				$myself."?mode=delete&amp;".$id,$current);
			}
			showminicommand('copy',$copyicon,
			$myself."?mode=copytpl&amp;".$id,$current,$winw,$winh,0);
		}

		print "</td>";
		print "</tr>\n";
	}
	print "</tbody>\n";
	print "</table>\n";

}

# show all the comments - special function that shows all the groups
# "flattened out". This way is easier to spot unapproved comments.
sub showcomments
{
	my ($hostid,$groupid,$documentid) = @_;

	# If I have selected a document show the comments on that document
	if( $documentid ) {
		showtherealcomment();
		return;
	}

	# width and height of the edit window
	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);

	# first of all, show all the groups
	my $q="select * from groups where hostid=? order by groupname asc";
	my $r=$dbh->prepare($q);
	$r->execute($hostid);
	my $col=0;
	my $total=0;

	print "<table width='100%' bgcolor='lightblue' border='0' cellspacing='0' cellpadding='5pt'>";
	print "<thead>\n";
	print "<th align='left'>Group</th>\n";
	print "<th align='left'># Docs</th>\n";
	print "<th align='left'># Comm</th>\n";
	print "<th align='left'>to approve</th>\n";
	print "</thead>\n";
	print "<tbody>\n";
	while( my $x=$r->fetchrow_hashref() ) {

		# count if the group has at least ONE document with comments enabled,
		# if not, then do not display the group.
		$q="select count(documentid) from documents where hostid=? and groupid=? and comments=true";
		my $rr=$dbh->prepare($q);
		$rr->execute($hostid,$x->{'groupid'});
		my ($cc)=$rr->fetchrow_array();
		if( $cc > 0 ) {

			# flag
			$total+=$cc;

			# who is the owner of this group?
			if( $x->{'author'} eq $userid ) {
				$isgroupowner='yes';
			} else {
				$isgroupowner='no';
			}
			
			# count numbers of documents per group
			$q='select count(documentid) from documents where hostid=? and groupid=?';
			my $rr=$dbh->prepare($q);
			$rr->execute($hostid,$x->{'groupid'});
			my ($numdocs)=$rr->fetchrow_array();
			# count numbers of documents to approve per group
			$q="select count(documentid) from documentscontent where hostid=? and groupid=? and approved=false";
			$rr=$dbh->prepare($q);
			$rr->execute($hostid,$x->{'groupid'});
			my ($numdocsta)=$rr->fetchrow_array();
	
			# count number of comments
			$q='select count(documentid) from comments where hostid=? and groupid=?';
			$rr=$dbh->prepare($q);
			$rr->execute($hostid,$x->{'groupid'});
			my ($numcomm)=$rr->fetchrow_array();
	
			# and number of comments to approve for open documents
			$q="select count(c.documentid) from comments c, documents d where c.hostid=? and c.groupid=? and c.approved=false ".
			"and c.hostid=d.hostid and c.documentid=d.documentid and c.groupid=d.groupid and d.comments=true";
			$rr=$dbh->prepare($q);
			$rr->execute($hostid,$x->{'groupid'});
			my ($numcommtoapprove)=$rr->fetchrow_array();
	
			# just to simplify the links
			my $show;
			if( $groupid eq $x->{'groupid'} ) {
				$show="javascript:execlink(\"".$myself."?current=".$current.
				"&amp;hostid=$hostid&amp;groupid=#".$x->{'groupid'}."\")";
			} else {
				$show="javascript:execlink(\"".$myself."?current=".$current.
				"&amp;hostid=$hostid&amp;groupid=".$x->{'groupid'}."#".$x->{'groupid'}."\")";
			}

			# now display the data
			print "<tr ";
			if( $col==1 ) {
				print "bgcolor='white'";
				$col=0;
			} else {
				$col=1;
			}
			print ">\n";
			print "<td class='msgtext'>";
			print "<a name='".$x->{'groupid'}."'>";
			print "<a href='".$show."' title='click to expand'>";
			print $x->{'groupname'};
			print "</a></a>\n";
			print "</td>\n";
			print "<td class='msgtext'>\n";
			print $numdocs . " documents ";
			if( $numdocsta > 0 ) {
				print " - ".$numdocsta . " to approve";
			}
			print "</td>\n";
	
			print "<td class='msgtext'>\n";
			print $numcomm . " comments ";
			print "</td>\n";
	
			print "<td class='msgtext'>\n";
			if($numcommtoapprove > 0) {
				print "<b>";
			}
			print $numcommtoapprove . " to approve.";
			if($numcommtoapprove > 0) {
				print "</b>";
			}
			
			print "</td>\n";
	
			print "<td align='right'>";
			print "</td>";
			print "</tr>\n";

		}

		# if the group is selected, show the documnts that belong to this group
		if( $groupid eq $x->{'groupid'} ) {

			# group selected, display the documents in this group.
			# ONLY if the document has comments enabled and the current user 
			# is the author or moderator or is root or the group's owner
			my $q=(q{
			select d.*,dc.title as title, dc.approved as approved, dc.language as language
			from documents d, documentscontent dc
			where 
			d.comments=true and dc.approved=true and
			d.hostid=dc.hostid and d.groupid=dc.groupid and d.documentid=dc.documentid 
			and d.groupid=? and d.hostid=?
			});

			# if I'm not the owner of the group, only authors or moderator can see the
			# document
			if( ! checkuserrights('group',$x->{'hostid'},$x->{'groupid'}) ) {
				$q.=" and (author=? or moderator=?)";
			}
			$q.=" order by documentid";

			my $r=$dbh->prepare($q);
			if( ! checkuserrights('group',$x->{'hostid'},$x->{'groupid'}) ) {
				$r->execute($groupid,$hostid,$userid,$userid);
			} else {
				$r->execute($groupid,$hostid);
			}

			# there could be that I don't have one single document to show,
			# in this case, there is no sense in going on...
			if( $r->rows > 0 ) {

				print "<tr><td colspan='5'>\n";
				print "<table width='100%' cellspacing='0' cellpadding='3' border='0'";
				print " bgcolor='lightgrey'>";
				print "<thead>\n";
				print "<th>&nbsp;</th>";
				print "<th align='left'>Title</th>\n";
				print "<th align='center'>Icon</th>\n";
				print "<th align='left'>Template</th>\n";
				print "<th align='left'>Css</th>\n";
				print "<th align='left'>Rss</th>\n";
				print "<th align='left'>Created</th>\n";
				print "<th align='left'>Updated</th>\n";
				print "<th align='center'>Comm/App</th>\n";
				print "<th>&nbsp;</th>\n";
				print "</thead>\n";
				print "<tbody>\n";
	
				my $color=0;
				my $did;
				my @languages;
	
				# loop on all the documents;
				while( my $x=$r->fetchrow_hashref() ) {
	
					if( ! $did ) {
						$did = $x ;
					}
	
					# I don't need the languages in the comments view, so I just
					# print ONCE the document's title.
					if ( $did->{'documentid'} ne $x->{'documentid'} ) {
						# show a line
						$color=showarowcomments($did,$color);
						$did=$x;
					}
	
				}
	
				# must still print the last record
				if( $did ) {
					showarowcomments($did,$color);
				}
				print "</tbody>\n";
				print "</table>\n";
				print "</td></tr>\n";
			}
		}
	}
	print "</tbody>\n";
	print "</table>\n";

	# now, If I don't have any document with comments, display a message to the user
	if( $total == 0 ) {
		print "<p class='msgtext'><center>";
		print "No document for this host is enabled for comments.";
		print "</center></p>";
	}
}

# Function used to display just the comments for approval
# NOTE: no checks are done in this function 'cause theoretically,
# this function SHOULD not be called directly but only throught
# the 'showcomments' or the 'showdocuments' functions where all
# the controls are... yes, I know that is not really nice.
sub showtherealcomment
{
	# width and height of the edit window
	my $winw=getconfparam('commedit-fw',$dbh);
	my $winh=getconfparam('commedit-fh',$dbh);
	my $level=0;

	# Check rights
	if( ! checkuserrights('comm',$hostid,$groupid,$documentid) ) {
		return;
	}

	my $link="?current=comments&amp;hostid=".$hostid."&amp;groupid=".$groupid.
	"&amp;documentid=".$documentid."&amp;commentid=";

	# add the 'update single comment' script
	print "<script>\n";
	print "function togapproved(commid,divid)\n";
	print "{\n";
	print " var xx=document.getElementById(divid);\n";
	print "\n";
	print " new Ajax.Request('".$myself."', {\n";
	print "         parameters: commid,\n";
	print "         method: 'post',\n";
	print "         onComplete:function( transport ) {\n";
	print "                 xx.innerHTML=transport.responseText;\n";
	print "         }\n";
	print " });\n";
	print "}\n";
	print "</script>\n";

	# print master table
	print "<table bgcolor='white' cellspacing='0' cellpadding='2' border='0' width='100%'>\n";
	print "<tbody>\n";

	# reminder for the icons and 'add a new comment' command
	print "<tr>\n";
	print "<td colspan='8' align='right'>\n";
	showminicommand('post new',$addicon,$postnew."?mode=new".$link,$current,$winw,$winh,0);
	print "</td>\n";
	print "</tr>\n";
	print "</tbody>\n";
	print "</table>\n";
	print "<hr>\n";

	# scan the comments and print them in a tree-like-fashion
	scancommentbyparentid(0,0);

}

# loop through the comments with a given parentid for threading
sub scancommentbyparentid
{
	my ($pid,$col)=@_;

	# search for all the comments with this parentid
	my $q="select c.hostid, c.groupid, c.documentid, c.commentid, ".
	"c.parentid, c.author, c.username, c.clientip, ".
	"to_char(c.created,'".$dateformat."') as created, ".
	"c.approved, c.title, c.content, c.spam, c.spamscore, ".
	"u.name, u.icon  from ".
	"comments c, users u ".
	"where ".
	"c.author=u.email and ".
	"hostid=? and groupid=? and documentid=?";

	# if parentid=0, then no parent id otherwise, the p.id CANNOT BE the same as the c.id.
	if( $pid != 0 ) {
		$q.=" and parentid=? and parentid<>commentid";
	} else {
		$q.=" and parentid=commentid";
	}
	$q.=" order by commentid asc";

	my $r=$dbh->prepare($q);
	if( $pid != 0 ) {
		$r->execute($hostid,$groupid,$documentid,$pid);
	} else {
		$r->execute($hostid,$groupid,$documentid);
	}

	while( my $c=$r->fetchrow_hashref() ) {
		$col=showasinglecomment($c,$col);
		# now let's process all the "children" comments
		$col=scancommentbyparentid($c->{'commentid'},$col);
	}

	$r->finish();
	return $col;

}

# Display one single comment - with search
sub showasinglecomment2
{
	# search for a single comment
	my $q="select c.hostid, c.groupid, c.documentid, c.commentid, ".
	"c.parentid, c.author, c.username, c.clientip, ".
	"to_char(c.created,'".$dateformat."') as created, ".
	"c.approved, c.title, c.content, c.spam, c.spamscore, ".
	"u.name, u.icon  from ".
	"comments c, users u ".
	"where ".
	"c.author=u.email and ".
	"hostid=? and groupid=? and documentid=? ".
	"and commentid=? and parentid=?";

	my $commentid=$query->param('commentid');
	my $parentid=$query->param('parentid');

	my $r=$dbh->prepare($q);
	$r->execute($hostid,$groupid,$documentid,$commentid,$parentid);
	my $c=$r->fetchrow_hashref();

	showasinglecomment($c,0);
	$r->finish();
	return;

}

# Display one single comment
sub showasinglecomment
{
	my ($c,$col)=@_;

	# width and height of the edit window
	my $winw=getconfparam('commedit-fw',$dbh);
	my $winh=getconfparam('commedit-fh',$dbh);

	# build a ref here
	my $cid="hostid=".$c->{'hostid'}."&amp;groupid=".$c->{'groupid'}.
		"&amp;documentid=".$c->{'documentid'}.
		"&amp;commentid=".$c->{'commentid'}.
		"&amp;parentid=".$c->{'parentid'};

	# Id for fast search
	my $id=$c->{'hostid'}."-".$c->{'groupid'}."-".$c->{'documentid'}."-".
		$c->{'commentid'}."-".$c->{'parentid'};

	print "<table bgcolor='white' cellspacing='0' cellpadding='2' border='0' width='100%' ";
	print " id='".$c->{'commentid'}.$c->{'parentid'}."'>";
	print "<tbody>\n";

	print "<tr valign='top' ";
	if( $c->{'spam'} ) {
		print " bgcolor='orange'";
	} elsif( ! $c->{'approved'} ) {
		print " bgcolor='gold'";
	} else {
		print " bgcolor='white'";
	}
	print ">\n";

	print "<td width='20%' align='center' class='user'>";
	print "<a name='".$id."'>";
	if($c->{'icon'} ne '') {
		print "<img src='".$avatardir."/".$c->{'icon'}."' width='24'><br>\n";
		print $c->{'username'};
	}
	print "</a>\n";
	print "</td>\n";
	print "<td width='80%'>";
	print "<div class='msgtitle'>".$c->{'title'}."</div><br>\n";
	print "<span class='msgdetails'>";
	print $c->{'username'};
	print " (";
	print $c->{'author'};
	print " : ";
	print $c->{'clientip'};
	print " ";
	print $c->{'spamscore'};
	print ") ";
	print $c->{'created'};
	print "</span>\n";
	print "<p>\n";

	# process and print the comment
	print processthecomment( $c->{'content'},$dbh);
	print "</td>\n";

	print "<td align='right' valign='top'>\n";

	#commands

	# editing and adding are done through another script, so only
	# approval goes through this.
	my $link="?current=comments&amp;hostid=".$c->{'hostid'}."&amp;groupid=".$c->{'groupid'}.
	"&amp;documentid=".$c->{'documentid'}."&amp;commentid=".$c->{'commentid'}.
	"&amp;parentid=".$c->{'parentid'};
	my $divid=$c->{'commentid'}.$c->{'parentid'};

	if( ! $c->{'approved'} ) {
		print "<img src='".$publishicon."' ".
		"alt='publish' title='publish' width='16pt' ".
		"onclick='javascript:togapproved(\"".$link."&mode=togapproved\",\"$divid\")' onmouseover='style.cursor=\"pointer\"'>\n";
	} else {
		print "<img src='".$unpublishicon."' ".
		"alt='unpublish' title='unpublish' width='16pt' ".
		"onclick='javascript:togapproved(\"".$link."&mode=togapproved\",\"$divid\")' onmouseover='style.cursor=\"pointer\"'>\n";
		#showminicommand('unpublish',$unpublishicon,
		#$myself.$link."&amp;mode=togapproved#".$id,$current,0,0,1)
	}

	# Edit comment
	showminicommand('edit',$editicon,
	$postnew.$link."&amp;mode=edit",$current,$winw,$winh,0);
	print "\n";

	# Permanently remove the comment
	showminicommand('delete',$delicon,
	$myself.$link."&amp;mode=delete#".$id,$current,0,0,1);
	print "\n";

	# Toggle spam status
	showminicommand('spam/nospam',$spamicon,
	$myself.$link."&amp;mode=spam#".$id,$current,0,0,1);
	print "\n";

	# Answer this comment
	showminicommand('reply',$replyicon,
	$postnew.$link."&amp;mode=new",$current,$winw,$winh,0);
	print "\n";

	print "</td>\n";
	print "</tr>\n";
	# separator
	print "<tr>\n";
	print "<td colspan='6'>\n";
	print "<hr>\n";
	print "</td>\n";
	print "</tr>\n";

	print "</tbody>\n";
	print "</table>\n";

	return $col;

}

# This function is used to show the comments on a specific document, called by the
# previous function.
sub showarowcomments
{
	my ($did,$color)=@_;

	my $preview=getconfparam('preview',$dbh);
	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);

	# count the number of comments and the number of comments to approve
	my $cta=0;
	my $cto=0;
	my $q=(q{
		select count(*) from comments where 
		hostid=? and groupid=? and documentid=? and approved=false
	});

	my $r=$dbh->prepare($q);
	$r->execute($did->{'hostid'},$did->{'groupid'},$did->{'documentid'});
	($cta)=$r->fetchrow_array();

	# just get all the comments now
	$q=(q{
		select count(*) from comments where 
		hostid=? and groupid=?
		and documentid=?
	});
	$r=$dbh->prepare($q);
	$r->execute($did->{'hostid'},$did->{'groupid'},$did->{'documentid'});
	($cto)=$r->fetchrow_array();

	# search one link for the preview
	$q='select link from links where hostid=? and groupid=? and documentid=?';
	my $x=$dbh->prepare($q);
	$x->execute($did->{'hostid'},$did->{'groupid'},$did->{'documentid'});
	my ($previewurl)=$x->fetchrow_array();
	$previewurl=$preview."?doc=".$previewurl."&amp;host=".$hostid;
	$x->finish();

	print "<tr ";
	if($cta > 0) {
		print " bgcolor='yellow' ";
	} else {
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
	}
	print ">\n";

	print "<td> &nbsp; </td>";
	print "<td align='left'>";
	print "<a href=\"javascript:openwindow('".$previewurl."','',1000,800)\">";
	print $did->{'title'};
	print "</a>\n";
	print "</td>\n";
	print "<td align='center'>";
	if( $did->{'icon'} ne 'none' && $did->{'icon'} ne '' ) {
		print showdocicon($did->{'icon'}," width='16px' height='16px'");
	}
	print "</td>\n";
	print "<td align='left'>";
	print $did->{'template'};
	print "</td>\n";
	print "<td align='left'>\n";
	print $did->{'css'};
	print "</td>\n";
	print "<td align='left'>\n";
	print $did->{'rssid'};
	print "</td>\n";
	print "<td align='left'>\n";
	print $did->{'created'};
	print "</td>\n";
	print "<td align='left'>\n";
	print $did->{'updated'};
	print "</td>\n";

	print "<td align='center'>\n";
	if( $cta > 0 ) {
		print "<b>";
	}
	print $cto."/".$cta;
	if( $cta > 0 ) {
		print "</b>";
	}
	print "</td>\n";
	print "<td align='right'>";

	if( checkuserrights('comm',$did->{'hostid'},$did->{'groupid'},$did->{'documentid'}) ) {

		my $icon='';
		my $text='';

		# toggle comments on or off
		my $link="&amp;current=comments&amp;hostid=".$did->{'hostid'}."&amp;groupid=".
			$did->{'groupid'}."&amp;documentid=".$did->{'documentid'};
		if($did->{'comments'}) {
			$text='click to close comments';
			$icon=$unlockicon;
		} else {
			$icon=$lockicon;
			$text='click to open comments';
		}
		showminicommand($text,$icon,$myself."?mode=togcomment".$link,$current,0,0,1);

		# show-manage comments
		my $link="?current=comments&amp;hostid=".$did->{'hostid'}."&amp;groupid=".
			$did->{'groupid'}."&amp;documentid=".$did->{'documentid'};
		showminicommand('show comments',$pviewicon,$myself.$link,$current,$winw,$winh,0);
	}

	print "</td>";
	print "</tr>\n";
	return $color;
}

# ========
# Show the default 'commands' (add, remove...) as a reminder
sub showc
{
	if( $userid eq 'NONE' || $current eq '' ) {
		return;
	}

	my $iconsdir=getconfparam('iconsdir',$dbh);

	my $wingw=getconfparam("groups-fw",$dbh);
	my $wingh=getconfparam("groups-fh",$dbh);

	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);

	if($winw eq '') { $winw=1000; }
	if($winh eq '') { $winh=1000; }

	print "<table width='100%' cellspacing='0' cellpadding='0' border='0'>\n";
	print "<tbody>\n";
	print "<tr bgcolor='lightgrey'>\n";
	print "<td align='left' width='90%' class='command'>\n";

	# delete is always there
	print "<img alt='delete' title='delete' src='".$delicon."'>";
	print "delete ";

	if( $current eq 'documents' ) {
		print "<img alt='publish' title='publish' src='".$publishicon."'>";
		print "<img alt='un-publish' title='un-publish' src='".$unpublishicon."'>";
		print " publish/unpublish ";
		print "<img alt='display' title='enable' src='".$enableicon."'>";
		print "<img alt='un-display' title='disable display' src='".$disableicon ."'>";
		print " enable/disable listing ";
		print "<img alt='enable comments' title='enable comments' src='".$commaddicon."'>";
		print "<img alt='disable comments' title='disable comments' src='".$commdelicon."'>";
		print " enable/disable comments ";
		print "<img alt='show comments' title='show comments' src='".$pviewicon."'>";
		print " show comments";
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy document";
	}
	if( $current eq 'users' ) {
		print "<img alt='promote to root' title='promote to root' src='".$upicon."'>";
		print " promote to root ";
		print "<img alt='demote to user' title='demote to root' src='".$downicon."'>";
		print " demote to user";
		print "<img alt='reset password' title='reset password' src='".$lockicon."'>";
		print " reset pwd ";
		print "<img alt='confirm' title='confirm' src='".$accepticon."'>";
		print " confirm user ";
		print "<img alt='disable' title='disable' src='".$userremoveicon."'>";
		print " disable user ";
	}
	if( $current eq 'hosts' ) {
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy ";
		print "<img alt='select' title='select' src='".$selecticon."'>";
		print " select current host ";
	}
	if( $current eq 'images' ) {
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy ";
	}
	if( $current eq 'groups' ) {
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy ";
	}
	if( $current eq 'feed' ) {
		print "<img alt='generate rss feed' title='generate rss feed' src='".$genrssicon."'>";
		print " generate rss feed ";
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy ";
	}
	if( $current eq 'templates' ) {
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy ";
	}
	if( $current eq 'texts' ) {
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy ";
	}
	if( $current eq 'fragments' ) {
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy ";
	}
	if( $current eq 'config' ) {
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy ";
	}
	if( $current eq 'comments' ) {
		print "<img alt='publish' title='publish' src='".$publishicon."'>";
		print "<img alt='un-publish comment' title='un-publish comment' src='".$unpublishicon."'>";
		print " publish/unpublish comment ";
		print "<img alt='edit' title='edit' src='".$editicon."'>";
		print " edit comment ";
		print "<img alt='reply' title='reply' src='".$replyicon."'>";
		print " reply ";
		print "<img alt='post new' title='post new' src='".$addicon."''>";
		print " post new ";
		print "<img alt='enable comment' title='enable comment' src='".$commaddicon."'>";
		print "<img alt='disable comment' title='disable comment' src='".$commdelicon."'>";
		print " open/close comments on the document - ";
		print "<img alt='show comments' title='show comments' src='".$pviewicon."'>";
		print " show comments for this document ";
	}
	if( $current eq 'css' ) {
		print "<img alt='copy' title='copy' src='".$copyicon."'>";
		print " copy ";
	}
	print "</td>\n";
	print "<td align='right' width='10%' class='command'>\n";
	if( hasadoc($userid) && $current eq 'images' ) {
		showminicommand('add image',$addicon,$myself."?current=".
		"images&amp;mode=addimage&amp;imageid=&amp;hostid=$hostid",$current,$winw,$winh,0);
	}
	if( checkuserrights('host') ) {
		if( $current eq 'documents' ) {
			# nothing to do here
		} elsif( $current eq 'templates' ) {
			showminicommand('add template',$addicon,$myself."?current=".
			"templates&amp;mode=addtpl&amp;hostid=$hostid&amp;templateid=&amp;language=",$current,$winw,$winh,0);
		} elsif( $current eq 'fragments' ) {
			showminicommand('add fragment',$addicon,$myself."?current=".
			"fragments&amp;mode=addfrag&amp;hostid=$hostid&amp;fragid=&amp;language=",$current,$winw,$winh,0);
		} elsif( $current eq 'texts' ) {
			showminicommand('add text',$addicon,$myself."?current=".
			"texts&amp;mode=addtext&amp;hostid=$hostid&amp;textid=&amp;language=",$current,$winw,$winh,0);
		} elsif( $current eq 'feed' ) {
			showminicommand('generate all',$rssicon,$myself."?current=".
			"feed&amp;mode=genrss&amp;rssid=-ALL&amp;hostid=$hostid",$current,0,0,1);
			showminicommand('add feed',$addicon,$myself."?current=".
			"feed&amp;mode=addrss&amp;rssid=&amp;hostid=$hostid",$current,$winw,$winh,0);
		} elsif( $current eq 'css' ) {
			showminicommand('add css',$addicon,$myself."?current=".
			"css&amp;mode=addcss&amp;hostid=$hostid&amp;textid=&amp;language=",$current,$winw,$winh,0);
		}
	}
	if( checkuserrights('root')) {
		if( $current eq 'hosts' ) {
			showminicommand('add host',$addicon,$myself."?current=".
			"hosts&amp;mode=addhost&amp;hostid=&amp;language=",$current,$winw,$winh,0);
		} elsif( $current eq 'users' ) {
			showminicommand('add new user',$addicon,"./edituser.pl?".
			"mode=adduser&amp;language=",$current,$winw,$winh,0);
		} elsif( $current eq 'config' ) {
			showminicommand('add param',$addicon,$myself."?current=".
			"config&amp;mode=addconf&amp;paramid=",$current,$winw,$winh,0);
		}
		print "</td>\n";
	}
	print "</tr>\n";
	print "</tbody>\n";
	print "</table>\n";

	return;
}

# =============================================
# show the edit group form
sub showeditgroupform
{

	my $r=shift;
	my $mode=shift;
	my $t;
	my $dociconsdir=getconfparam('dociconsdir',$dbh);

	if($mode eq 'NEW') {
		$t="Add a new"
	} else {
		$t="Edit"
	}

	print "<script>\n";
	print "function selicon(iconname)\n";
	print "{\n";
	print " if( iconname != 'none' ) {\n";
	print "   document.editdoc.ticon.value=iconname;\n";
	print "   document.getElementById('icon').src='" .$dociconsdir."/'+iconname;\n";
	print " }\n";
	print "}\n";
	print "</script>\n";

	print "<div class='tableheader'>".$t." Group</div>\n";

	# display the edit form
	print "<form action='".$myself."' method='post' name='editgroup'>\n";

	if($mode eq 'NEW') {
		print "<input type='hidden' name='mode' value='add'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
		print "<input type='hidden' name='groupid' value='".$r->{'groupid'}."'>\n";
	}
	print "<input type='hidden' name='parentid' value='".$r->{'parentid'}."'>\n";
	print "<input type='hidden' id='ticon' name='ticon' value='".$r->{'icon'}."'>\n";
	print "<input type='hidden' name='current' value='groups'>\n";
	print "<input type='hidden' name='hostid' value='".$r->{'hostid'}."'>\n";

	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";
	print "<tbody>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "name";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	print "<input type='text' size='30' name='groupname' value='".$r->{'groupname'}."'>";
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "template";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	seltemplate($r->{'template'});
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "css";
	print "</td>\n";
	print "<td class='msgtext' colspan='1'>\n";
	selcss($r->{'cssid'});
	print "</td>\n";

	print "<td class='msgtext' align='right'>\n";
	print "rss";
	print "</td>\n";
	print "<td class='msgtext' colspan='1'>\n";
	selrss($r->{'rssid'});
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "comments";
	print "</td>\n";
	print "<td class='msgtext' colspan='1'>\n";
	showoptions('comments',$r->{'comments'},0,('yes','no'));
	print "</td>\n";

	print "<td class='msgtext' align='right'>\n";
	print "moderated";
	print "</td>\n";
	print "<td class='msgtext' colspan='1'>\n";
	showoptions('moderated',$r->{'moderated'},0,('yes','no'));
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "owner";
	print "</td>\n";
	print "<td class='msgtext' colspan='1'>\n";
	if( $mode eq 'NEW' ){
		seluser('owner',$r->{'owner'});
	} else {
		if(checkuserrights('host')) {
			seluser('owner',$r->{'owner'});
		} else {
			print displayusername($r->{'owner'});
		}
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "default";
	print "</td>\n";
	print "<td class='msgtext' colspan='1'>\n";
	showoptions('isdefault',$r->{'isdefault'},0,('yes','no'));
	print "</td>\n";
	print "<tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "def.author";
	print "</td>\n";
	print "<td class='msgtext' colspan='1'>\n";
	seluser('author',$r->{'author'});
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "def.moderator";
	print "</td>\n";
	print "<td class='msgtext' colspan='1'>\n";
	seluser('moderator',$r->{'moderator'});
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td align='center'>\n";
	if( $r->{'icon'} ne 'none' && $r->{'icon'} ne '' ) {
		print "<img id='icon' name='icon' src='".$dociconsdir."/".$r->{'icon'}."'>\n";
	} else {
		print "<img id='icon' name='icon' src=''>\n";
	}
	print "</td>\n";
	print "<td colspan='3'>\n";
	print "<iframe name='icons' src='".$myself."?mode=showdocicons&hostid=".
	$r->{'hostid'}."&groupid=".$r->{'groupid'}."' height='90px' width='100%'>\n";
	print "</iframe>\n";
	print "</td>\n";
	print "</tr>\n";
	print "<tr>\n";
	print "<td colspan=4 class='msgtext' align='left'>\n";
	print "<input type='checkbox' name='rollout' unchecked> Changes on all the documents of this group.";
	print "</td>\n";
	print "</tr>\n";

	print "</tbody>\n";
	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='ok' ";
	print "onclick='javascript:document.editgroup.submit();'>\n";
	print "<input type='button' value='cancel' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";
	closehtml();

	return;
}

# show the edit css form
sub showeditcssform
{
	my $r=shift;
	my $mode=shift;
	my $t;

	if($mode eq 'NEW') {
		$t="Add a"
	} else {
		$t="Edit"
	}
	print "<div class='tableheader'>".$t." CSS</div>\n";

	# display the edit form

	print "<form action='".$myself."' method='post' name='editcss' ";
        print "enctype='multipart/form-data'>\n";

	if($mode eq 'NEW') {
		print "<input type='hidden' name='mode' value='add'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
		print "<input type='hidden' name='cssid' value='".$r->{'cssid'}."'>\n";
		print "<input type='hidden' name='filename' value='".$r->{'filename'}."'>\n";
	}
	
	print "<input type='hidden' name='current' value='css'>\n";
	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Description";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	print "<input type='text' size='60' name='description' value='".$r->{'description'}."'>";
	print "</td>\n";
	print "</tr>\n";

	if( $mode ne 'NEW' ) {
		# edit window available only if the css already exists
		my $wh=getconfparam('comments-fh',$dbh);
		my $ww=getconfparam('comments-fw',$dbh);
		print "<tr>";
		print "<td class='msgtext' align='right'>\n";
		print "<a href='javascript:openwindow(\"/cgi-bin/editdoc.pl?mode=edit&cssid=".$r->{'cssid'};
		print "&current=css\"";
		print ",\"Direct editor\",$ww,$wh)'>Edit CSS</a>\n";
		print "</td>\n";
		print "<td class='msgtext' align='left'>\n";
		print "<a href='".$myself."?mode=download&cssid=".$r->{'cssid'};
		print "&type=css&current=css'>Download&nbsp;text&nbsp;for&nbsp;update</a>\n";
		print "</td>\n";
		print "</tr>\n";
	}

	print "<tr>";
	print "<td class='msgtext' align='right'>\n";
	print "Upload new content: ";
	print "</td>\n";
	print "<td>\n";
	print "<input type='file' size='40' name='content'>\n";
	print "</td>\n";
	print "</tr>\n";

	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='ok' ";
	print "onclick='javascript:document.editcss.submit();'>\n";
	print "<input type='button' value='cancel' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";
	closehtml();
	return;
}

# show the edit host form
sub showedithostform
{
	my $r=shift;
	my $mode=shift;
	my $t;

	if($mode eq 'NEW') {
		$t="Add an"
	} else {
		$t="Edit"
	}
	print "<div class='tableheader'>".$t." Host</div>\n";

	# display the edit form
	print "<form action='".$myself."' method='post' name='edithost'>\n";

	if($mode eq 'NEW') {
		print "<input type='hidden' name='mode' value='add'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
		print "<input type='hidden' name='hostid' value='".$r->{'hostid'}."'>\n";
	}
	
	print "<input type='hidden' name='current' value='hosts'>\n";
	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "ID";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	if( $mode eq 'NEW' ) {
		print "<input type='text' size='30' name='hostid' value='".$r->{'hostid'}."'>";
	} else {
		print $r->{'hostid'};
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Created";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	print $r->{'created'};
	print "</td>\n";
	print "</tr>\n";
	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "css";
	print "</td>\n";
	print "<td class='msgtext' colspan='3'>\n";
	# CSS are stored in a separate table
	selcss($r->{'cssid'});
	print "</td>\n";
	print "</tr>\n";
	# Aliases are stored in a separate table, this means that you
	# can add Aliases only AFTER the host has been added...
	if( $mode ne 'NEW' ) {
		print "<tr valign='top'>\n";
		print "<td class='msgtext' align='right'>\n";
		print "Aliases";
		print "</td>\n";
		print "<td class='msgtext' colspan='3'>\n";
		print "<iframe name='aliases' src='".$myself."?mode=showhostaliases&amp;hostid=".
			$r->{'hostid'}."' height='90px' width='100%'>\n";
		print "</iframe>\n";
		print "</td>\n";
		print "</tr>\n";
	}

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Owner";
	print "</td>\n";

	print "<td class='msgtext' align='left'>\n";
	if( checkuserrights('root')) {
		seluser('owner',$r->{'owner'});
	} else {
		print displayusername($r->{'owner'});
	}
	print "</td>\n";

	print "<td class='msgtext' align='right'>\n";
	print "Def. language";
	print "</td>\n";

	print "<td class='msgtext'>\n";
	selectlang('deflang',$r->{'deflang'});
	print "</td>\n";

	print "</tr>\n";

	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='ok' ";
	print "onclick='javascript:document.edithost.submit();'>\n";
	print "<input type='button' value='cancel' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";
	closehtml();
	return;
}

# show the edit configuration parameter form
sub showeditconfigform
{

	my $r=shift;
	my $mode=shift;
	my $t;

	if($mode eq 'NEW') {
		$t="Add a";
	} else {
		$t="Edit";
	}
	print "<div class='tableheader'>".$t." Configuration Parameter</div>\n";

	# display the edit form
	print "<form action='".$myself."' method='post' name='editconf'>\n";

	if($mode eq 'NEW') {
		print "<input type='hidden' name='mode' value='add'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
		print "<input type='hidden' name='paramid' value='".$r->{'paramid'}."'>\n";
	}
	
	print "<input type='hidden' name='current' value='config'>\n";
	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "id";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	if( $mode eq 'NEW' ) {
		print "<input type='text' size='30' name='paramid' value='".
		$r->{'paramid'}."'>";
	} else {
		print $r->{'paramid'};
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "updated";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	print $r->{'updated'};
	print "</td>\n";
	print "</tr>\n";
	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "value";
	print "</td>\n";
	print "<td class='msgtext' colspan='4'>\n";
	print "<input type='text' size='60' name='value' value='".
	scrub($r->{'value'},$dbh)."'>";
	print "</td>\n";
	print "</tr>\n";
	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "description";
	print "</td>\n";
	print "<td class='msgtext' colspan='4'>\n";
	print "<input type='text' size='60' name='description' ";
	print "value='".scrub($r->{'description'},$dbh)."'>";
	print "</td>\n";
	print "</tr>\n";

	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='ok' ";
	print "onclick='javascript:document.editconf.submit();'>\n";
	print "<input type='button' value='cancel' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";
	closehtml();

	return;
}

# show the edit image form
sub showeditimageform
{

	my $r=shift;
	my $mode=shift;
	my $t;
	my $thumbdir=getconfparam('thumbdir',$dbh);

	if($mode eq 'NEW') {
		$t="Add a new"
	} else {
		$t="Edit"
	}
	print "<div class='tableheader'>".$t." Image</div>\n";
	print "Maximum size of picture: ".$imgmaxsize." Kb<br>\n";

	# display the edit form
	print "<form action='".$myself."' method='post' name='editimage' ";
	print "enctype='multipart/form-data'>\n";

	if($mode eq 'NEW') {
		print "<input type='hidden' name='mode' value='add'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
	}
	#print "<input type='hidden' name='imageid' value='".$r->{'imageid'}."'>\n";
	print "<input type='hidden' name='hostid' value='".$hostid."'>\n";
	print "<input type='hidden' name='current' value='".$current."'>\n";
	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Id";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	if($mode eq 'NEW') {
		print "<input type='text' name='imageid' value='".$r->{'imageid'}."' width='30' >\n";
	} else {
		print "<input type='hidden' name='imageid' value='".$r->{'imageid'}."'>\n";
		print $r->{'imageid'};
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Updated";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	if($mode ne 'NEW') {
		print $r->{'created'};
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Author";
	print "</td>\n";
	print "<td class='msgtext' colspan='3'>\n";
	print displayusername($r->{'author'});
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Filename:";
	print "</td>\n";
	print "<td class='msgtext' colspan='3'>\n";
	if($mode ne 'NEW') {
		print $r->{'filename'};
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "preview (click to enlarge)";
	print "</td>\n";
	print "<td class='msgtext' colspan='3'>\n";
	# show preview only if there is a picture
	if( $r->{'filename'} ne '' ) {
		print "<a href='javascript:openwindow(\"/img/".$hostid."/".$r->{'filename'}."\",\"\",1000,800)'>";
		print "<img src='/img/".$hostid."/".$thumbdir."/".$r->{'filename'}."' width='64'>";
		print "</a>";
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "upload new picture";
	print "</td>\n";
	print "<td class='msgtext' colspan='3'>\n";
	print "<input type='file' size='60' name='content'>\n";
	print "</td>\n";

	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='ok' ";
	print "onclick='javascript:document.editimage.submit();'>\n";
	print "<input type='button' value='cancel' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";
	closehtml();

	return;
}

# show the edit rss form
sub showeditrssform
{

	my $r=shift;
	my $mode=shift;
	my $t;

	if($mode eq 'NEW') {
		$t="Add a new"
	} else {
		$t="Edit"
	}
	print "<div class='tableheader'>".$t." RSS feed</div>\n";

	# display the edit form
	print "<form action='".$myself."' method='post' name='editrss'>\n";

	if($mode eq 'NEW') {
		print "<input type='hidden' name='mode' value='add'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
		print "<input type='hidden' name='filename' value='".$r->{'filename'}."'>\n";
	}
	print "<input type='hidden' name='hostid' value='".$hostid."'>\n";
	print "<input type='hidden' name='current' value='".$current."'>\n";
	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "filename";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	if( $mode eq 'NEW' ) {
		print "<input type='text' size='30' name='filename' value='".$r->{'filename'}."'>";
	} else {
		print $r->{'filename'};
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Last done";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	print $r->{'lastdone'};
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Language";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	if( $mode eq 'NEW' ) {
		selectlang('language',$r->{'language'});
	} else {
		print $r->{'language'};
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Author";
	print "</td>\n";
	print "<td class='msgtext' colspan='5'>\n";
	seluser('author',$r->{'author'});
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Subject";
	print "</td>\n";
	print "<td class='msgtext' colspan='5'>\n";
	print "<input type='text' size='60' name='subject' value='";
	print scrub($r->{'subject'},$dbh);
	print "'>";
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Title";
	print "</td>\n";
	print "<td class='msgtext' colspan='5'>\n";
	print "<input type='text' name='title' size='60' value='";
	print scrub($r->{'title'},$dbh);
	print "'>";
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Link";
	print "</td>\n";
	print "<td class='msgtext' colspan='5'>\n";
	print "<input type='text' size='60' name='link' value='";
	print scrub($r->{'link'},$dbh);
	print "'>";
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Copyright";
	print "</td>\n";
	print "<td class='msgtext' colspan='5'>\n";
	print "<input type='text' name='copyright' size='60' value='";
	print scrub($r->{'copyright'},$dbh);
	print "'>";
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Taxo";
	print "</td>\n";
	print "<td class='msgtext' colspan='5'>\n";
	if( $r->{'taxo'} eq '' ) {
		$r->{'taxo'} = ' ';
	}
	print "<input type='text' name='taxo' size='60' value='";
	print scrub($r->{'taxo'},$dbh);
	print "'>";
	print "</td>\n";
	print "</tr>\n";

	print "<tr valign='top'>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Description";
	print "</td>\n";
	print "<td class='msgtext' colspan='5'>\n";
	print "<textarea name='description' id='description' cols='80' rows='5'>\n";
	print scrub($r->{'description'},$dbh);
	print "</textarea>\n";
	print "</td>\n";
	print "</tr>\n";

	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='ok' ";
	print "onclick='javascript:document.editrss.submit();'>\n";
	print "<input type='button' value='cancel' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";
	closehtml();

	return;
}

# show the edit text window
sub showedittextform
{

	my $r=shift;
	my $mode=shift;
	my $t;

	if($mode eq 'NEW') {
		$t="Add a"
	} else {
		$t="Edit"
	}
	print "<div class='tableheader'>".$t." text</div>\n";

	# display the edit form
	print "<form action='".$myself."' method='post' name='edittpl'>\n";

	if($mode eq 'NEW') {
		print "<input type='hidden' name='mode' value='add'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
		print "<input type='hidden' name='textid' value='".$r->{'textid'}."'>\n";
		print "<input type='hidden' name='language' value='".$r->{'language'}."'>\n";
	}
	print "<input type='hidden' name='hostid' value='".$r->{'hostid'}."'>\n";
	print "<input type='hidden' name='current' value='texts'>\n";
	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "ID";
	print "</td>\n";
	print "<td class='msgtext' colspan='2'>\n";
	if( $mode eq 'NEW' ) {
		print "<input type='text' size='30' name='textid' value='".
		$r->{'textid'}."'>";
	} else {
		print $r->{'textid'};
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Language";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	if( $mode eq 'NEW' ) {
		selectlang('language',$r->{'language'});
	} else {
		print $r->{'language'};
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Content";
	print "</td>\n";
	print "<td class='msgtext' colspan='3'>\n";
	print "<input type='text' name='content' size='60' value='";
	print scrub($r->{'content'},$dbh);
	print "'>\n";
	print "</td>\n";
	print "</tr>\n";

	print "</tr>\n";

	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='ok' ";
	print "onclick='javascript:document.edittpl.submit();'>\n";
	print "<input type='button' value='cancel' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";

	closehtml();

	return;
}

# show the edit template window
sub showedittemplateform
{

	my $r=shift;
	my $mode=shift;
	my $t;

	if($mode eq 'NEW' || $mode eq 'COPY') {
		$t="Add a new "
	} else {
		$t="Edit"
	}
	print "<div class='tableheader'>".$t." template</div>\n";

	# display the edit form
	print "<form action='".$myself."' method='post' name='edittpl' ";
	print "enctype='multipart/form-data'>\n";

	if($mode eq 'NEW' ) {
		print "<input type='hidden' name='mode' value='add'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
		print "<input type='hidden' name='title' value='".$r->{'title'}."'>\n";
	}

	print "<input type='hidden' name='hostid' value='".$hostid."'>\n";
	print "<input type='hidden' name='current' value='templates'>\n";
	print "<input type='hidden' name='type' value='template'>\n";

	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "title";
	print "</td>\n";
	print "<td class='msgtext' colspan='1' align='left'>\n";
	if($mode ne 'NEW') {
		print $r->{'title'};
	} else {
		print "<input type='text' size='60' name='title' value='".$r->{'title'}."'>";
	}
	print "</td>\n";

	print "<td class='msgtext' align='right'>\n";
	print "default";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	showoptions('isdefault',$r->{'isdefault'},0,('yes','no'));
	print "</td>\n";
	print "</tr><tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Updated";
	print "</td>";
	print "<td class='msgtext' align='left' colspan='3'>\n";
	print $r->{'updated'};
	print "</td>\n";
	print "</tr>\n";

	print "</table>\n";
	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";

	if( $mode ne 'NEW' ) {
		# edit window available only if the document already exists,
		# otherwise it can't save!
		my $wh=getconfparam('comments-fh',$dbh);
		my $ww=getconfparam('comments-fw',$dbh);
		print "<tr>";
		print "<td class='msgtext' align='right'>\n";
		print "<a href='javascript:openwindow(\"/cgi-bin/editdoc.pl?mode=edit&hostid=".$r->{'hostid'};
		print "&templateid=".$r->{'title'}."&current=templates\"";
		print ",\"Direct editor\",$ww,$wh)'>Edit template</a>\n";
		print "</td>\n";
		print "<td colspan='2'></td>";
		print "</tr>\n";
	}
	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "<a href='".$myself."?mode=download&hostid=".$r->{'hostid'}."&templateid=".$r->{'title'};
	print "&language=".$r->{'language'};
	print "&type=template&current=templates'>Download&nbsp;text&nbsp;for&nbsp;update</a>\n";
	print "</td>\n";

	print "<td class='msgtext' align='right'>\n";
	print "Upload new content";
	print "</td>\n";
	print "<td colspan='2' class='msgtext'>\n";
	print "<input type='file' size='40' name='content'>\n";
	print "</td>\n";

	print "</tr>\n";

	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='apply' ";
	print "onclick='javascript:document.edittpl.submit();'>\n";
	print "<input type='button' value='close' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";

	closehtml();

	return;
}

# show the edit fragment window
sub showeditfragmentform
{

	my $r=shift;
	my $mode=shift;
	my $t;

	if($mode eq 'NEW') {
		$t="Add a new"
	} else {
		$t="Edit"
	}
	print "<div class='tableheader'>".$t." fragment</div>\n";

	# display the edit form
	print "<form action='".$myself."' method='post' name='editdoc' ";
	print "enctype='multipart/form-data'>\n";

	if($mode eq 'NEW') {
		print "<input type='hidden' name='mode' value='add'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
		print "<input type='hidden' name='fragid' value='".$r->{'fragid'}."'>\n";
		print "<input type='hidden' name='language' value='".$r->{'language'}."'>\n";
	}
	print "<input type='hidden' name='hostid' value='".$hostid."'>\n";
	print "<input type='hidden' name='current' value='fragments'>\n";
	print "<input type='hidden' name='type' value='fragment'>\n";

	print "<table bgcolor='lightgrey' width='100%' border='0' cellspacing='0' cellpadding='2'>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "id:";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	if( $mode eq 'NEW' ) {
		print "<input type='text' size='60' name='fragid' value='".$r->{'fragid'}."'>";
	} else {
		print $r->{'fragid'};
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "language:";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	if( $mode eq 'NEW' ) {
		selectlang('language',$r->{'language'});
	} else {
		print $r->{'language'};
	}
	print "</td>\n";
	print "</tr>\n";

	print "</table>";
	print "<table bgcolor='lightgrey' width='100%' border='0' cellspacing='0' cellpadding='2'>\n";

	if( $mode ne 'NEW' ) {	
		# edit window available only if the fragment already exists...
		my $wh=getconfparam('comments-fh',$dbh);
		my $ww=getconfparam('comments-fw',$dbh);
		print "<tr>";
		print "<td class='msgtext' align='right'>\n";
		print "<a href='javascript:openwindow(\"/cgi-bin/editdoc.pl?mode=edit&hostid=".$r->{'hostid'};
		print "&fragid=".$r->{'fragid'}."&language=".$r->{'language'}."&current=fragments\"";
		print ",\"Direct editor\",$ww,$wh)'>Edit fragment</a>\n";
		print "</td>\n";
		print "<td colspan='2'></td>";
		print "</tr>\n";
	}
	
	print "<tr>\n";
	print "<td colspan='2' class='msgtext' align='left'>\n";
	print "<a href='".$myself."?mode=download&hostid=".$r->{'hostid'}."&fragid=".$r->{'fragid'};
	print "&language=".$r->{'language'};
	print "&current=fragments'>Download text for update</a>\n";
	print "</td>\n";

	print "<td class='msgtext' align='left'>\n";
	print "upload new content:";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	print "<input type='file' size='40' name='content'>\n";
	print "</td>\n";

	print "</tr>\n";

	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='ok' ";
	print "onclick='javascript:document.editdoc.submit();'>\n";
	print "<input type='button' value='cancel' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";

	closehtml();

	return;
}

# Show the host's aliases list
sub showhostaliases
{
	my $hostid=shift;
	my $msg=shift;

	my $color=0;
	my $formname='';
	my $no='';

	$no=$myself."?mode=showhostaliases&hostid=".$hostid;

	my $s=$dbh->prepare('select alias from hostaliases where hostid=?');
	$s->execute($hostid);

	# initialize html page
	printheader($dbh);

	if( $msg ne '' ) {
		warning($msg);
	}
	print "<body bgcolor='white'>\n";

	print "<table width='100%' cellspacing='0' cellpadding='0' bgcolor='white'>\n";

	if( $debug ) {
		print "Showing aliases for host $hostid<br>\n";
	}

	while( my $r=$s->fetchrow_hashref() ) {
		$formname=$myself."?mode=delhostalias&hostid=".$hostid."&alias=".$r->{'alias'};
		if( $color==1 ) {
			print "<tr bgcolor='lightgrey'>\n";
			$color=0;
		} else {
			print "<tr bgcolor='white'>\n";
			$color=1;
		}
		print "<td>\n";
		print $r->{'alias'}."<br>\n";
		print "</td>\n";
		if( checkuserrights('host',$hostid)) {
			print "<td align='right' width='10%'>\n";
			print "<img src='".$delicon."' alt='Remove alias' title='remove alias' width='16pt' ";
			print "onclick='askconfirm(\"Remove alias ".$r->{'alias'}."?\",\"$formname\",\"$no\")' ";
			print "onmouseover=\"style.cursor='pointer'\">";
			print "&nbsp;";
			print "</td>\n";
		}
		print "</tr>\n";
	}
	$s->finish();

	# Form to add a new alias
	if( checkuserrights('host',$hostid)) {
		print "<form name='addalias' id='addalias' action='".$myself."'>\n";
		print "<input type='hidden' name='mode' value='addhostalias'>\n";
		print "<input type='hidden' name='hostid' value='".$hostid."'>\n";
		print "<tr bgcolor='yellow'>\n";
		print "<td>\n";
		print "<input type='text' value='add new' name='alias' bgcolor='yellow' size='80'>\n";
		print "</td>\n";
		print "<td align='right' width='10%'>\n";
		showminicommand('Add alias',$addicon,"javascript:document.addalias.submit()",$current,0,0,0);
		print "</td>\n";
		print "</tr>\n";
		print "</form>\n";
	}

	print "</table>\n";

	print "</body>\n";
	print "</html>\n";

}

# Show the document's icons list
sub showdocumenticons
{
	my $basedir=getconfparam('base',$dbh);
	my $iconsdir=getconfparam('dociconsdir',$dbh);
	my $file;
	my $icon;

	if( $documentid ne '' ) {
		my $s=$dbh->prepare('select icon from documents where hostid=? and documentid=? and groupid=?');
		$s->execute($hostid,$documentid,$groupid);
		($icon)=$s->fetchrow_array();
	} else {
		$icon='';
	}

	$iconsdir="/".$iconsdir."/";
	$iconsdir=~s/\/\//\//g;
	my $scandir=$basedir."/".$iconsdir."/";
	$scandir=~s/\/\//\//g;

	print "<html>\n";
	print "<script>\n";
	print "function selicon(iconname)\n";
	print "{\n";
	print "parent.document.getElementById('ticon').value=iconname;\n";
	print "parent.document.getElementById('icon').src=iconname;\n";
	print "}\n";
	print "</script>\n";
	print "<body>\n";

	if( $debug ) {
		print "Showing icons from $iconsdir, current icon is '".$icon."'...<br>\n";
	}

	# show all the possible icons for a document, highlight the current one
	opendir(DIR,$scandir);
	while($file=readdir(DIR)) {
		# take only PNG graphics
		$file=$iconsdir."/".$file;
		$file=~s/\/\//\//g;
	        if( $file =~ /\.png$/ ) {
	                print "<img src='".$file."' ";
			print "onmouseover=\"style.cursor='pointer'\" ";
			print "onclick=\"selicon('".$file."')\"> ";
		}
	}
	print "</body>\n";
	print "</html>\n";

}

# display the edit a document form
sub showeditdocumentform
{
	my ($r,$mode)=@_;
	my $t;

	my $iconsdir=getconfparam('dociconsdir',$dbh);
	my $buttondir=getconfparam('buttondir',$dbh);

	$buttondir=~s/\/$//;
	$iconsdir=~s/\/$//;

	if($mode eq 'NEW' || $mode eq 'COPY') {
		$t="Add a new";
	} else {
		$t="Edit";
	}

	# script to show/select the icon
	print "<script>\n";
	print "function selicon(iconname)\n";
	print "{\n";
	print " document.editdoc.ticon.value=iconname;\n";
	print " document.getElementById('icon').src='" .$iconsdir."/'+iconname;\n";
	print "}\n";
	print "</script>\n";

	print "<div class='tableheader'>\n";
	print "<div style='float:left'>".$t." document </div>\n";

	# if is NOT a new document, show the preview 'button'
	if($mode ne 'NEW') {
	
		# get a link to show the preview
		my $q='select link from links where hostid=? and groupid=? and documentid=?';
		my $x=$dbh->prepare($q);
		$x->execute($r->{'hostid'},$r->{'groupid'},$r->{'documentid'});
		my ($previewurl)=$x->fetchrow_array();
		$x->finish();

		print "<div style='float: right' onclick='";
		print "openwindow(\"".$preview."?doc=".$previewurl.
		"&amp;host=".$r->{'hostid'}."&amp;language=".$r->{'language'}."\",\"\",1000,800)'";
		print " onmouseover=\"style.cursor='pointer'\">";
		print "<img src='";
		print $buttondir."/".getconfparam('previewicon',$dbh);
		print "' alt='click for preview' title='click for preview'>\n";
		print "</div>\n";
	}
	print "</div>\n";

	# display the edit form
	print "<form action='".$myself."' method='post' name='editdoc' ";
	print "enctype='multipart/form-data'>\n";

	print "<input type='hidden' name='current' value='documents'>\n";
	print "<input type='hidden' name='type' value='document'>\n";
	print "<input type='hidden' id='ticon' name='ticon' value='".$r->{'icon'}."'>\n";
	print "<input type='hidden' name='hostid' value='".$r->{'hostid'}."'>\n";
	print "<input type='hidden' name='groupid' value='".$r->{'groupid'}."'>\n";
	print "<input type='hidden' name='documentid' value='".$r->{'documentid'}."'>\n";

	if($mode eq 'NEW' ) {
		print "<input type='hidden' name='mode' value='add'>\n";
	} elsif( $mode eq 'COPY') {
		print "<input type='hidden' name='mode' value='copy'>\n";
	} else {
		print "<input type='hidden' name='mode' value='edit'>\n";
		print "<input type='hidden' name='oldlanguage' value='".$r->{'language'}."'>\n";
	}

	print "<table bgcolor='lightgrey' width='100%' ";
	print "border='0' cellspacing='0' cellpadding='3'>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Title";
	print "</td>\n";
	print "<td class='msgtext' colspan='5'>\n";
	print "<input type='text' size='80' width='80' name='title' id='title' value='";
	print scrub($r->{'title'},$dbh);
	print "'>";
	print "</td>\n";
	print "<td class='msgtext' colspan='2' align='left'>\n";
	# the language can be changed if it is not a new document.
	# This allow to add a document of a different language if the document didn't existed
	if( $mode eq 'NEW' || $mode eq 'COPY' ) {
		selectlang('language',$r->{'language'});
	} else {
		selectlang('language',$r->{'language'});
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Template";
	print "</td>\n";
	print "<td class='msgtext' colspan='2'>\n";
	if( $mode ne 'COPY' ) {
		seltemplate($r->{'template'});
	} else {
		print $r->{'template'};
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "RSS Feed";
	print "</td>\n";
	print "<td class='msgtext' colspan='2'>\n";
	if( $mode ne 'COPY' ) {
		selrss($r->{'rssid'});
	} else {
		print $r->{'rssid'};
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "CSS";
	print "</td>\n";
	print "<td class='msgtext' colpan='5'>\n";
	if( $mode ne 'COPY' ) {
		selcss($r->{'cssid'});
	} else {
		print $r->{'cssid'};
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Author";
	print "</td>\n";
	print "<td class='msgtext' colspan='2'>\n";
	if( $mode ne 'COPY' ) {
		seluser('author',$r->{'author'});
	} else {
		seluser('author',$r->{'author'},1);
	}
	print "</td>\n";

	print "<td class='msgtext' align='right'>\n";
	print "Moderator";
	print "</td>\n";

	print "<td class='msgtext' colspan='2'>\n";
	if( $mode ne 'COPY' ) {
		seluser('moderator',$r->{'moderator'});
	} else {
		seluser('moderator',$r->{'moderator'},1);
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Created";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	print $r->{'created'};
	print "</td>\n";


	print "<td class='msgtext' align='right'>\n";
	print "Updated";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	print $r->{'updated'};
	print "</td>\n";

	print "<td class='msgtext' align='right'>\n";
	if( $mode eq 'NEW' ) {
		print "<input name='upd' type='hidden' value='checked'>";
	} else {
		print "Update published date ";
		print "</td>\n";
		print "<td align='left'>";
		print "<input name='upd' type='checkbox' ".$r->{'upd'}.">";
	}
	print "</td>\n";

	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Approved";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	showoptions('approved',$r->{'approved'},0,('yes','no'));
	print "</td>\n";

	print "<td class='msgtext' align='right'>\n";
	print "Display";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	if( $mode ne 'COPY' ) {
		showoptions('display',$r->{'display'},0,('yes','no'));
	} else {
		showoptions('display',$r->{'display'},1,('yes','no'));
	}
	print "</td>\n";

	print "<td class='msgtext' align='right'>\n";
	print "Comments";
	print "</td>\n";
	print "<td class='msgtext' align='left'>\n";
	if( $mode ne 'COPY' ) {
		showoptions('comments',$r->{'comments'},0,('yes','no'));
	} else {
		showoptions('comments',$r->{'comments'},1,('yes','no'));
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Moderated";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	if( $mode ne 'COPY' ) {
		showoptions('moderated',$r->{'moderated'},0,('yes','no'));
	} else {
		showoptions('moderated',$r->{'moderated'},1,('yes','no'));
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "default";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	if( $mode ne 'COPY' ) {
		showoptions('isdefault',$r->{'isdefault'},0,('yes','no'));
	} else {
		showoptions('isdefault',$r->{'isdefault'},1,('yes','no'));
	}
	print "</td>\n";
	print "<td class='msgtext' align='right'>\n";
	print "404 (not found)";
	print "</td>\n";
	print "<td class='msgtext'>\n";
	if( $mode ne 'COPY' ) {
		showoptions('is404',$r->{'is404'},0,('yes','no'));
	} else {
		showoptions('is404',$r->{'is404'},1,('yes','no'));
	}
	print "</td>\n";
	print "</tr>\n";

	print "<tr valign='top'>\n";
	print "<td class='msgtext' align='right'>\n";
	print "Excerpt";
	print "</td>\n";
	print "<td class='msgtext' colspan='5'>\n";
	print "<textarea name='excerpt' id='excerpt' cols='80' rows='4'>";
	print $r->{'excerpt'};
	print "</textarea>\n";

	# enable Editor
	print "<script type='text/javascript'>\n";
	print "CKEDITOR.on( 'instanceReady', function(ev)\n";
	print "{ev.editor.dataProcessor.writer.setRules('p',{class: doctext, indent: false, breakBeforeOpen: false, breakAfterOpen: false,";
	print "breakBeforeClose: false, breakAfterClose:false});\n";
	print "})\n";
	print "CKEDITOR.replace('excerpt',\n";
	print "{ toolbar: [['Source','Bold','Italic','Underline','Smiley','Image']], startupMode: 'wysiwyg', ";
	print "width: '100%', height:'50',";
	print "keystrokes: [[ CKEDITOR.CTRL+66, 'bold' ],[ CKEDITOR.CTRL+73, 'italic' ],";
	print "[ CKEDITOR.CTRL+85, 'underline' ],[CKEDITOR.CTRL+83,'smiley']";
	print ",[CKEDITOR.CTRL+74,'image']]});\n";
	print "</script>\n";

	print "</td>\n";
	print "</tr>\n";
	
	print "<tr>\n";
	print "<td align='center'>\n";
	if( $r->{'icon'} ne 'none' ) {
		print showdocicon($r->{'icon'},"id='icon' name='icon'");
	} else {
		print "<img id='icon' name='icon' src=''>\n";
	}
	print "</td>\n";
	print "<td colspan='5'>\n";
	print "<iframe name='icons' src='".$myself."?mode=showdocicons&amp;groupid=".
		$r->{'groupid'}."&amp;documentid=".
		$r->{'documentid'}."&amp;language=".
		$r->{'language'}."' height='90px' width='100%'>\n";
	print "</iframe>\n";
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";

	if( $mode ne 'NEW' ) {
   		# Links are only available if the document already exists.
		print "<td class='msgtext' align='right' valign='top'		>\n";
		print "Links:";
		print "</td>\n";
		print "<td class='msgtext' align='left' valign='top' colspan='5'>\n";
		print "<iframe name='doclinks' src='".$myself."?mode=showdoclinks&amp;hostid=".$r->{'hostid'};
		print "&amp;groupid=".$r->{'groupid'}."&amp;documentid=".$r->{'documentid'}. "' ";
		print "height='100px' width='100%'>\n";
		print "</iframe>\n";
		print "</td>\n";
		print "</tr>\n";

   		# Editing window only available if the document already exists.
		my $wh=getconfparam('comments-fh',$dbh);
		my $ww=getconfparam('comments-fw',$dbh);
		print "<tr>\n";
		print "<td colspan='2' class='msgtext'>\n";

		print "<a href='javascript:openwindow(\"/cgi-bin/editdoc.pl?mode=";
		print "&amp;hostid=".$r->{'hostid'}."&groupid=".$r->{'groupid'};
		print "&amp;documentid=".$r->{'documentid'}."&amp;language=".$r->{'language'};
		print "&amp;current=documents\"";
		print ",\"Direct editor\",$ww,$wh)'>Edit Document</a><br>\n";

		print "<a href='".$myself."?mode=download&amp;hostid=".$r->{'hostid'}."&groupid=".$r->{'groupid'};
		print "&amp;documentid=".$r->{'documentid'}."&language=".$r->{'language'};
		print "&amp;current=documents'>Download text for update</a>\n";
		print "</td>\n";

	} else {
		print "<td>\n";
		print "&nbsp;";
		print "</td>\n";
	}

	print "<td class='msgtext' align='right' colspan='2'>\n";
	print "Upload new content";
	print "</td>\n";
	print "<td colspan='2' class='msgtext' align='left'>\n";
	print "<input type='file' name='content'>\n";
	print "</td>\n";

	print "</tr>\n";

	print "</table>\n";
	print "<hr>\n";

	print "<input type='button' value='apply' ";
	print "onclick='javascript:document.editdoc.submit();'>\n";
	print "<input type='button' value='close' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</form>\n";

	closehtml($msg);

	return;
}

# copy an host
sub copyhost
{
	my ($hostid) = @_;

	my $q='select * from hosts where hostid=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid);
	my $r=$x->fetchrow_hashref();
	showedithostform($r,'NEW');
	return;
}

# edit a css
sub editcss
{
	my $cssid = shift;

	my $q='select * from css where cssid=?';
	my $x=$dbh->prepare($q);
	$x->execute($cssid);
	my $r=$x->fetchrow_hashref();

	showeditcssform($r);
	return;
}

# edit an host
sub edithost
{
	my ($hostid) = @_;

	my $q='select * from hosts where hostid=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid);
	my $r=$x->fetchrow_hashref();
	showedithostform($r);
	return;
}

# copy a group
sub copygroup
{
	my ($hostid,$groupid) = @_;

	my $q='select * from groups where hostid=? and groupid=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$groupid);
	my $r=$x->fetchrow_hashref();

	showeditgroupform($r,'NEW');
	return;
}

# edit a group
sub editgroup
{
	my ($hostid,$groupid) = @_;

	my $q='select * from groups where hostid=? and groupid=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$groupid);
	my $r=$x->fetchrow_hashref();

	showeditgroupform($r);
	return;
}

# copy a configuration parameter
sub copyconf
{
	my ($paramid) = @_;

	my $q="select paramid,description,to_char(updated,'".$dateformat."') as updated,value from configuration where paramid=?";
	my $x=$dbh->prepare($q);
	$x->execute($paramid);
	my $r=$x->fetchrow_hashref();
	$r->{'paramid'}='';

	showeditconfigform($r,'NEW');
	return;
}

# edit a configuration parameter
sub editconf
{
	my ($paramid) = @_;

	my $q="select paramid,description,to_char(updated,'".$dateformat."') as updated,value from configuration where paramid=?";
	my $x=$dbh->prepare($q);
	$x->execute($paramid);
	my $r=$x->fetchrow_hashref();

	showeditconfigform($r);
	return;
}

# copy an image to a different host
sub copyimage
{
	my ($hostid,$imageid) = @_;

	my $q='select * from images where hostid=? and imageid=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$imageid);
	my $r=$x->fetchrow_hashref();

	showeditimageform($r,'NEW');
	return;
}

# edit an image
sub editimage
{
	my ($hostid,$imageid) = @_;

	my $q='select * from images where hostid=? and imageid=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$imageid);
	my $r=$x->fetchrow_hashref();

	showeditimageform($r);
	return;
}

# copy an rss
sub copyrss
{
	my ($hostid,$rssid) = @_;

	my $q='select * from rssfeeds where filename=? and hostid=?';
	my $x=$dbh->prepare($q);
	$x->execute($rssid,$hostid);
	my $r=$x->fetchrow_hashref();

	showeditrssform($r,'NEW');
	return;
}

# edit a rss
sub editrss
{
	my ($hostid,$rssid) = @_;

	my $q='select * from rssfeeds where hostid=? and filename=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$rssid);
	my $r=$x->fetchrow_hashref();

	showeditrssform($r);
	return;
}

# copy a text
sub copytext
{
	my ($hostid,$textid,$language) = @_;

	my $q='select * from deftexts where hostid=? and textid=? and language=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$textid,$language);
	my $r=$x->fetchrow_hashref();

	showedittextform($r,'NEW');
	return;
}

# edit a text
sub edittext
{
	my ($hostid,$textid,$language) = @_;

	my $q='select * from deftexts where hostid=? and textid=? and language=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$textid,$language);
	my $r=$x->fetchrow_hashref();

	showedittextform($r);
	return;
}

# copy a fragment
sub copyfragment
{
	my ($hostid,$fragid,$language) = @_;

	my $q='select * from fragments where hostid=? and fragid=? and language=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$fragid,$language);
	my $r=$x->fetchrow_hashref();

	showeditfragmentform($r,'NEW');
	return;
}

# edit a fragment
sub editfragment
{
	my ($hostid,$fragid,$language) = @_;

	my $q='select * from fragments where hostid=? and fragid=? and language=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$fragid,$language);
	my $r=$x->fetchrow_hashref();

	showeditfragmentform($r);
	return;
}

# copy a template
sub copytemplate
{
	my ($hostid,$templateid) = @_;

	my $q='select content from templates where hostid=? and title=?';
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$templateid);
	my $r=$x->fetchrow_hashref();
	$r->{'hostid'}=$hostid;
	$r->{'title'}='';
	$r->{'updated'}='';
	$r->{'isdefault'}='yes';

	showedittemplateform($r,'NEW');
	return;
}

# edit a template
sub edittemplate
{
	my ($hostid,$templateid) = @_;

	if( ! $query->param('templateid') ) {
		$templateid=$query->param('title');
	}

	my $q="select hostid,title,content,isdefault,to_char(updated,'".$dateformat."') as updated from templates where hostid=? and title=?";
	my $x=$dbh->prepare($q);
	$x->execute($hostid,$templateid);
	my $r=$x->fetchrow_hashref();

	showedittemplateform($r);
	return;
}

# copy a document
sub copydocument
{
	my ($hostid,$groupid,$documentid) = @_;

	my $q="select  ".
		"d.hostid, d.groupid, d.documentid, d.template, d.cssid,".
		"d.icon, d.rssid, d.author, d.moderator, d.moderated,".
		"d.comments, d.isdefault, d.is404, d.display, d.created,".
		"d.updated, c.language, c.title, c.excerpt, c.content, c.approved ".
		"from documents d, documentscontent c where ".
		"d.hostid=c.hostid and d.groupid=c.groupid and d.documentid=c.documentid and ".
		"d.hostid=? and d.groupid=? and d.documentid=? and c.language=?";

	my $x=$dbh->prepare($q);

	$x->execute($hostid,$groupid,$documentid,$language);
	my $r=$x->fetchrow_hashref();

	# by default, DO NOT update date
	if( $query->param('upd') ) {
		$r->{'upd'}=$query->param('upd');
	} else {
		$r->{'upd'}='unchecked';
	}

	showeditdocumentform($r,'COPY');
	return;

}

# import a document into the group, copying it from another group.
sub importdocument
{
	my ($hostid,$groupid) = @_;

	my ($hostid,$groupid)=@_;
	my $srcgrp=$query->param('srcgrp');
	my $srcdoc=$query->param('srcdoc');
	my $ref="?current=documents&hostid=".$hostid."&groupid=".$groupid."&mode=import&type=document";

	print "<script>\n";
	print "function searchdocs()\n";
	print "{\n";
	print " var dest=document.getElementById('srcgrp');\n";
	print " window.location='".$myself.$ref."&srcgrp='+dest.value;\n";
	print "}\n";
	print "function seldoc()\n";
	print "{\n";
	print " var srcgrp=document.getElementById('srcgrp');\n";
	print " var srcdoc=document.getElementById('srcdoc');\n";
	print " window.location='".$myself.$ref."&srcgrp='+srcgrp.value+'&srcdoc='+srcdoc.value;\n";
	print "}\n";
	print "function doimport()\n";
	print "{\n";
	print " var srcgrp=document.getElementById('srcgrp');\n";
	print " var srcdoc=document.getElementById('srcdoc');\n";
	print " var impcomm=document.getElementById('impcomm');\n";
	print " var override=document.getElementById('override');\n";
	print " window.location='".$myself.$ref."&srcgrp='+srcgrp.value+'&srcdoc='+srcdoc.value+'&impcomm='+impcomm.value+'&override='+override.value+'&opt=do';\n";
	print "}\n";
	print "</script>\n";

	if( $query->param('opt') eq 'do' ) {
		# do the import
		print "<script>\n";
		doimportdocument($hostid,$groupid);
		print "closeandrefresh();\n";
		print "</script>\n";
	} else {
		# display form

		print "<div class='tableheader'>\n";
		print "<div style='float:left'> Import a document </div>\n";
		print "</div>\n";

		print "<div style='background: lightgrey; height: 300px; padding: 10px;'>\n";
		print "<form name='groups' id='groups' action='".$myself."' method='post'>\n";
		print "<p>\n";
		print "Select the group from which you want to import a document from the list below:<br>";
		print "Group: ";
		print "<select name='srcgrp' id='srcgrp' ";
		print "onChange='javascript:searchdocs()'>\n";
		my $q='select groupid,groupname from groups where hostid=? and groupid != ? order by groupname asc';
		my $s=$dbh->prepare($q);
		$s->execute($hostid,$groupid);
		while( my $r=$s->fetchrow_hashref() ) {
			print "<option value='".$r->{'groupid'}."'";
			if( $srcgrp eq $r->{'groupid'} ) {
				print " selected";
			}
			print ">".$r->{'groupname'}."\n";
		}
		$s->finish();
		print "</select>\n";
		print "</p>\n";
	
		if( $srcgrp ne '' ) {
			print "<p>\n";
			print "Select the document you want to import from the list below:<br>\n";
			$q='select dc.title, dc.language, dc.documentid, dc.groupid, d.updated '.
			'from documents d,documentscontent dc '.
			'where d.hostid=? and d.groupid=? and '.
			'dc.hostid=d.hostid and dc.groupid=d.groupid and '.
			'dc.approved=true order by dc.title asc';
	
			$s=$dbh->prepare($q);
			$s->execute($hostid,$srcgrp);
			print "<select name='srcdoc' id='srcdoc' ";
			print "onChange='javascript:seldoc()'>\n";
			my $olddoc='';
			while( my $r=$s->fetchrow_hashref() ) {
				if( $olddoc != $r->{'documentid'}) {
					print "<option value='".$r->{'documentid'}."'";
					if ( $r->{'documentid'} == $srcdoc ) {
						print " selected ";
					}
					print ">";
					print $r->{'title'};
					print "\n";
					$olddoc=$r->{'documentid'};
				}
			}
			print "</select>\n";
			print "</p>\n";
	
			if( $srcdoc ne '' ) {
				print "<p>\n";
				print "Import comments from the document <input type='checkbox' id='impcomm' name='impcomm' unchecked><br>\n";
				print "Impost group default <input type='checkbox' id='override' name='override' checked><br>\n";
				print "</p>\n";
				print "<p>\n";
	
				print "<input type='button' value='import selected document' ";
				print "onclick='javascript:doimport();'>\n";
			}
		}
		print "</form>\n";
	}
	print "<input type='button' value='close' ";
	print "onclick='javascript:closeandrefresh();'>\n";
	print "</p>\n";
	print "</div>\n";
	return;
}

# import the document
sub doimportdocument
{
	my ($hostid,$groupid) = @_;
	my $srcgrp=$query->param('srcgrp');
	my $srcdoc=$query->param('srcdoc');
	my $comm=$query->param('impcomm');
	my $over=$query->param('override');

	# query to insert the data
	my $q1="insert into documents ".
		"(hostid, groupid, documentid, template, cssid,".
		"icon, rssid, author, moderator, moderated, comments,display) values".
		"(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
	my $q2="insert into documentscontent ".
		"(hostid, groupid, documentid, language,".
		"title, excerpt, approved, content) ".
		"values (?, ?, ?, ?, ?, ?, ?, ?)";

	# first of all, get the data from the source document
	my $q="select  ".
		"d.template, d.cssid, d.icon, d.rssid, d.author, d.moderator, d.moderated,".
		"d.comments, d.display, dc.language, dc.title, dc.excerpt, dc.content ".
		"from documents d, documentscontent dc where ".
		"d.hostid=dc.hostid and d.groupid=dc.groupid and d.documentid=dc.documentid and ".
		"d.hostid=? and d.groupid=? and d.documentid=? and dc.approved=true";

	if( $srcgrp eq '' || $srcdoc eq '' ) {
		print "alert('Source group or doc missing (".$srcgrp.",".$srcdoc.")!');\n";
		return;
	}

	my $x=$dbh->prepare($q);
	$x->execute($hostid,$srcgrp,$srcdoc);
	if( $x->rows < 1 ) {
		print "alert(\"Cannot import the document: not found??\");\n";
		return;
	}
	my $once=0;
	while( my $r=$x->fetchrow_hashref() ) {

		if( ! $once ) {
			# make an id
			my $q3="select max(documentid)+1 from documents where hostid=? and groupid=?";
			my $p=$dbh->prepare($q3);
			$p->execute($hostid,$groupid);
			($documentid)=$p->fetchrow_array();
			if( ! $documentid ) {
				$documentid=1;
			}
			$p->finish();

			# I nedd to add the header only once
			my $k=$dbh->prepare($q1);
			$k->execute(
				$hostid,
				$groupid,
				$documentid,
				$r->{'template'},
				$r->{'cssid'},
				$r->{'icon'},
				$r->{'rssid'},
				$r->{'author'},
				$r->{'moderator'},
				$r->{'moderated'},
				$r->{'comments'},
				$r->{'display'}
			);
			$once=1;
			$k->finish();
		}

		# need to build a new title
		my $title='Copy of '.$r->{'title'};
		my $q3="select count(*) from documentscontent where hostid=? and title=?";
		my $p=$dbh->prepare($q3);
		my $loop=1;
		while( $loop ) {
			$p->execute($hostid,$title);
			my ($c)=$p->fetchrow_array();
			if( $c > 0 ) {
				# title exists, add a counter.
				$title='Copy of '.$r->{'title'}.' ['.$loop.']';
				$loop++;
			} else {
				$loop=0;
			}
			$p->finish();
		}

		# add the contents
		my $k=$dbh->prepare($q2);
		$k->execute(
			$hostid,
			$groupid,
			$documentid,
			$r->{'language'},
			$title,
			$r->{'excerpt'},
			$r->{'approved'},
			$r->{'content'}
		);
	}

	# Ok, now it's matter of adding a new link for the document
	addalink($hostid,$groupid,$documentid,'');

	# do I have to report the comments too?
	if( $query->param('impcomm') ) {
		# yes, import the comments
		my $q1='select commentid,parentid,author,username,clientip,created,approved,title,content from '.
		'comments where hostid=? and groupid=? and documentid=?';
		my $q2='insert into comments (hostid,groupid,documentid,commentid,parentid,'.
		'author,username,clientip,created,approved,title,content) '.
		'values (?,?,?,?,?,?,?,?,?,?,?,?)';
		my $r1=$dbh->prepare($q1);
		my $r2=$dbh->prepare($q2);
		$r1->execute($hostid,$srcgrp,$srcdoc);
		while( my $x=$r1->fetchrow_hashref() ) {
			$r2->execute(
				$hostid,
				$groupid,
				$documentid,
				$x->{'commentid'},
				$x->{'parentid'},
				$x->{'author'},
				$x->{'username'},
				$x->{'clientip'},
				$x->{'created'},
				$x->{'approved'},
				$x->{'title'},
				$x->{'content'}
			);
		}
		$r1->finish();
		$r2->finish();
	}
	

	print "alert('The document has been imported.');";
	return;

}

# edit a document
sub editdocument
{
	my ($hostid,$groupid,$documentid,$language,$msg) = @_;

	my $q="select  ".
		"d.hostid, d.groupid, d.documentid, d.template, d.cssid,".
		"d.icon, d.rssid, d.author, d.moderator, d.moderated,".
		"d.comments, d.isdefault, d.is404, d.display, d.created,".
		"d.updated, c.language, c.title, c.excerpt, c.content, c.approved ".
		"from documents d, documentscontent c where ".
		"d.hostid=c.hostid and d.groupid=c.groupid and d.documentid=c.documentid and ".
		"d.hostid=? and d.groupid=? and d.documentid=? and c.language=?";

	my $x=$dbh->prepare($q);

	$x->execute($hostid,$groupid,$documentid,$language);
	my $r=$x->fetchrow_hashref();

	# by default, DO NOT update date
	if( $query->param('upd') ) {
		$r->{'upd'}=$query->param('upd');
	} else {
		$r->{'upd'}='unchecked';
	}

	$r->{'msg'}=$msg;
	showeditdocumentform($r);
	return;
}

# add an empty group
sub addagroup
{

	my ($hostid,$parentid)=@_;
	my $r;
	my $q;
	my $x;

	$q='select * from groups where hostid=? and groupid=?';
	$x=$dbh->prepare($q);
	$x->execute($hostid,$parentid);
	$r=$x->fetchrow_hashref();

	# zap some values and create a new ID
	$r->{'groupname'}='';
	$r->{'groupid'}=-1;
	$r->{'parentid'}=$parentid;
	$r->{'hostid'}=$hostid;

	showeditgroupform($r,'NEW');
	return;
}

# add an empty css
sub addacss
{
	my $r;
	$r->{'cssid'}='';
	$r->{'filename'}='';
	$r->{'description'}='';

	showeditcssform($r,'NEW');
	return;
}

# add an empty host
sub addanhost
{
	my $r;
	$r->{'hostid'}='';
	$r->{'created'}=$today;
	$r->{'cssid'}=$css;
	$r->{'deflang'}=$deflang;
	$r->{'owner'}=$userid;

	showedithostform($r,'NEW');
	return;
}

# add an empty configuration parameter.
sub addaparam
{
	my $r;
	$r->{'paramid'}='';
	$r->{'value'}='';
	$r->{'updated'}='';
	$r->{'description'}='';

	showeditconfigform($r,'NEW');
	return;
}

# add an empty image.
sub addaimage
{
	# search the next image id for this host
	my $q="select imageid from images where hostid=? order by imageid desc limit 1";
	my $s=$dbh->prepare($q);
	$s->execute($hostid);
	my ($id)=$s->fetchrow_array();
	$id++;
	
	my $r;
	$r->{'hostid'}=$hostid;
	$r->{'imageid'}=$id;
	$r->{'filename'}='';
	$r->{'author'}=$userid;
	$r->{'created'}=$today;

	showeditimageform($r,'NEW');
	return;
}

# add an empty rss feed. In fact this function only build an
# empty structure and then call the 'show edit' to add
sub addarss
{
	my $r;
	$r->{'hostid'}=$hostid;
	$r->{'language'}="$deflang-$deflang";
	$r->{'filename'}='';
	$r->{'title'}='';
	$r->{'lastdone'}='';
	$r->{'description'}='';
	$r->{'link'}='';
	$r->{'author'}=$userid;
	$r->{'copyright'}='';
	$r->{'subject'}='';
	$r->{'taxo'}='';

	showeditrssform($r,'NEW');
	return;
}

# add an empty text. In fact this function only build an
# empty structure and then call the 'show edit' to add
sub addatext
{
	my ($hostid,$textid) = @_;

	my $r;
	$r->{'hostid'}=$hostid;
	$r->{'textid'}=$textid;
	$r->{'language'}=$deflang;
	$r->{'content'}='';

	showedittextform($r,'NEW');
	return;
}

# copy an existing fragment
sub copyfrag
{
	my ($hostid,$fragid) = @_;

	my $q='select * from fragments where hostid=? and fragid=?';
	my $s=$dbh->prepare($q);
	$s->execute($hostid,$fragid);
	my $r=$s->fetchrow_hashref();
	$r->{'created'}=$today;

	showeditfragmentform($r,'NEW');
	return;
}

# add an empty fragment. In fact this function only build an
# empty structure and then call the 'show edit' to add
sub addafrag
{
	my ($fragid) = @_;

	my $r;
	$r->{'hostid'}=$hostid;
	$r->{'fragid'}='';
	$r->{'language'}=$deflang;
	$r->{'created'}=$today;
	$r->{'name'}='';
	$r->{'content'}='';

	showeditfragmentform($r,'NEW');
	return;
}

# add an empty template. In fact this function only build an
# empty structure and then call the 'show edit' to add
sub addatemplate
{
	my ($hostid,$templateid) = @_;

	my $r;
	$r->{'hostid'}=$hostid;
	$r->{'title'}='';
	$r->{'updated'}='';
	$r->{'title'}='';
	$r->{'content'}='';
	$r->{'isdefault'}=0;

	showedittemplateform($r,'NEW');
	return;
}

# add an empty document. In fact this function only build an
# empty structure and then call the 'show edit' to add the doc.
sub addadocument
{
	my ($hostid,$groupid) = @_;

	# See if I have a group and get the default for the group
	my $q='select * from groups where hostid=? and groupid=?';
	my $s=$dbh->prepare($q);
	$s->execute($hostid,$groupid);
	my $x;
	if( $s->rows > 0 ) {
		$x=$s->fetchrow_hashref();
	} else {
		$x->{'hostid'}=$hostid;
		$x->{'groupid'}=$groupid;
		$x->{'template'}='';
		$x->{'css'}=$css;
		$x->{'icon'}='none';
		$x->{'rssid'}='none';
		$x->{'comments'}='no';
		$x->{'moderated'}='yes';
		$x->{'moderator'}='root@onlyforfun.net';
		$x->{'author'}='root@onlyforfun.net';
	}

	my $r;
	$r->{'hostid'}=$x->{'hostid'};
	$r->{'groupid'}=$x->{'groupid'};
	$r->{'documentid'}='';
	$r->{'language'}=$deflang;
	$r->{'approved'}='no';
	$r->{'isdefault'}='no';
	$r->{'is404'}='no';
	$r->{'display'}='no';
	$r->{'rssid'}=$x->{'rssid'};
	$r->{'author'}=$x->{'author'};
	$r->{'moderator'}=$x->{'moderator'};
	$r->{'moderated'}=$x->{'moderated'};
	$r->{'comments'}=$x->{'comments'};
	$r->{'template'}=$x->{'template'};
	$r->{'cssid'}=$x->{'cssid'};
	$r->{'icon'}=$x->{'icon'};
	$r->{'title'}='';
	$r->{'upd'}='unchecked';

	showeditdocumentform($r,'NEW');
	return;
}

# copy an existing document into a new one.
sub copydocument
{
	my ($hostid,$groupid,$documentid) = @_;

	# get the document
	my $q='select * from documents where hostid=? and groupid=? and documentid=?';
	my $s=$dbh->prepare($q);
	$s->execute($hostid,$groupid,$documentid);
	my $x=$s->fetchrow_hashref();
	$x->{'approved'}='no';
	$x->{'display'}='no';

	$x->{'upd'}='unchecked';

	showeditdocumentform($x,'COPY');
	return;
}

# dump the content of a css
sub printcontentcss
{
	print $query->header(
		-type => 'application/data'
	);

	# get the CSS
	my $cssid=shift;
	my $q='select filename from css where cssid=?';
	my $s=$dbh->prepare($q);
	$s->execute($cssid);
	my ($c)=$s->fetchrow_array();
	$c=getconfparam('base',$dbh)."/".getconfparam('cssdir',$dbh)."/".$c;
	$c=~s/\/\//\//g;

	# now load the file
	open INFILE,"<$c";
	while( <INFILE> ) {
		print $_;
	}
	close INFILE;

	return;
}

# dump the content of a document for off-line editing
sub printcontentdoc
{
	print $query->header(
		-type => 'application/data'
	);

	my ($hostid,$groupid,$documentid,$language) = @_;
	my $q='select content from documentscontent where hostid=? and groupid=? and documentid=? and language=?';
	my $s=$dbh->prepare($q);
	$s->execute($hostid,$groupid,$documentid,$language);
	my ($c)=$s->fetchrow_array();
	print $c;
	return;
}

# dump the content of a fragment for off-line editing
sub printcontentfragment
{
	my ($hostid,$fragid,$language) = @_;

	print "Content-type: application/data\n\n";
	my $q='select content from fragments where hostid=? and fragid=? and language=?';
	my $s=$dbh->prepare($q);
	$s->execute($hostid,$fragid,$language);
	my ($c)=$s->fetchrow_array();
	print $c;
	return;
}

# dump the content of a template for off-line editing
sub printcontenttpl
{

	my ($hostid,$templateid,$language) = @_;

	print "Content-type: application/data\n\n";
	my $q='select content from templates where hostid=? and title=?';
	my $s=$dbh->prepare($q);
	$s->execute($hostid,$templateid);
	my ($c)=$s->fetchrow_array();

	print $c;
	return;
}

# show a list of groups in 'select' like fashion
sub selgroup
{
	my $name=shift;
	my $selected=shift;
	my $hostid=shift;

	# don't mind my language
	my $q='select groupid from groups where hostid=?';
	my $s=$dbh->prepare($q);
	$s->execute($hostid);

	print "<select name='".$name."'>\n";
	while( my $r=$s->fetchrow_hashref() ) {
		print "<option value='".$r->{'groupid'}."'";
		if( $r->{'groupid'} eq $selected ) {
			print " selected";
		}
		print "> ".$r->{'groupid'}."\n";
	}
	print "</select>\n";
	return;
}

# show a list of users in 'select' like fashion
sub seluser
{
	my $name=shift;
	my $selected=shift;
	my $disabled=shift;

	my $q='select email,name from users order by name';
	my $s=$dbh->prepare($q);
	$s->execute();

	print "<select name='".$name."' ";
	if( $disabled ) {
		print " disabled ";
	}
	print ">\n";
	while( my $r=$s->fetchrow_hashref() ) {
		print "<option value='".$r->{'email'}."'";
		if( $r->{'email'} eq $selected ) {
			print " selected";
		}
		print "> ".$r->{'name'}."\n";
	}
	print "</select>\n";
	return;
}

# show a list of rss
sub selrss
{
	my $selected=shift;

	my $q='select filename from rssfeeds where hostid=?';
	my $s=$dbh->prepare($q);
	$s->execute($hostid);

	print "<select name='rssid'>\n";
	# add an rss name 'none'
	print "<option value='none'";
	if( $selected eq 'none' ) {
		print " selected";
	}
	print "> none\n";
	while( my $r=$s->fetchrow_hashref() ) {
		print "<option value='".$r->{'filename'}."'";
		if( $r->{'filename'} eq $selected ) {
			print " selected";
		}
		print "> ".$r->{'filename'}."\n";
	}
	print "</select>\n";
	return;
}

# show a list of CSSes in 'select' like fashion
sub selcss
{
	my $selected=shift;

	my $q='select cssid,description from css order by cssid';
	my $s=$dbh->prepare($q);
	$s->execute();

	print "<select name='cssid' id='cssid'>\n";
	while( my $r=$s->fetchrow_hashref() ) {
		print "<option value='".$r->{'cssid'}."'";
		if( $r->{'cssid'} eq $selected ) {
			print " selected";
		}
		print "> ".$r->{'description'}."\n";
	}
	print "</select>\n";
	return;
}

# show a list of templates in 'select' like fashion
sub seltemplate
{
	my $selected=shift;

	my $q='select title from templates where hostid=?';
	my $s=$dbh->prepare($q);
	$s->execute($hostid);

	print "<select name='template'>\n";
	while( my $r=$s->fetchrow_hashref() ) {
		print "<option value='".$r->{'title'}."'";
		if( $r->{'title'} eq $selected ) {
			print " selected";
		}
		print "> ".$r->{'title'}."\n";
	}
	print "</select>\n";
	return;
}

# perform the actual editing.
sub doeditgroup
{
	my $q;
	my $id;
	my $old;

	# remove the directories from the icon
	my $icon=$query->param('ticon');
	$icon=~s/^\/.*\///;

	if( $query->param('mode') eq 'add' ) {

		# search a new id
		$q='select max(groupid)+1 from groups where hostid=?';
		my $x=$dbh->prepare($q);
		$x->execute($hostid);
		($id)=$x->fetchrow_array();
		$x->finish();

		$q=(q{
		insert into groups 
			(hostid, groupname, groupid, parentid, template,
			cssid, icon, rssid, author, owner, comments,
			moderated, moderator, isdefault)
		values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		});

	} else {

		# find out what did I changed and see if I have to change thins on
		# the documents too.
		$q='select template,cssid,icon,rssid,comments,moderated,moderator,author from groups where hostid=? and groupid=?';
		my $r=$dbh->prepare($q);
		$r->execute($query->param('hostid'),$query->param('groupid'));
		$old=$r->fetchrow_hashref();

		# now prepare for update
		if( checkuserrights('host', $hostid ) ) {
			$q=(q{
			update groups set
			groupname=?,template=?,cssid=?,icon=?,rssid=?,comments=?,
			moderated=?,moderator=?,author=?,isdefault=?,owner=? where
			hostid=? and groupid=?
			});
		} else {
			$q=(q{
			update groups set
			groupname=?,template=?,cssid=?,icon=?,rssid=?,comments=?,
			moderated=?,moderator=?,author=?,isdefault=? where
			hostid=? and groupid=?
			});
		}
	}

	my $r=$dbh->prepare($q);
	my $result;

	if($debug) {
		print "hostid:".$query->param('hostid')." ";
		print "groupid:".$id." ";
		print "parentid:".$query->param('parentid')." ";
		print "groupname:".$query->param('groupname')." ";
		print "template:".$query->param('template')." ";
		print "cssid:".$query->param('cssid')." ";
		print "icon:".$icon." ";
		print "rssid:".$query->param('rssid')." ";
		print "comments:".$query->param('comments')." ";
		print "moderated:".$query->param('moderated')." ";
		print "moderator:".$query->param('moderator')." ";
		print "author:".$query->param('author')."<p>\n";
		print "owner:".$query->param('owner')."<p>\n";
		print "rollout:".$query->param('rollout')."<p>\n";
	}

	# if the group is the default one, need to remove the 'default' from other groups
	if( $query->param('isdefault') eq 'yes' ) {
		my $q="update groups set isdefault=false where hostid=?";
		my $r=$dbh->prepare($q);
		$r->execute($hostid);
	}

	if( $query->param('mode') eq 'add' ) {
		$result=$r->execute(
		$query->param('hostid'),
		scrub($query->param('groupname'),$dbh),
		$id,
		$query->param('parentid'),
		$query->param('template'),
		$query->param('cssid'),
		$icon,
		$query->param('rssid'),
		$query->param('author'),
		$query->param('owner'),
		$query->param('comments'),
		$query->param('moderated'),
		$query->param('moderator'),
		$query->param('isdefault')
		);
	} else {
		if( checkuserrights('host', $hostid ) ) {
			$result=$r->execute(
			scrub($query->param('groupname'),$dbh),
			$query->param('template'),
			$query->param('cssid'),
			$icon,
			$query->param('rssid'),
			$query->param('comments'),
			$query->param('moderated'),
			$query->param('moderator'),
			$query->param('author'),
			$query->param('isdefault'),
			$query->param('owner'),
			$query->param('hostid'),
			$query->param('groupid'));
		} else {
			$result=$r->execute(
			scrub($query->param('name'),$dbh),
			$query->param('template'),
			$query->param('css'),
			$icon,
			$query->param('rssid'),
			$query->param('comments'),
			$query->param('moderated'),
			$query->param('moderator'),
			$query->param('author'),
			$query->param('isdefault'),
			$query->param('hostid'),
			$query->param('groupid'));
		}

		# changes in the group could replicate to all the documents, yes, it is ugly
		# as a sin.. any better idea?
		if( $query->param('rollout') eq 'on' ) {
			# see what did I changed
			if( $old->{'rssid'} ne $query->param('rssid') ) {
				# rssid changed
				$q="update documents set rssid=? where hostid=? and groupid=?";
				$r=$dbh->prepare($q);
				$r->execute($query->param('rssid'),$query->param('hostid'),$query->param('groupid'));
			}
			if( $old->{'comments'} ne $query->param('comments') ) {
				# comments changed
				$q="update documents set comments=? where hostid=? and groupid=?";
				$r=$dbh->prepare($q);
				$r->execute($query->param('comments'),$query->param('hostid'),$query->param('groupid'));
			}
			if( $old->{'moderated'} ne $query->param('moderated') ) {
				# moderated changed
				$q="update documents set moderated=? where hostid=? and groupid=?";
				$r=$dbh->prepare($q);
				$r->execute($query->param('moderated'),$query->param('hostid'),$query->param('groupid'));
			}
			if( $old->{'moderator'} ne $query->param('moderator') ) {
				# moderator changed
				$q="update documents set moderator=? where hostid=? and groupid=?";
				$r=$dbh->prepare($q);
				$r->execute($query->param('moderator'),$query->param('hostid'),$query->param('groupid'));
			}
			if( $old->{'author'} ne $query->param('author') ) {
				# author changed
				$q="update documents set author=? where hostid=? and groupid=?";
				$r=$dbh->prepare($q);
				$r->execute($query->param('author'),$query->param('hostid'),$query->param('groupid'));
			}
			if( $old->{'css'} ne $query->param('css') ) {
				# css changed
				$q="update documents set css=? where hostid=? and groupid=?";
				$r=$dbh->prepare($q);
				$r->execute($query->param('css'),$query->param('hostid'),$query->param('groupid'));
			}
			if( $old->{'template'} ne $query->param('template') ) {
				# template changed
				$q="update documents set template=? where hostid=? and groupid=?";
				$r=$dbh->prepare($q);
				$r->execute($query->param('template'),$query->param('hostid'),$query->param('groupid'));
			}
			if( $old->{'icon'} ne $icon ) {
				# icon changed
				$q="update documents set icon=? where hostid=? and groupid=?";
				$r=$dbh->prepare($q);
				$r->execute($icon,$query->param('hostid'),$query->param('groupid'));
			}
		}
	}

	if( ! $result ) {
		closewindow($dbh->{mysql_error});
	} else {
		closewindow();
	}
	exit;
}

# perform the actual editing/adding of the host
sub doedithost
{
	my $q;
	my $id;

	if( $debug ) {
		print "Checking ".$query->param('hostid')."<br>\n";
	}

	if( $query->param('mode') eq 'add' ) {
		$id=checkid($query->param('hostid'));
		if( $debug ) {
			print "Adding ".$id."<br>\n";
		}
		$q=(q{
		insert into hosts
		(hostid, cssid, deflang, owner)
		values (?,?,?,?)
		});
	} else {
		$q=(q{
		update hosts set
		cssid=?, deflang=?, owner=?
		where hostid=?
		});
	}

	my $r=$dbh->prepare($q);
	my $result;

	if( $query->param('mode') eq 'add' ) {
		$result= $r->execute(
		$id,
		$query->param('cssid'),
		$query->param('deflang'),
		$query->param('owner'));

		# select the host
		$hostid=$id;

		# create IMG directory
		my $base=getconfparam('base',$dbh);
		my $destdir=getconfparam('imgdir',$dbh);
		my $thumbdir=getconfparam('thumbdir',$dbh);
		my $imagedir=$base."/".$destdir."/".$hostid."/";
		$imagedir=~s/\/\//\//g;
		$imagedir=~s/\/$//;
		if( checkdir($imagedir) ne '' ) {
			`mkdir -p $imagedir`;
		}
		$thumbdir=$base."/".$destdir."/".$hostid."/".$thumbdir."/";
		$thumbdir=~s/\/\//\//g;
		$thumbdir=~s/\/$//;
		if( checkdir($thumbdir) ne '' ) {
			`mkdir -p $thumbdir`;
		}

		# create RSS directory
		my $rssdir=$base."/".getconfparam('rssfeeddir',$dbh)."/".$hostid;
		$rssdir=~s/\/\//\//g;

		# if the directory doesn't already exists, add it
		if( checkdir($rssdir) ne '' ) {
			`mkdir -p $rssdir`;
		}

	} else {
		$result= $r->execute(
		$query->param('cssid'),	
		$query->param('deflang'),
		$query->param('owner'),
		$query->param('hostid'));
	}

	if( ! $result ) {
		closewindow($dbh->{mysql_error});
	} else {
		closewindow();
	}
	exit;
}

# perform the actual editing.
sub doeditconf
{
	my $q;
	my $id;

	if( $query->param('mode') eq 'add' ) {

		$id=checkid($query->param('paramid'));
		$q=(q{
		insert into configuration
		(paramid, value, description, updated )
		values (?,?,?,now())
		});
	} else {
		$q=(q{
		update configuration set
		value=?, description=?, updated=now()
		where paramid=?
		});
	}

	my $r=$dbh->prepare($q);
	my $result;

	if( $query->param('mode') eq 'add' ) {
		$result= $r->execute(
		$id,
		$query->param('value'),
		$query->param('description'));
	} else {
		$result= $r->execute(
		$query->param('value'),
		$query->param('description'),
		$query->param('paramid'));
	}

	if( ! $result ) {
		closewindow($dbh->{mysql_error});
	} else {
		closewindow();
	}
	exit;
}

# perform the actual editing.
sub doeditrss
{
	my $q;
	my $id;
	my $fname;
	my $basedir;

	# get the configured directory for the feeds
	$basedir="/".getconfparam('base',$dbh)."/".
		getconfparam('rssfeeddir',$dbh)."/".$hostid;
	# adjust for double-slashes
	$basedir=~s/\/\//\//g;

	# build the filename for checking
	$fname=checkid($query->param('filename'));
	if( $fname !~ /\.rss$/ ) {
		$fname .= ".rss";
	}

	# check if the filename has an existing directory.
	$q=checkdir($basedir."/".$fname);

	if( $q ne '' ) {
		warning($q);
	}

	if( $query->param('mode') eq 'add' ) {
		$q=(q{
		insert into rssfeeds
		(hostid,filename,title,description,
		link,language,author,copyright,subject,taxo )
		values (?,?,?,?,?,?,?,?,?,?)
		});
	} else {
		$q=(q{
		update rssfeeds set
		title=?, description=?, link=?,
		author=?, copyright=?, subject=?, taxo=?
		where
		hostid=? and filename=?
		});
	}

	my $r=$dbh->prepare($q);
	my $result;

	if( $query->param('mode') eq 'add' ) {
		$result= $r->execute(
			$hostid,
			$fname,
			scrub($query->param('title'),$dbh),
			scrub($query->param('description'),$dbh),
			$query->param('link'),
			$query->param('language'),
			scrub($query->param('author'),$dbh),
			scrub($query->param('copyright'),$dbh),
			scrub($query->param('subject'),$dbh),
			scrub($query->param('taxo'),$dbh)
		);
	} else {
		$result= $r->execute(
			scrub($query->param('title'),$dbh),
			scrub($query->param('description'),$dbh),
			$query->param('link'),
			scrub($query->param('author'),$dbh),
			scrub($query->param('copyright'),$dbh),
			scrub($query->param('subject'),$dbh),
			scrub($query->param('taxo'),$dbh),
			$hostid,
			$query->param('filename')
		);
	}

	if( ! $result ) {
		closewindow($dbh->{mysql_error});
	} else {
		closewindow();
	}
	exit;
}

# perform the actual editing.
sub doedittext
{
	my $q;
	my $id;

	if( $query->param('mode') eq 'add' ) {
		$q=(q{
		insert into deftexts
		(hostid,textid,language,content)
		values (?,?,?,?)
		});
	} else {
		$q=(q{
		update deftexts set content=? where hostid=? and textid=? and language=?
		});
	}

	my $r=$dbh->prepare($q);
	my $result;

	if( $query->param('mode') eq 'add' ) {
		$id=checkid($query->param('textid'));
		$result= $r->execute(
		$hostid,
		$id,
		$query->param('language'),
		scrub($query->param('content'),$dbh)
		);
	} else {
		$result= $r->execute(
		scrub($query->param('content'),$dbh),
		$hostid,
		$query->param('textid'),
		$query->param('language'));
	}

	if( ! $result ) {
		closewindow($dbh->{mysql_error});
	} else {
		closewindow();
	}
	exit;
}

# perform the actual editing.
sub doeditcss
{
	my $q;
	my $cssdir=getconfparam('cssdir',$dbh);
	my $base=getconfparam('base',$dbh);
	my $cssid=checkid($query->param('cssid'));
	my $content=$query->param('content');
	my $description=$query->param('description');
	my $filename=$query->param('filename');
	my $fh;
	my $msg='';
	my $ext='';

	# check if the destination dir exists
	if( checkdir($cssdir) ne '' ) {
		closewindow('The css dir '.$cssdir.' does not exists!');
		return;
	}

	$cssdir=$base."/".$cssdir;
	$cssdir=~s/\/\//\//g;

	if( $query->param('mode') eq 'add' ) {
	
		# create a temporary file for writing
		($fh,$filename)=tempfile(DIR=>$cssdir,SUFFIX=>'.css');

		# remove the dir from the filename for insertion in the db
		$filename=~s/^.*\///;
		$cssid=$filename;
		$cssid=~s/\.css//;
	}

	# do I have the content?
	if($query->param('content')) {

		my $f=$cssdir."/".$filename;
		$f=~s/\/\//\//g;

		# load the file
		my $content=$query->param('content');
		open OUTFILE,">$f";
		while(<$content>) {
			print OUTFILE $_;
		}
		close OUTFILE;
	}

	# now do it
	if( $query->param('mode') eq 'add' ) {
		$q=(q{
		insert into css
		(cssid,filename,description) values (?,?,?)
		});
	} else {
		$q="update css set description=?,updated=now() where cssid=?";
	}

	my $r=$dbh->prepare($q);
	my $result;

	if( $query->param('mode') eq 'add' ) {
		$result= $r->execute(
			$cssid,
			$filename,
			$description
		);
	} else {
		$result= $r->execute(
			$description,
			$cssid
		);
	}

	if( ! $result ) {
		closewindow($dbh->{mysql_error});
	} else {
		closewindow();
	}
	exit;
}

# perform the actual editing.
sub doeditimage
{
	my $q;
	my $uploaddir=getconfparam('uploaddir',$dbh);
	my $base=getconfparam('base',$dbh);
	my $destdir=getconfparam('imgdir',$dbh);
	my $thumbdir=getconfparam('thumbdir',$dbh);
	my $mkthumb=getconfparam('mkthumb',$dbh);
	my $id=checkid($query->param('imageid'));
	my $content=$query->param('content');
	my $msg='';
	my $ext='';

	# check if the id exists
	if( $query->param('mode') eq 'add' ) {
		$q='select count(*) as count from images where hostid=? and imageid=?';
		my $s=$dbh->prepare($q);
		$s->execute($hostid,$id);
		my $r=$s->fetchrow_hashref();
		if( $r->{'count'} > 0 ) {
			closewindow('ID already present!');
		}
		$s->finish();
	}

	# check if the temp upload dir exists
	if( checkdir($uploaddir) ne '' ) {
		closewindow('The temporary upload dir '.$uploaddir.' does not exists!');
		return;
	}

	# no content? no editing.
	if( ! $content ) {
		closewindow('No file uploaded.');
		return;
	}

	# build the image directory and remove all the junk from it
	my $imagedir=$base."/".$destdir."/".$hostid."/";
	$imagedir=~s/\/\//\//g;
	$imagedir=~s/\/$//;
	if( checkdir($imagedir) ne '' ) {
		closewindow('Destination directory '.$imagedir.' does not exists!');
		return;
	}

	# build a new filename and the one for the thumbnail
	my $filename=$content;

	my $destfile=$imagedir."/".$id;
	my $thumb=$imagedir."/".$thumbdir."/".$id;

	if($debug) {
		print "Destination file: ".$destfile."<br>\n";
		print "Thumbnail file: ".$thumb."<br>\n";
	}

	# load the file
	my $safechar= "a-z0-9_.-";
	$filename=~s/ /_/g;
	$filename=lc $filename;
	$filename=~s/[^$safechar]//g;

	# now the file name should be reasonably clean
	open ( UPLOADFILE, ">$uploaddir/$filename" ) or die "$!";
	binmode UPLOADFILE;
	while(<$content>) {
		print UPLOADFILE;
	}
	close UPLOADFILE;

	if( $debug) {
		print "File uploaded<br>\n";
	}
	# is the file really a .png or a .jpg file ?
	my $type=`file $uploaddir/$filename`;
	if($type =~ /PNG/ || $type =~ /JPEG/ ) {
		# fix the filename with the correct extension.
		if( $type =~ /PNG/ ) {
			$ext='.png';
		}
		if( $type =~ /JPEG/ ) {
			$ext='.jpg';
		}
		$destfile.=$ext;
		$thumb.=$ext;
		if($debug) {
			print "Destination file: ".$destfile."<br>\n";
			print "Thumbnail file: ".$thumb."<br>\n";
		}
		# move the image in the correct dir
		if( $query->param('mode') eq 'edit' ) {
			`rm -f $destfile`;
			`rm -f $thumb`;
		}
		`cp $uploaddir/$filename $destfile`;
		`$mkthumb $destfile $thumb`;
	} else {
		$msg="The uploaded file does not appear to be an image.";
	}

	if( $msg ) {
		closewindow($msg);
	}

	`rm -f $uploaddir/$filename`;

	# now do it
	if( $query->param('mode') eq 'add' ) {
		$q=(q{
		insert into images
		(hostid,imageid,author,created,filename)
		values (?,?,?,?,?)
		});
	} else {
		$q=(q{
		update images set created=?, author=?
		});
		$q.=" where hostid=? and imageid=?";
	}

	my $r=$dbh->prepare($q);
	my $result;

	if( $query->param('mode') eq 'add' ) {
		$result= $r->execute(
			$hostid,
			$id,
			$userid,
			$today,
			$id.$ext
		);
	} else {
		$result= $r->execute(
			$today,
			$userid,
			$hostid,
			$id
		);
	}

	if( ! $result ) {
		closewindow($dbh->{mysql_error});
	} else {
		closewindow();
	}
	exit;
}

# perform the actual editing.
sub doeditfragment
{
	my $q;
	my $c;
	my $id;

	if( $query->param('mode') eq 'add' ) {
		$q=(q{
		insert into fragments
		(hostid,fragid,language,content)
		values (?,?,?,?)
		});
		$c="";
		if($query->param('content')) {
			# load the file
			my $filename= $query->param('content');
			while(<$filename>) {
				$c.=$_;
			}
		}

	} else {
		if($query->param('content')) {
			$q="update fragments set content=? where hostid=? and fragid=? and language=?";
			# load the file
			my $filename= $query->param('content');
			while(<$filename>) {
				$c.=$_;
			}
		} else {
			closewindow();
		}
	}

	my $r=$dbh->prepare($q);
	my $result;

	if( $query->param('mode') eq 'add' ) {
		$id=checkid($query->param('fragid'));
		$result= $r->execute( $hostid, $id, $query->param('language'), $c);
	} else {
		$result= $r->execute( $c, $hostid, $query->param('fragid'), $query->param('language'));
	}

	if( ! $result ) {
		closewindow($dbh->{mysql_error});
	} else {
		closewindow();
	}
	exit;
}

# perform the actual editing.
sub doedittemplate
{
	my $q;
	my $c;
	my $default=0;
	my $title=$query->param('title');

	if( $query->param('isdefault') eq 'yes' ) {
		$default=1;
	}

	if( $query->param('mode') eq 'add' ) {

		# if I am in add mode, check if the template id is ok.
		$title=checkid($query->param('title'));

		$q=(q{
		insert into templates
		(hostid,title,content,updated,isdefault)
		values (?,?,?,?,?)
		});
		$c='';
		if($query->param('content')) {
			# load the file
			my $filename= $query->param('content');
			while(<$filename>) {
				$c.=$_;
			}
		}

	} else {
		$q=(q{
		update templates set updated=?,isdefault=?
		});
		if($query->param('content')) {
			# load the file
			my $filename= $query->param('content');
			while(<$filename>) {
				$c.=$_;
			}
			$q.=",content=?";
		}
		$q.=" where hostid=? and title=?";
	}

	my $r=$dbh->prepare($q);
	my $result;

	# I can have only one default template per host
	if( $query->param('isdefault') eq 'yes' ) {
		my $q="update templates set isdefault=false where hostid=?";
		my $r=$dbh->prepare($q);
		$r->execute($hostid);
	}

	if( $query->param('mode') eq 'add' ) {
		$result= $r->execute( $hostid, $title, $c, $today, $default);
	} else {
		if($query->param('content')) {
			$result= $r->execute($today, $default, $c, $hostid, $title);
		} else {
			$result= $r->execute($today, $default, $hostid, $title);
		}
	}

}

# Execute the editing (or adding) of a document
sub doeditdocument
{
	my $q;
	my $r;
	my $icon=$query->param('ticon');
	my $msg='';
	my $title=$query->param('title');
	my $content='';
	my $oldlang=$query->param('oldlanguage');
	my $published;

	# zap the path from the icon's name
	$icon=~s/.*\///;

	# do I have the content?
	if($query->param('content')) {

		# load the file
		my $filename= param('content');
		while(<$filename>) {
			$content.=$_;
		}
		$content=~s/\r\n/\n/g;
	}

	# If I have an excerpt, remove simple paragraf (<p> - </p>) from it, this to avoid
	# problems with the CKeditor that insists in putting paragraphs everywhere!
	my $excerpt=$query->param('excerpt');
	if( $excerpt ) {
		$excerpt=~s/<p>//g;
		$excerpt=~s/<\/p>//g;
	}

	# clean the title
	if( $query->param('title')) {
		$title=scrub($query->param('title'),$dbh);
	}

	# if ADDING I need a new documentid
	if( $query->param('mode') eq 'add' ) {

		# need to build a new documentid
		$q="select max(documentid)+1 from documents where hostid=? and groupid=?";
		$r=$dbh->prepare($q);
		$r->execute($hostid,$groupid);
		($documentid)=$r->fetchrow_array();
		if( ! $documentid ) {
			$documentid=1;
		}
		$r->finish();

	}

	# If adding or copying I need to check the title
	if( $query->param('mode') eq 'add' || $query->param('mode') eq 'copy' ) {

		# check if the title ain't already in.
		$q="select count(*) from documentscontent where hostid=? and language=? and title=?";
		$r=$dbh->prepare($q);
		$r->execute($hostid,$language,$title);
		my ($c)=$r->fetchrow_array();
		if( $c > 0 ) {
			# error
			$msg='A document with this title already exists!';
			$r->finish();
			return $msg;
		}
		$r->finish();

		# check errors
		if( $msg eq '' ) {

			if( $query->param('mode') eq 'add' ) {
				
				# add the new document
				$q="insert into documents ".
				"(hostid, groupid, documentid, template, cssid,".
				"icon, rssid, author, moderator, moderated, comments,".
				"isdefault, is404, display, created, updated, published ) values".
				"(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

				# if the document is approved, I also update the published date, otherwise I set it to NULL
				if( $query->param('approved') eq 'yes') {
					$published=$today;
				}
				my $r=$dbh->prepare($q);
				if( ! $r->execute(
					$hostid,
					$groupid,
					$documentid,
					$query->param('template'),
					$query->param('cssid'),
					$icon,
					$query->param('rssid'),
					$query->param('author'),
					$query->param('moderator'),
					$query->param('moderated'),
					$query->param('comments'),
					$query->param('isdefault'),
					$query->param('is404'),
					$query->param('display'),
					'now()',
					'now()',
					$published) ) {
					$msg=$dbh->errstr;
					return $msg;
				}
			}

			# add a link to the document (one has to exist)
			addalink($hostid,$groupid,$documentid,'');

			# now let's add the content (or at minimum the language place-holder)
			$q="insert into documentscontent ".
			"(hostid, groupid, documentid, language,".
			"title, excerpt, approved, content) ".
			"values (?, ?, ?, ?, ?, ?, ?, ?)";

			$r=$dbh->prepare($q);
			if( ! $r->execute(
				$hostid,
				$groupid,
				$documentid,
				$language,
				$title,
				$excerpt,
				$query->param('approved'),
				$content)) {
				$msg=$dbh->errstr;
				return $msg;
			}
		}

	} else {

		# editing or ADDING a different language if the original didn't existed.
		if( $debug ) {
			print "Updating:<br>\n";
			print $query->param('template')."<br>";
			print $query->param('cssid')."<br>";
			print $query->param('ticon')."<br>";
			print $query->param('rssid')."<br>";
			print $query->param('author')."<br>";
			print $query->param('moderator')."<br>";
			print $query->param('moderated')."<br>";
			print $query->param('comments')."<br>";
			print $query->param('isdefault')."<br>";
			print $query->param('is404')."<br>";
			print $query->param('display')."<br>";
			print $query->param('hostid')."<br>";
			print $query->param('groupid')."<br>";
			print $query->param('documentid')."<p>";
			print $query->param('language')."<p>";
			print $query->param('oldlanguage')."<p>";
		}

		# is the new language different from the old one?
		if( $language ne $oldlang ) {

			# I've changed the language. Check if the document doesn't already exists.
			$q='select count(*) from documentscontent where hostid=? and groupid=? and documentid=? and language=?';
			$r=$dbh->prepare($q);
			$r->execute($hostid,$groupid,$documentid,$language);
			my ($c)=$r->fetchrow_array();
			if( $c > 0 ) {
				# document already present!
				$msg="That language already exists!";
				return $msg;
			}

			# ok, cool. I'm adding a new language then
			$q="insert into documentscontent ".
			"(hostid, groupid, documentid, language,".
			"title, excerpt, approved, content) ".
			"values (?, ?, ?, ?, ?, ?, ?, ?)";

			$r=$dbh->prepare($q);
			if( ! $r->execute(
				$hostid,
				$groupid,
				$documentid,
				$language,
				$title,
				$excerpt,
				$query->param('approved'),
				$content)) {
					$msg=$dbh->errstr;
					return $msg;
			}
		}

		# update the header first
		$q="update documents set ".
		"template=?, cssid=?, icon=?, rssid=?, ".
		"author=?, moderator=?, moderated=?, comments=?, ".
		"isdefault=?, is404=?, display=?";
		# update date
		if( $query->param('upd') ) {
			$q.=",updated=now() ";
		}
		# update published date
		if( $query->param('approved') eq 'yes') {
			$q.=",published=now() ";
		} else {
			$q.=",published=NULL ";
		}
		$q.="where hostid=? and groupid=? and documentid=? ";

		$r=$dbh->prepare($q);
		if( ! $r->execute(
			$query->param('template'),
			$query->param('cssid'),
			$query->param('ticon'),
			$query->param('rssid'),
			$query->param('author'),
			$query->param('moderator'),
			$query->param('moderated'),
			$query->param('comments'),
			$query->param('isdefault'),
			$query->param('is404'),
			$query->param('display'),
			$query->param('hostid'),
			$query->param('groupid'),
			$query->param('documentid')
		)) {
			$msg=$dbh->errstr;
			return $msg;
		}
		$r->finish();

		# now update the content.
		$q="update documentscontent set ".
		"title=?,excerpt=?,approved=? " ;
		if( $query->param('content') ) {
			$q.=",content=? ";
		}
		$q.="where hostid=? and groupid=? and documentid=? and language=?";
		$r=$dbh->prepare($q);
		if( $query->param('content') ) {
			if( ! $r->execute(
				$title,
				$excerpt,
				$query->param('approved'),
				$content,
				$query->param('hostid'),
				$query->param('groupid'),
				$query->param('documentid'),
				$query->param('language')
			)) {
				$msg=$dbh->errstr;
				return $msg;
			}
		} else {
			if( ! $r->execute(
				$title,
				$excerpt,
				$query->param('approved'),
				$query->param('hostid'),
				$query->param('groupid'),
				$query->param('documentid'),
				$query->param('language')
			)) {
				$msg=$dbh->errstr;
				return $msg;
			}
		}

	}
	$r->finish();

	# if I've set this document as 404 or default, I have to remove any other
	# default or 404 from the group.
	if( $query->param('isdefault') eq 'yes' ) {
		$q="update documents set isdefault='no' where hostid=? and groupid=? and documentid <> ?";
		$r=$dbh->prepare($q);
		if( ! $r->execute($query->param('hostid'),$query->param('groupid'),$query->param('documentid'))) {
			return $dbh->errstr;
		}
	}
	if( $query->param('is404') eq 'yes' ) {
		$q="update documents set is404='no' where hostid=? and groupid=? and documentid <> ?";
		$r=$dbh->prepare($q);
		if( ! $r->execute($query->param('hostid'),$query->param('groupid'),$query->param('documentid'))) {
			return $dbh->errstr;
		}
	}

	return '';
}

# Toggle the comments bit on the document
sub togglecomment
{
	# get the data
	my $hostid=$query->param('hostid');
	my $groupid=$query->param('groupid');
	my $documentid=$query->param('documentid');

	# toggle
	my $q1='select comments from documents where hostid=? and groupid=? and documentid=?';
	my $q2='update documents set comments=? where hostid=? and groupid=? and documentid=?';
	my $r=$dbh->prepare( $q1 );
	$r->execute($hostid,$groupid,$documentid);
	my ($i)=$r->fetchrow_array();
	$r->finish();
	$r=$dbh->prepare( $q2 );
	if( $i ) {
		$r->execute('false',$hostid,$groupid,$documentid);
	} else {
		$r->execute('true',$hostid,$groupid,$documentid);
	}
}

# Toggle the 'status' for comments.
# NOTE: in 5.0 there is no longer a 'status' for the comments,
# a documents has comments or doesn't, if a documents has comments
# but the comment flag is off, then is automatically closed.
sub togglestatus
{
	return;
}
#	# get the data
#	my $hostid=$query->param('hostid');
#	my $groupid=$query->param('groupid');
#	my $documentid=$query->param('documentid');
#
#	my $q1='select status from documents where hostid=? and groupid=? and documentid=?';
#	my $q2='update documents set status=? where hostid=? and groupid=? and documentid=?';
#	if( ! checkuserrights('group',$hostid,$groupid) ) {
#		$q1.=" and (author='".$userid."' or moderator='".$userid."')";
#		$q2.=" and (author='".$userid."' or moderator='".$userid."')";
#	}
#	my $r=$dbh->prepare($q1);
#	$r->execute($hostid,$groupid,$documentid);
#	my ($i)=$r->fetchrow_array();
#	if( $i eq 'open' ) {
#		$i='close';
#	} else {
#		$i='open';
#	}
#	$r=$dbh->prepare($q2);
#	$r->execute($i,$hostid,$groupid,$documentid);
#}

# disable/enable the 'display' bit
sub toggledisplay
{
	# get the data
	my $current=$query->param('current');
	my $hostid=$query->param('hostid');
	my $groupid=$query->param('groupid');
	my $documentid=$query->param('documentid');
	my $commentid=$query->param('commentid');
	my $parentid=$query->param('parentid');
	my $language=$query->param('language');

	# toggle
	if( $current eq 'documents' ) {
		my $q1='select display from documents where hostid=? and groupid=? and documentid=?';
		my $q2='update documents set display=? where hostid=? and groupid=? and documentid=?';
		if( ! checkuserrights('group',$hostid,$groupid) ) {
			$q1.=" and author='".$userid."'";
			$q2.=" and author='".$userid."'";
		}

		my $r=$dbh->prepare($q1);
		$r->execute($hostid,$groupid,$documentid);
		my ($i)=$r->fetchrow_array();
		if( $i ) {
			$i=0;
		} else {
			$i=1;
		}
		$r=$dbh->prepare( $q2 );
		$r->execute($i,$hostid,$groupid,$documentid);
	}
}

# toggle the spam status in a comment
sub togglespam
{
	my $commentid=$query->param('commentid');
	my $parentid=$query->param('parentid');

	my $q1='update comments set spam = not spam where hostid=? and groupid=? and documentid=? and commentid=? and parentid=?';
	my $r1=$dbh->prepare($q1);
	$r1->execute($hostid,$groupid,$documentid,$commentid,$parentid);
	return;
}

# toggle the 'root' bit for a user
sub toggleroot
{
	# get the data
	my $current=$query->param('current');
	my $email=$query->param('email');
	my $language=$query->param('language');

	my $q1='select isroot from users where email=?';
	my $q2='update users set isroot=? where email=?';
	my $r=$dbh->prepare( $q1 );
	$r->execute($email);
	my ($i)=$r->fetchrow_array();
	if( $i ) {
		$i=0;
	} else {
		$i=1;
	}
	$r=$dbh->prepare( $q2 );
	$r->execute($i,$email);
}

# remove an image
sub delimage
{
	# get the data
	my $current=$query->param('current');
	my $hostid=$query->param('hostid');
	my $imageid=$query->param('imageid');

	my $q1='delete from images where hostid=? and imageid=?';
	my $r=$dbh->prepare( $q1 );
	$r->execute($hostid,$imageid);

}

# remove a default text
sub deltext
{
	# get the data
	my $current=$query->param('current');
	my $hostid=$query->param('hostid');
	my $textid=$query->param('textid');

	my $q1='delete from deftexts where hostid=? and textid=?';
	my $r=$dbh->prepare( $q1 );
	$r->execute($hostid,$textid);

}

# remove a configuration paramater
sub delconfig
{
	# get the data
	my $current=$query->param('current');
	my $paramid=$query->param('paramid');

	my $q1='delete from configuration where paramid=?';
	my $r=$dbh->prepare( $q1 );
	$r->execute($paramid);

}

# remove a post
sub delcomment
{
	# get the data
	my $current=$query->param('current');
	my $groupid=$query->param('groupid');
	my $hostid=$query->param('hostid');
	my $documentid=$query->param('documentid');
	my $commentid=$query->param('commentid');
	my $parentid=$query->param('parentid');

	# to remove a comment I also have to remove all the Children
	my $q1='delete from comments where hostid=? and groupid=? and documentid=? and commentid=? and parentid=?';
	my $r=$dbh->prepare( $q1 );
	$r->execute($hostid,$groupid,$documentid,$commentid,$parentid);

}

# remove a user
# when a user is removed all the comments are deleted, all the documents
# and the groups are assigned to the local user (root).
sub deluser
{
	# get the data
	my $email=$query->param('email');

	my $q;
	my $r;

	$q='update hosts set owner=? where owner=?';
	$r=$dbh->prepare($q);
	$r->execute($userid,$email);

	$q='update documents set author=? where author=?';
	$r=$dbh->prepare($q);
	$r->execute($userid,$email);
	$q='update documents set moderator=? where moderator=?';
	$r=$dbh->prepare($q);
	$r->execute($userid,$email);

	$q='update groups set author=? where author=?';
	$r=$dbh->prepare($q);
	$r->execute($userid,$email);
	$q='update groups set moderator=? where moderator=?';
	$r=$dbh->prepare($q);
	$r->execute($userid,$email);

	$q='update comments set userid=? where userid=?';
	$r=$dbh->prepare($q);
	$r->execute($userid,$email);

	$q='delete from userdescs where userid=?';
	$r=$dbh->prepare( $q );
	$r->execute($email);

	$q='delete from users where email=?';
	$r=$dbh->prepare( $q );
	$r->execute($email);

	# done
}

# disable/enable the 'approve' bit
# some parts require double check (users...)
sub toggleapprove
{
	# get the data
	my $current=$query->param('current');
	my $hostid=$query->param('hostid');
	my $groupid=$query->param('groupid');
	my $documentid=$query->param('documentid');
	my $email=$query->param('email');
	my $commentid=$query->param('commentid');
	my $parentid=$query->param('parentid');
	my $language=$query->param('language');

	# toggle
	if( $current eq 'documents' ) {

		my $q1='select approved from documentscontent where hostid=? and groupid=? and documentid=?';
		my $q2='update documentscontent set approved=? where hostid=? and groupid=? and documentid=?';
		my $q3='update documents set published=now() where hostid=? and groupid=? and documentid=?';
		if( ! checkuserrights('group',$hostid,$groupid ) ) {
			$q1.=" and author='".$userid."'";
			$q2.=" and author='".$userid."'";
		}
		if( $debug ) {
			print "searching $hostid $groupid $documentid<br>\n";
		}
		my $r=$dbh->prepare( $q1 );
		$r->execute($hostid,$groupid,$documentid);
		my ($i)=$r->fetchrow_array();
		my $d='null';
		if( $i ) {
			$i=0;
			$q3='update documents set published=NULL where hostid=? and groupid=? and documentid=?';
		} else {
			$i=1;
		}
		$r=$dbh->prepare( $q2 );
		if( $debug ) {
			print "updating $hostid $groupid $documentid with $i<br>\n";
		}
		$r->execute($i,$hostid,$groupid,$documentid);
		# update publication date with today or nothing, depending if I want to publish or un-publish
		$r=$dbh->prepare( $q3 );
		$r->execute($hostid,$groupid,$documentid);

	} elsif( $current eq 'comments' ) {

		my $q1='select approved from comments where hostid=? and groupid=? and documentid=? and commentid=? and parentid=?';
		my $q2='update comments set approved=? where hostid=? and groupid=? and documentid=? and commentid=? and parentid=?';

		my $r=$dbh->prepare( $q1 );
		$r->execute($hostid,$groupid,$documentid,$commentid,$parentid);
		my ($i)=$r->fetchrow_array();
		$r->finish();
		$r=$dbh->prepare( $q2 );
		if( $i ) {
			$r->execute('false',$hostid,$groupid,$documentid,$commentid,$parentid);
		} else {
			$r->execute('true',$hostid,$groupid,$documentid,$commentid,$parentid);
		}
		$r->finish();

	} elsif( $current eq 'users' && $isroot ) {
		# to disable or enable a user I replace the password with 'disabled'
		my $q='select password from users where email=?';
		my $r=$dbh->prepare($q);
		$r->execute($email);
		my ($op) = $r->fetchrow_array();
		if( $op eq 'nopass' ) {
			# must be enabled
			enableuser($email,$dbh,$deflang);
		} elsif( $op eq 'disabled' ) {
			# must be re-enabled
			enableuser($email,$dbh,$deflang);
		} else {
			# must be disabled
			$q="update users set password='disabled' where email=?";
			$r=$dbh->prepare($q);
			$r->execute($email);
		}
	}

}

# close the page
sub closehtml
{

	my $msg=shift;

	# close the page
	print "<hr>\n";

	if( $userid ne 'NONE' && $hostid eq '' && $mode eq '') {
		print "<p><center><b>You need to select an HOST to work.</b><p>";
		print "Click on the <img src='".$iconsdir."/home.png'> ".
		" icon and the click on the <img src='".
		$accepticon."'> icon of the ";
		print "host you want to manage.</center>";
		print "<hr>\n";
	}

	if( $userid eq 'NONE' ) {
		print "<p><center>\n";
		print "<table width='80%' border='0' cellspacing='0'>";
		print "<tr><td align='center'><h3>Welcome to the CMS FDT Backoffice.</h3></td></tr>\n";
		print "<tr><td align='center'>";
		print "You won't see the fantastic functionality I put into this baby until ";
		print "you login.</td></tr>";
		print "</td></tr></table>\n";
		print "<p>";

		print "<table width='40%' border='0' cellspacing='2' cellpadding='2' ";
		print "bgcolor='lightgrey'>\n";
		print "<tr><td colspan='2'>\n";
		print "Enter your e-mail and password to login.\n";
		print "</td></tr>\n";
		print "<form name='loginform' method='post' action='".$myself."'>\n";
		print "<input type='hidden' name='mode' value='login'>\n";
		print "<tr><td width='10%'>";
		print "E-mail:";
		print "</td><td><input type='text' name='email' size='30' value=''>";
		print "</td></tr>\n";
		print "<tr>\n";
		print "<td width='10%'>\n";
		print "Password:</td>";
		print "<td><input type='password' name='password' size='30' value=''>";
		print "</td></tr>\n";
		print "<tr><td colspan='2'>";
		print "<input type='submit' value='Login'>";
		print "</td></tr>\n";
		print "</table>\n";
		print "</center><p>";
		print "<hr>\n";
	}

	# end page
	printfooter();

	if( $msg ) {
		print "<script>\n";
		print "alert('".$msg."');\n";
		print "</script>\n";
	}
	print "</body>\n";
	print "</html>\n";

}

# generate ALL the RSS feed for the system
sub genallrss
{
	my $q='select hostid,filename from rssfeeds';
	my $s=$dbh->prepare($q);
	$s->execute();
	while( my ($hostid,$rssid)=$s->fetchrow_array() ) {
		genrssfeed($hostid,$rssid,0);
	}
}

# Generate the RSS feed for the system, if the 'id' is ALL, all the
# rss feeds defined will be generated.
sub genrssfeed
{
	my ($hostid,$rssid,$msg)=@_;
	my $query;

	# get the configured directory for the feeds
	my $dir="/".getconfparam('base',$dbh)."/".
		getconfparam('rssfeeddir',$dbh)."/".$hostid;

	# max number of documents to include in the feed.
	my $limit=getconfparam('rsslimit',$dbh);
	if( ! $limit ) {
		$limit=60;
	}

	# adjust for double-slashes
	$dir=~s/\/\//\//g;
	my $rss = XML::RSS->new( version => '1.0' );

	# if the directory does not exists, don't generate anything
	my $q=checkdir($dir);
	if( $q ne '' && $msg==1 ) {
		warning("The destination directory (".$dir.") does not exists. Feed NOT generated.");
		return;
	}

	$query='select * from rssfeeds where hostid=? and filename=?';
	my $sth=$dbh->prepare($query);
	$sth->execute($hostid,$rssid);
	my $feed=$sth->fetchrow_hashref();

	if( $debug ) {
		print "Generating RSS feed for $rssid\n";
	}

	# build the feed
	$rss->channel (
		title        => $feed->{'title'},
		link         => $feed->{'link'},
		description  => $feed->{'description'},
		language     => $feed->{'language'},
		copyright    => $feed->{'copyright'},
		dc=>{
			subject=>$feed->{'subject'},
			author=>$feed->{'author'},
		},
		taxo => [ $feed->{'taxo'} ] 
	);

	# now get the first 60 documents related to this feed
	$query=(q{
	select
	dc.title,dc.excerpt,d.documentid,d.groupid,l.link from 
	documentscontent dc, documents d, links l
	where 
	d.hostid=dc.hostid and
	d.groupid=dc.groupid and
	d.documentid=dc.documentid and
	d.hostid=l.hostid and
	d.groupid=l.groupid and
	d.documentid=l.documentid and
	d.hostid=? and d.rssid=? and dc.language=? and 
	dc.approved=true and d.display=true 
	order by d.groupid desc,d.documentid desc
	});
	$q.=" limit $limit";
	$sth=$dbh->prepare($query);
	$sth->execute($hostid,$rssid,$feed->{'language'});

	if( $debug ) {
		print "found ".$sth->rows." documents\n";
	}

	# cycle on the documents
	my $olddoc;
	while( my $r=$sth->fetchrow_hashref()) {

		# only one document per link, since a document
		# can have more links...
		if( $olddoc ne $r->{'documentid'}) {
			$olddoc=$r->{'documentid'};

			my $exc=unscrub($r->{'excerpt'},$dbh);
			my $link=$feed->{'link'}."/".$r->{'link'};
	
			if( $debug ) {
				print "adding ".$link."\n";
			}
	
			# add link to the excerpt
			$exc.="...<a href='".$link."'>read more</a>";
	
			# add the item
			$rss->add_item( title => unscrub($r->{'title'},$dbh),
				link => $link,
				description => $exc );
		}
	}

	# save the feed
	$dir=~s/\/\//\//g;
	$dir=~s/\/$//;
	$dir=~s/^\///;
	my $outfile="/".$dir."/".$feed->{'filename'};
	$rss->save($outfile);

	# update feed record
	$query=(q{
	update rssfeeds set lastdone=? where hostid=? and filename=?
	});
	$sth=$dbh->prepare($query);
	$sth->execute($today,$hostid,$rssid);
	$sth->finish();

	if( $msg == 1 ) {
		print "<script>\n";
		print "alert(\"Feed generated in ".$outfile.".\");\n";
		print "</script>\n";
	}
	return;

}

# show a list of languages as a 'select'
sub selectlang
{
	my ($name,$curlang)=@_;
	my $lang=getconfparam('languages',$dbh);
	my @languages=split / /,$lang;
	print "<select name='$name'>\n";
	foreach my $lang (@languages) {
		print "<option value='".$lang."'";
		if( $lang eq $curlang ) {
			print " selected";
		}
		print ">" . $lang . "\n";
	}
	print "</select>\n";
}

# Display the title bar - normal
sub printtitle
{
	my $css=getconfparam('css',$dbh);
	my $icondir=getconfparam('buttondir',$dbh);
	my $avatardir=getconfparam('avatardir',$dbh);

	my $numicons=0;

	# remove last '/'
	$icondir=~s/\/$//;

	# load the icons
	my $templatesicon=$icondir."/".getconfparam('templatesicon',$dbh);
	my $hostsicon=$icondir."/".getconfparam('hostsicon',$dbh);
	my $groupsicon=$icondir."/".getconfparam('groupsicon',$dbh);
	my $documentsicon=$icondir."/".getconfparam('documentsicon',$dbh);
	my $usersicon=$icondir."/".getconfparam('usersicon',$dbh);
	my $fragmentsicon=$icondir."/".getconfparam('fragmentsicon',$dbh);
	my $commentsicon=$icondir."/".getconfparam('commentsicon',$dbh);
	my $textsicon=$icondir."/".getconfparam('textsicon',$dbh);
	my $rssicon=$icondir."/".getconfparam('rssicon',$dbh);
	my $configicon=$icondir."/".getconfparam('configicon',$dbh);
	my $logouticon=$icondir."/".getconfparam('logouticon',$dbh);
	my $loginicon=$icondir."/".getconfparam('loginicon',$dbh);
	my $closeicon=$icondir."/".getconfparam('closeicon',$dbh);
	my $helpicon=$icondir."/".getconfparam('helpicon',$dbh);
	my $imgicon=$icondir."/".getconfparam('imgicon',$dbh);
	my $cssicon=$icondir."/".getconfparam('cssicon',$dbh);
	my $helplink=getconfparam('helplink',$dbh);

	$helplink=~s/\/$//;

	# print the title
	print "<table width='100%' border='0' cellspacing='0' cellpadding='5pt'>\n";
	print "<tr valign='top' class='title'>\n";
	print "<td align='left' width='90%'>\n";
	print "<h1>".getconfparam('title',$dbh);
	if( $hostid ) {
		print " [$hostid]";
	}
	if( $userid ne 'NONE' ) {
		print "[$userid]";
	}
	print "</h1>\n";

	if( $current eq 'comments' && $extra ) {
		# print number of comments to approve 
		my $q='select count(*) from comments where hostid=? and groupid=? and documentid=? and approved=false';
		my $r=$dbh->prepare($q);
		$r->execute($hostid,$groupid,$documentid);
		my ($c)=$r->fetchrow_array();
		print $c." comments to approve for this document.";
		$r->finish();
	}

	print "</td>\n";

	showcommand('help!','read the on-line help',$helpicon,$helplink."/".$current,$current,1000,800,0);
	if( $current eq 'comments' && $extra ) {
		showcommand('close','close this window',$closeicon,'javascript:closeandrefresh()',$current,0,0,1);
	} else {
		if( $userid eq 'NONE' ) {
			showcommand('login','login',$loginicon,'/cgi-bin/login.pl',$current,780,530,0);
		} else {
			showcommand('edit','open the edit user window',$avatardir.'/'.$icon,
				"/cgi-bin/edituser.pl?mode=display&email=$userid",
				$current,1000,700,0);
			showcommand('logout','logout',$logouticon,$myself.'?mode=logout',$current,0,0,1);
		}
	}
	print "</tr>\n";
	print "</table>\n";

	# no userid? no functions!
	if( $userid eq 'NONE' ) {
		return;
	}

	if( ! $extra ) {

		# normal icons
		print "<table width='100%' border='0' cellspacing='0' cellpadding='5pt' class='command'>\n";
		print "<tr align='left'>";
		if(checkuserrights('root') ) {
			$numicons+=3;
			showcommand('users','users management',$usersicon,
				$myself."?current=users&hostid=".$hostid,$current,0,0,1);
			showcommand('config','configuration parameters',$configicon,
				$myself."?current=config&hostid=".$hostid,$current,0,0,1);
			showcommand('css','css',$cssicon,
				$myself."?current=css&hostid=".$hostid,$current,0,0,1);
		}
		$numicons++;
		showcommand('hosts','hosts',$hostsicon,
				$myself."?current=hosts&hostid=".$hostid,$current,0,0,1);
		if( $hostid ne '' ) {
			if( checkuserrights('host') ) {
				$numicons+=4;
				showcommand('texts','short text',$textsicon,
					$myself."?current=texts&hostid=".$hostid,$current,0,0,1);
				showcommand('fragments','text fragments',$fragmentsicon,
					$myself."?current=fragments&hostid=".$hostid,$current,0,0,1);
				showcommand('feed','rss feeds',$rssicon,
					$myself."?current=feed&hostid=".$hostid,$current,0,0,1);
				showcommand('templates','templates',$templatesicon,
					$myself."?current=templates&hostid=".$hostid,$current,0,0,1);
			}
			if( hasadoc($userid) ) {
				$numicons++;
				showcommand('images','images',$imgicon,$myself."?current=images&hostid=".$hostid,$current,0,0,1);
			}
			if( hasadoc($userid) ) {
				$numicons++;
				showcommand('documents','documents',$documentsicon,
					$myself."?current=documents&hostid=".$hostid,$current,0,0,1);
			}
			if( ismoderator($userid) ) {
				$numicons++;
				showcommand('comments','comments',$commentsicon,$myself."?current=comments&hostid=".$hostid,$current,0,0,1);
			}
		}

		# now fill up the row
		for( my $c=$numicons; $c<11; $c++ ) {
			print "<td width='9%' style='none'></td>";
		}
		print "</tr>\n";
		print "</table>\n";
	}
	print "<hr>\n";

}

# Checking functions (to remove some errors...)

# remove all the spaces from the ID
sub checkid
{
	my $id=shift;
	if($debug) {
		print "Checking $id<br>\n";
	}
	$id=~s/ //g;
	if($debug) {
		print "Returning $id<br>\n";
	}
	return $id;
}

# check if a directory exists or not
sub checkdir
{
	my $dir=shift;

	# get only the directory part (for files), adjust for double slashes
	$dir=~s/^(.*)\/.*$/$1\//;
	$dir=~s/\/\//\//g;

	# if the dir does not beging with a '/', I assume is relative to the
	# "base" dir
	if( $dir !~ /^\// ) {
		my $base=getconfparam('base',$dbh);
		$dir=$base."/".$dir;
	}

	if( $debug ) {
		print "Checking if dir $dir exists<br>\n";
	}

	if ( -d $dir ) {
		return "";
	} else {
		if( $debug ) {
			print "Directory ".$dir." does not exists!<br>\n";
		}
		return "The specified directory ('".$dir."') does not exists!";
	} 
}

# show an icon on screen.
# used to get rid of all the problems with directory/nodirectory in
# the icons options.
sub showdocicon
{
	my ($icon,$special)=@_;
	$icon=~s/^\///;
	$icon=~s/^.*\///;
	my $dociconsdir=getconfparam('dociconsdir',$dbh);
	$dociconsdir="/".$dociconsdir;
	$dociconsdir=~s/^\/\//\//;
	$dociconsdir=~s/\/$//;

	return "<img src='".$dociconsdir."/".$icon."' ".$special.">\n";
}

# Check the user rights agains a given level, return '1' if the
# user can do it, or 0 if he can't.
sub checkuserrights
{
	my $l=shift;
	my $h=shift;
	my $g=shift;
	my $d=shift;

	if( $debug ) {
		print "level: $l host: $h group: $g doc: $d isroot: $isroot<br>\n";
	}

	#if the user is root there is no sense in checking
	if ( $isroot ) {
		if( $debug ) {
			print "user is root<br>\n";
		}
		return 1;
	}

	if( $h ) {
		my $q='select owner from hosts where hostid=?';
		my $r=$dbh->prepare($q);
		$r->execute($h);
		my $x=$r->fetchrow_hashref();
		if( $x->{'owner'} eq $userid ) {
			$ishostowner='yes';
		} else {
			$ishostowner='no';
		}
	}

	if( $h && $g ) {
		my $q='select owner from groups where hostid=? and groupid=?';
		my $r=$dbh->prepare($q);
		$r->execute($h,$g);
		my $x=$r->fetchrow_hashref();
		if( $x->{'owner'} eq $userid ) {
			$isgroupowner='yes';
		} else {
			$isgroupowner='no';
		}
	}

	if($h && $g && $d) {
		my $q='select author,moderator from documents where hostid=? and groupid=? and documentid=?';
		my $r=$dbh->prepare($q);
		$r->execute($h,$g,$d);
		my $x=$r->fetchrow_hashref();
		$author=$x->{'author'};
		$moderator=$x->{'moderator'};
	}

	if( $l eq 'host' ) {
		if( $ishostowner eq 'yes' ) {
			if( $debug ) {
				print "user is host owner<br>\n";
			}
			return 1;
		}
	}

	if( $l eq 'group' ) {
		if( $isgroupowner eq 'yes' || $ishostowner eq 'yes' ) {
			return 1;
		}
	}
	if( $l eq 'doc' ) {
		if( $author eq $userid || $isgroupowner eq 'yes' || $ishostowner eq 'yes' ) {
			return 1;
		}
	}
	if( $l eq 'comm' ) {
		if( $moderator eq $userid || $author eq $userid || $isgroupowner eq 'yes' || $ishostowner eq 'yes' ) {
			return 1;
		}
	}

	# nope! Sorry buddy!
	return 0;

}

# display a user's name given the email
sub displayusername
{
	my $email=shift;
	my $q='select name from users where email=?';
	my $r=$dbh->prepare($q);
	$r->execute($email);
	my ($o)=$r->fetchrow_array();
	$r->finish();
	return $o;
}

# check if the current user is moderator for at least one document
sub ismoderator
{
	my $userid=shift;

	# if he has a document or a group it's ok
	if ( hasadoc($userid) ) {
		return 1;
	}

	# search one document
	my $q='select count(*) from documents where hostid=? and moderator=?';
	my $r=$dbh->prepare($q);
	$r->execute($hostid,$userid);
	my ($c)=$r->fetchrow_array();
	if( $c > 0 ) {
		return 1;
	}

	return 0;
}

# check if the current user has at least one document on his name or is a group
# owner
sub hasadoc
{
	my $userid=shift;

	if( hasagroup( $userid ) ) {
		return 1;
	}
	
	# search one document
	my $q='select count(*) from documents where hostid=? and author=?';
	my $r=$dbh->prepare($q);
	$r->execute($hostid,$userid);
	my ($c)=$r->fetchrow_array();
	if( $c > 0 ) {
		return 1;
	}

	return 0;
}

# check if the user owns a group
sub hasagroup
{
	my $userid=shift;

	# is he root or the host owner? if so, ok.
	if( $isroot || $ishostowner eq 'yes' ) {
		return 1;
	}

	# see if he owns a group
	my $q='select count(*) from groups where hostid=? and owner=?';
	my $r=$dbh->prepare($q);
	$r->execute($hostid,$userid);
	my ($c)=$r->fetchrow_array();
	if( $c > 0 ) {
		return 1;
	}
	return 0;
}

# show the links for a document
sub showdoclinks
{
	my ($hostid,$groupid,$documentid,$msg) = @_;
	
	my $q='select link from links where hostid=? and groupid=? and documentid=?';
	my $r=$dbh->prepare($q);
	my $count=0;
	my $id;
	my $color=0;

	print "<html>\n";
	print "<head>\n";
	print "</head>\n";
	print "<body>\n";

	print "<table bgcolor='white' cellpadding='3' cellspacing='0' border='0' width='100%'>\n";
	$r->execute($hostid,$groupid,$documentid);
	if( $r->rows > 0 ) {
		while( my $l=$r->fetchrow_hashref() ) {

			if( $color==0 ) {
				print "<tr bgcolor='white'>\n";
				$color=1;
			} else {
				print "<tr bgcolor='lightgrey'>\n";
				$color=0;
			}
			print "<td align='left' valign='top' class='msgtext'>\n";
			print $l->{'link'};
			print "</td>\n";
			print "<td>\n";
			if( $r->rows > 1 ) {
				my $id='dellink'.$count;
				$count++;
				print "<form id='".$id."' name='".$id."' action='".$myself."' method='post'>\n";
				print "<input type='hidden' name='hostid' value='".$hostid."'>\n";
				print "<input type='hidden' name='groupid' value='".$groupid."'>\n";
				print "<input type='hidden' name='documentid' value='".$documentid."'>\n";
				print "<input type='hidden' name='link' value='".$l->{'link'}."'>\n";
				print "<input type='hidden' name='mode' value='dellink'>\n";
				print "<img src='".$delicon."' title='remove link' alt='remove link' ";
				print "onmouseover='style.cursor=\"pointer\"' ";
				print "onclick='javascript:document.".$id.".submit()'>\n";
				print "</form>\n";
			}
			print "</td>\n";
			print "</tr>\n";
		}
	}
	
	# always show the 'add one'
	print "<tr bgcolor='yellow'>\n";
	print "<td align='left' valign='top'>\n";
	print "<form id='addlink' method='post' action='".$myself."' name='addlink'>\n";
	print "<input type='hidden' name='hostid' value='".$hostid."'>\n";
	print "<input type='hidden' name='groupid' value='".$groupid."'>\n";
	print "<input type='hidden' name='documentid' value='".$documentid."'>\n";
	print "<input type='hidden' name='mode' value='addlink'>\n";
	print "<input type='text' size='80%' name='link' value=''>\n";
	print "</td>\n";
	print "<td align='right' valign='top'>\n";
	print "<img src='".$addicon."' title='add a new link' ";
	print "onmouseover='style.cursor=\"pointer\"' ";
	print "onclick='javascript:document.addlink.submit()'>\n";
	print "</td>\n";
	print "</tr>\n";
	print "</form>\n";
	print "</table>\n";

	# eventual error messages are printed after displaynd the data
	if( $msg ) {
		print "<script>\n";
		print "alert('".$msg."');\n";
		print "</script>\n";
	}

	print "</body>\n";
	print "</html>\n";
}

# add a new link to a document
sub addalink
{
	my ($hostid,$groupid,$documentid,$link)=@_;
	my $msg='';
	
	# remove trailing/leading and double slashes, spaces and the like
	$link=~s/\/\///g;
	$link=~s/^\///;
	$link=~s/\/$//;
	$link=~s/[^\/a-zA-z0-9_-]//g;
	
	# check user authorizations
	if( checkuserrights('doc',$hostid,$groupid,$documentid)) {

		# if the link is empty, search the correct GroupName (group/group/group...) and add the documentid
		# to make a link that make sense (not something like 17/9).
		if( $link eq '' ) {
			$link=buildgroupfromid($hostid,$groupid)."/".$documentid;
		}
		
		# Oky, insert
		my $q='insert into links (hostid,groupid,documentid,link) values(?,?,?,?)';
		my $r=$dbh->prepare($q);
		if(! $r->execute($hostid,$groupid,$documentid,$link) ) {
			$msg='Error adding the new link:'.$dbh->errstr;
		}
	}

	return $msg;
}

# remove a link from a document
sub removealink
{
	my ($hostid,$groupid,$documentid,$link)=@_;
	my $msg='';
	
	# check user authorizations
	if( checkuserrights('doc',$hostid,$groupid,$documentid)) {
	
		# Oky, remove
		my $q='delete from links where hostid=? and link=?';
		my $r=$dbh->prepare($q);
		if( ! $r->execute($hostid,$link) ) {
			$msg='Error removing the link:'.$dbh->errstr;
		}
	}
	return $msg;

}


# Documents... the documents are hierarchical, so we first show the groups
sub showroot
{
	# Special function to show the ROOT group, each host has one ROOT group.
	# all the other groups are created underneat it.
	my ($hostid,$parentid,$history)=@_;

	# width and height of the edit document window
	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);

	# width and height of the edit group window
	my $wingw=getconfparam("groups-fw",$dbh);
	my $wingh=getconfparam("groups-fh",$dbh);

	my $paddicon=$iconsdir."/".getconfparam('pageadd',$dbh);

	my $q="select * from groups where hostid=? and groupid=parentid";
	my $r=$dbh->prepare($q);
	$r->execute($hostid);
	if( $r->rows == 0 ) {
		addrootgroup();
		$r->execute($hostid);
	}

	# display data
	print "<table width='100%' bgcolor='lightblue' border='0' cellspacing='0' cellpadding='5pt'>";
	my $x=$r->fetchrow_hashref();

	# who is the owner of this group?
	if( $x->{'owner'} eq $userid ) {
		$isgroupowner='yes';
	} else {
		$isgroupowner='no';
	}

	# count numbers of documents per group
	$q='select count(documentid) from documents where hostid=? and groupid=?';
	my $rr=$dbh->prepare($q);
	$rr->execute($hostid,$x->{'groupid'});
	my ($numdocs)=$rr->fetchrow_array();

	# count numbers of documents to approve per group
	$q="select count(documentid) from documentscontent where hostid=? and groupid=? and approved is false";
	$rr=$dbh->prepare($q);
	$rr->execute($hostid,$x->{'groupid'});
	my ($numdocsta)=$rr->fetchrow_array();

	# count number of comments
	$q='select count(documentid) from comments where hostid=? and groupid=?';
	$rr=$dbh->prepare($q);
	$rr->execute($hostid,$x->{'groupid'});
	my ($numcomm)=$rr->fetchrow_array();

	# and number of comments to approve
	$q="select count(documentid) from comments where hostid=? and groupid=? and approved is false";
	$rr=$dbh->prepare($q);
	$rr->execute($hostid,$x->{'groupid'});
	my ($numcommtoapprove)=$rr->fetchrow_array();

	my $show;
	my $edit;
	my $icon=$accepticon;

	# just to simplify the links
	if( $x->{'isdefault'} ) {
		$icon=$iconsdir."/".getconfparam("defaultfoldericon",$dbh);
	} else {
		$icon=$iconsdir."/".getconfparam("foldericon",$dbh);
	}

	# edit group function
	$edit=$myself."?mode=editgroup&amp;current=$current&amp;hostid=".
		$hostid."&amp;groupid=".$x->{'groupid'};

	# print titles
	print "<thead>\n";
	print "<tr>\n";
	print "<th align='left'>Group</th>\n";
	print "<th align='left'>Template</th>\n";
	print "<th align='left'>CSS</th>\n";
	print "<th>Icon</th>\n";
	print "<th align='left'>Rss</th>\n";
	print "<th align='left'>Comm</th>\n";
	print "<th align='left'>Owner</th>\n";
	print "<th align='left'>#docs</th>\n";
	print "<th align='left'>#comm</th>\n";
	print "<th align='right'>&nbsp;</th>\n";
	print "</tr>\n";
	print "</thead>\n";
	print "<tbody>\n";

	# now display the data
	print "<tr bgcolor='white'>\n";
	print "<td align='left'>";
	if( checkuserrights('group',$x->{'hostid'},$x->{'groupid'}) ) {
		showminicommand('click to edit',$icon,$edit,'',$wingw,$wingh,0);
	}
	print "<a name='".$x->{'groupid'}."'>";
	print $x->{'groupname'};
	print "</a>\n";
	print "</td>\n";
	print "<td align='left'>".$x->{'template'}."</td>";
	print "<td align='left'>".$x->{'cssid'}."</td>";
	print "<td align='center'>";
	print showdocicon($x->{'icon'},"width='16px' height='16px'");
	print "</td>";
	print "<td align='left'>".$x->{'rssid'}."</td>";
	print "<td align='left'>".$x->{'comments'}."</td>";
	print "<td align='left'>";
	print displayusername($x->{'owner'});
	print "</td>";
	print "<td align='left'>\n";
	if( $numdocsta > 0 ) {
		print "<b>";
	}
	print $numdocs . "/";
	print $numdocsta;
	if( $numdocsta > 0 ) {
		print "</b>";
	}
	print "</td>\n";

	print "<td align='left'>\n";
	if( $numcommtoapprove > 0 ) {
		print "<b>";
	}
	print $numcomm . "/";
	print $numcommtoapprove;
	if( $numcommtoapprove > 0 ) {
		print "</b>";
	}
	print "</td>\n";

	print "<td align='right'>";

	# if the current user is root or the current user is the owner of the group,
	# allow to create new documents in this group
	if( checkuserrights('group') ) {
		showminicommand('add a group',$faddicon,
		$myself."?current=groups&amp;hostid=$hostid&amp;groupid=".
		$x->{'groupid'}."&amp;mode=addgroup",$current,$wingw,$wingh,0);

		showminicommand('add document in this group',$paddicon,
		$myself."?current=".$current."&amp;hostid=$hostid&amp;groupid=".
		$x->{'groupid'}."&amp;mode=adddoc&amp;type=document",$current,$winw,$winh,0);
	}

	# minimum host owner to handle groups
	if(checkuserrights('host',$hostid)) {

		# I can only delete a group if it doesn't contains other groups -
		# delete is not recursive (yet)
		my $kr=$dbh->prepare('select count(*) from groups where hostid=? and parentid=?');
		$kr->execute($hostid,$x->{'groupid'});
		my ($kkr) = $kr->fetchrow_array();
		$kr->finish();
		if( $kkr == 0 ) {
			showminicommand2('delete this group',$delicon,"Delete the group ".
			$x->{'name'}." and all the associated documents?",
			$myself."?mode=delete&amp;current=groups&amp;groupid=".
			$x->{'groupid'}."&amp;hostid=$hostid",$current);
		}

		showminicommand('copy group',$copyicon,$myself.
		"?mode=copygroup&amp;current=groups&amp;groupid=".
		$x->{'groupid'}."&amp;hostid=$hostid",$current,$wingw,$wingh,0);
	}

	print "</td>";
	print "</tr>\n";

	return;
}

# Show all the groups in directory-fashion
sub showgroups
{
	my ($hostid,$parentid,$history) = @_;
	my $col=0;
	my $sort=$query->param('sort');

	# width and height of the edit document window
	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);

	# width and height of the edit group window
	my $wingw=getconfparam("groups-fw",$dbh);
	my $wingh=getconfparam("groups-fh",$dbh);

	my $paddicon=$iconsdir."/".getconfparam('pageadd',$dbh);
	my $pgdn=$iconsdir."/".getconfparam('pagedown',$dbh);

	# no history? Show the root group only 
	my $q="select * from groups where hostid=? and parentid=? and groupid != parentid order by groupname,parentid desc";
	my $r=$dbh->prepare($q);
	$r->execute($hostid,$parentid);

	if( $parentid == 0 && $r->rows==0 ) {

		# check if there is a template, without templates you can't add groups.
		my $x=$dbh->prepare('select title from templates where hostid=? and isdefault is true');
		$x->execute($hostid);
		if( $x->rows == 0 ) {

			$winw=getconfparam("templates-fw",$dbh);
			$winh=getconfparam("templates-fh",$dbh);

			print "<p class='msgtext'><center>";
			print "Before adding groups and documents you need to have at least <b>one</b> <i>template</i>.<br>";
			print "Click ";
			showminicommand('add a template',$addicon,$myself."?".
			"mode=addtpl&amp;hostid=".$hostid,$current,$winw,$winh,0);
			print " to add a template.";
			print "</center></p>";
		} else {
			# re-execute the query to refresh the result
			$r->execute($hostid,$parentid);
		}
		$x->finish();
	}

	# display data
	print "<table width='100%' bgcolor='lightblue' border='0' cellspacing='0' cellpadding='5pt'>";
	if( $r->rows > 0 ) {

		# print titles only if there are rows
		print "<thead>\n";
		print "<tr>\n";
		print "<th align='left'>Group</th>\n";
		print "<th align='left'>Template</th>\n";
		print "<th align='left'>CSS</th>\n";
		print "<th>Icon</th>\n";
		print "<th align='left'>Rss</th>\n";
		print "<th align='left'>Comm</th>\n";
		print "<th align='left'>Owner</th>\n";
		print "<th align='left'>#docs</th>\n";
		print "<th align='left'>#comm</th>\n";
		print "<th align='right'>&nbsp;</th>\n";
		print "</tr>\n";
		print "</thead>\n";
		print "<tbody>\n";
	}

	# loop and print the infos
	while( my $x=$r->fetchrow_hashref() ) {

		# who is the owner of this group?
		if( $x->{'owner'} eq $userid ) {
			$isgroupowner='yes';
		} else {
			$isgroupowner='no';
		}

		# count numbers of documents per group
		$q='select count(documentid) from documents where hostid=? and groupid=?';
		my $rr=$dbh->prepare($q);
		$rr->execute($hostid,$x->{'groupid'});
		my ($numdocs)=$rr->fetchrow_array();

		# count numbers of documents to approve per group
		$q="select count(documentid) from documentscontent where hostid=? and groupid=? and approved is false";
		$rr=$dbh->prepare($q);
		$rr->execute($hostid,$x->{'groupid'});
		my ($numdocsta)=$rr->fetchrow_array();

		# count number of comments
		$q='select count(documentid) from comments where hostid=? and groupid=?';
		$rr=$dbh->prepare($q);
		$rr->execute($hostid,$x->{'groupid'});
		my ($numcomm)=$rr->fetchrow_array();

		# and number of comments to approve
		$q="select count(documentid) from comments where hostid=? and groupid=? and approved is false";
		$rr=$dbh->prepare($q);
		$rr->execute($hostid,$x->{'groupid'});
		my ($numcommtoapprove)=$rr->fetchrow_array();

		my $show;
		my $edit;
		my $icon=$accepticon;

		# just to simplify the links
		if( $x->{'isdefault'} ) {
			$icon=$iconsdir."/".getconfparam("defaultfoldericon",$dbh);
		} else {
			$icon=$iconsdir."/".getconfparam("foldericon",$dbh);
		}

		# edit group function
		$edit=$myself."?mode=editgroup&amp;current=$current&amp;hostid=".
			$hostid."&amp;groupid=".$x->{'groupid'};

		# now display the data
		print "<tr ";
		if( $col==1 ) {
			print "bgcolor='white'";
			$col=0;
		} else {
			$col=1;
		}
		print ">\n";
		print "<td align='left'>";
		if( checkuserrights('group',$x->{'hostid'},$x->{'groupid'}) ) {
			showminicommand('click to edit',$icon,$edit,'',$wingw,$wingh,0);
		}
		print "<a name='".$x->{'groupid'}."'>";
		print "<a href='".$myself."?mode=expand&amp;parentid=".$x->{'groupid'};
		print "&amp;hostid=".$x->{'hostid'}."&amp;history=".$history."#".$x->{'groupid'}."' ";
		print "title='click to expand'>";
		print $x->{'groupname'};
		print "</a></a>\n";
		print "</td>\n";
		print "<td align='left'>".$x->{'template'}."</td>";
		print "<td align='left'>".$x->{'cssid'}."</td>";
		print "<td align='center'>";
		print showdocicon($x->{'icon'},"width='16px' height='16px'");
		print "</td>";
		print "<td align='left'>".$x->{'rssid'}."</td>";
		print "<td align='left'>".$x->{'comments'}."</td>";
		print "<td align='left'>";
		print displayusername($x->{'owner'});
		print "</td>";
		print "<td align='left'>\n";
		if( $numdocsta > 0 ) {
			print "<b>";
		}
		print $numdocs . "/";
		print $numdocsta;
		if( $numdocsta > 0 ) {
			print "</b>";
		}
		print "</td>\n";

		print "<td align='left'>\n";
		if( $numcommtoapprove > 0 ) {
			print "<b>";
		}
		print $numcomm . "/";
		print $numcommtoapprove;
		if( $numcommtoapprove > 0 ) {
			print "</b>";
		}
		print "</td>\n";

		print "<td align='right'>";

		# if the current user is root or the current user is the owner of the group,
		# allow to create new documents in this group
		if( checkuserrights('group') ) {
			showminicommand('add a group',$faddicon,
			$myself."?current=groups&amp;hostid=$hostid&amp;groupid=".
			$x->{'groupid'}."&amp;history=".$history."&amp;mode=addgroup",$current,$wingw,$wingh,0);

			showminicommand('add document in this group',$paddicon,
			$myself."?current=".$current."&amp;hostid=$hostid&amp;groupid=".
			$x->{'groupid'}."&amp;history=".$history."&amp;mode=adddoc&amp;type=document",$current,$winw,$winh,0);

			showminicommand('import a document from another group',$pgdn,
			$myself."?current=".$current."&amp;hostid=$hostid&amp;groupid=".
			$x->{'groupid'}."&amp;history=".$history."&amp;mode=import&amp;type=document",$current,800,400,0);
		}

		# minimum host owner to handle groups
		if(checkuserrights('host',$hostid)) {

			# I can only delete a group if it doesn't contains other groups -
			# delete is not recursive (yet)
			my $kr=$dbh->prepare('select count(*) from groups where hostid=? and parentid=?');
			$kr->execute($hostid,$x->{'groupid'});
			my ($kkr) = $kr->fetchrow_array();
			$kr->finish();
			if( $kkr == 0 ) {
				showminicommand2('delete this group',$delicon,"Delete the group ".
				$x->{'name'}." and all the associated documents?",
				$myself."?mode=delete&amp;current=groups&amp;groupid=".
				$x->{'groupid'}."&amp;hostid=$hostid",$current);
			}

			showminicommand('copy group',$copyicon,$myself.
			"?mode=copygroup&amp;current=groups&amp;groupid=".
			$x->{'groupid'}."&amp;hostid=$hostid",$current,$wingw,$wingh,0);
		}

		print "</td>";
		print "</tr>\n";

		# now let's see if I have to show the subgroups for this group
		my $id='@'.$x->{'groupid'}.'@';
		if( $history =~ /$id/ && $history ne '' ) {
			print "<tr bgcolor='lightblue'>\n";
			print "<td colspan='10'>\n";
			showgroups($x->{'hostid'},$x->{'groupid'},$history);
			print "</td>\n";
			print "</tr>\n";
		}

	}

	# I print the documents in any event
	showdocsforgroup($hostid,$parentid,$sort);

	print "</tbody>\n";
	print "</table>\n";

}

# Print the docs that belongs to a specific group.
sub showdocsforgroup
{
	my ($hostid,$groupid,$sort) = @_;

	if( $debug ) {
		print "Searching docs for group ".$groupid."<br>\n";
	}

	my $q="select ".
		"d.hostid, d.groupid, d.documentid, d.template, ".
		"d.cssid, d.icon, d.rssid, d.author, d.moderator, d.moderated, ".
		"d.comments, d.isdefault, d.is404, d.display, ".
		"to_char(d.updated,'".$dateformat."') as updated,".
		"to_char(d.published,'".$dateformat."') as published,".
		"d1.title as title, d1.language as language, d1.approved as approved ".
		"from ".
		"documents d, documentscontent d1 ".
		"where ".
		"d.hostid=d1.hostid and ".
		"d.groupid=d1.groupid and ".
		"d.documentid=d1.documentid and ".
		"d.hostid=? and d.groupid=? ";

	if( ! checkuserrights('group',$hostid,$groupid) ) {
		$q.=" and author=? ";
	}
	if( $sort ) {
		$q.=" order by $sort";
	} else {
		$q.=" order by documentid";
	}

	my $r=$dbh->prepare($q);
	if( ! checkuserrights('group',$hostid,$groupid) ) {
		$r->execute($hostid,$groupid,$userid);
	} else {
		$r->execute($hostid,$groupid);
	}

	# if there are no documents in this group, no sense in showing
	# anything...
	if( $r->rows > 0 ) {

		print "<tr><td colspan='10'>\n";
		print "<table width='100%' cellspacing='0' cellpadding='3' border='0'";
		print " bgcolor='lightgrey'>";
		print "<thead>\n";
		print "<tr>\n";
		print "<th>&nbsp;</th>";
		print "<th align='left'>Title</th>\n";
		print "<th align='center'>Icon</th>\n";
		print "<th align='left'>Template</th>\n";
		print "<th align='left'>Css</th>\n";
		print "<th align='left'>Rss</th>\n";
		print "<th align='left'>Updated</th>\n";
		print "<th align='left'>Published</th>\n";
		print "<th align='center'>Comm/App</th>\n";
		print "<th>&nbsp;</th>\n";
		print "</tr>\n";
		print "</thead>\n";
		print "<tbody>\n";

		my $color=0;
		my $did;
		my @languages=();

		# loop on all the documents;
		while( my $x=$r->fetchrow_hashref() ) {

			if( ! $did ) {
				$did=$x ;
			}
			# same document as before? just get the language
			if ( $did->{'documentid'} eq $x->{'documentid'} ) {
				$languages[++$#languages]=$x->{'language'}.":".$x->{'approved'};
				if( $x->{'isdefault'} eq 'yes' ) {
					$did->{'isdefault'}='yes';
				}
				if( $x->{'is404'} eq 'yes' ) {
					$did->{'is404'}='yes';
				}
			} else {
				# show a line
				$color=showonedoc($did,$color,@languages);
				$did=$x;
				@languages=();
				$languages[++$#languages]=$x->{'language'}.":".$x->{'approved'};
			}
		}

		# must still print the last record
		showonedoc($did,$color,@languages);
		print "</tbody>\n";
		print "</table>\n";
		print "</td></tr>\n";
	}
}

# utility function to show one single document in the 'showdocsforgroup' function above.
# used not to repeat everytime.
sub showonedoc
{
	my ($did,$color,@languages)=@_;

	# to rebuild the list later
	my $history=$query->param('history');
	my $parentid=$query->param('parentid');

	my $winw=getconfparam($current."-fw",$dbh);
	my $winh=getconfparam($current."-fh",$dbh);

	# check if the document has comments enabled, if he does,
	# search for comments to approve.
	my $cta=0;
	my $cto=0;

	# compute comments anywa
	my $q=(q{
		select count(*) from comments where hostid=? and groupid=?
		and documentid=? and approved=false;
	});
	my $r=$dbh->prepare($q);
	$r->execute($did->{'hostid'},$did->{'groupid'},$did->{'documentid'});
	($cta)=$r->fetchrow_array();
	$r->finish();
	# just get all the comments now
	$q=(q{
		select count(*) from comments where 
		hostid=? and groupid=? and documentid=?
	});
	$r=$dbh->prepare($q);
	$r->execute($did->{'hostid'},$did->{'groupid'},$did->{'documentid'});
	($cto)=$r->fetchrow_array();
	$r->finish();

	# search one link for the preview
	my $q='select link from links where hostid=? and groupid=? and documentid=?';
        my $x=$dbh->prepare($q);
	$x->execute($did->{'hostid'},$did->{'groupid'},$did->{'documentid'});
	my ($previewurl)=$x->fetchrow_array();
	$previewurl=$preview."?doc=".$previewurl."&amp;host=".$hostid;
	$x->finish();

	print "<tr ";
	if($cta > 0) {
		# if there are comments to approve, show it in yellow
		print " bgcolor='yellow' ";
	} else {
		if( $color==0 ) {
			print " bgcolor='white' ";
			$color=1;
		} else {
			$color=0;
		}
	}

	print ">\n";
	# if the document is the default one or is the 404 one, show something
	print "<td>";
	if( $did->{'isdefault'} || $did->{'is404'} ) {
		if( $did->{'isdefault'} ) {
			showminicommand('default document for the group',$selecticon,'','',0,0,0);
		}
		if( $did->{'is404'} ) {
			showminicommand('not found document',$icon404,'','',0,0,0);
		}
	} else {
		print "&nbsp;";
	}
	print "</td>\n";

	# preview link - run the preview in the default language
	print "<td>\n";
	print "<a name='".$previewurl."'></a>";
	print "<a href='javascript:openwindow(\"".$previewurl."\",\"".$did->{'title'}."\",1000,800)' ";
	print "title='click for preview'>";
	if( $did->{'isdefault'} || $did->{'is404'} ) {
		print "<b>";
	}
	print $did->{'title'};
	if( $did->{'isdefault'} || $did->{'is404'} ) {
		print "</b>";
	}
	print "</a> &nbsp;";
	for (@languages) {

		my $ok=0;
		my ($lang,$app)=split /:/,$_;

		# edit the document only if the user is author or above
		if( checkuserrights('doc',$did->{'hostid'},$did->{'groupid'},$did->{'documentid'}) ||
			$did->{'author'} eq $userid ) {
			$ok=1;
		}

		# for the approval, I need to see the document -in the language-
		print "[ ";
		if( $app eq 'no' ) {
			print "<b>";
		}
		if( $ok ) {
			print "<a href='javascript:openwindow(";
			print "\"".$myself."?hostid=".$did->{'hostid'}."&amp;groupid=";
			print $did->{'groupid'}."&amp;documentid=".$did->{'documentid'};
			print "&amp;language=".$lang."&amp;mode=editdoc";
			print "\",\"Edit document\",".$winw.",".$winh.")'>";
		}
		print $lang;
		if( $ok ) {
			print "</a>";
		}
		if( $app eq 'no' ) {
			print "</b>";
		}
		print " ] ";
	}
	print "</td>\n";
	print "<td align='center'>";
	if( $did->{'icon'} ne 'none' && $did->{'icon'} ne '' ) {
		print showdocicon($did->{'icon'}," width='16px' height='16px'");
	}
	print "</td>\n";
	print "<td>";
	print $did->{'template'};
	print "</td>\n";
	print "<td>\n";
	print $did->{'cssid'};
	print "</td>\n";
	print "<td>\n";
	print $did->{'rssid'};
	print "</td>\n";
	print "<td>\n";
	print $did->{'updated'};
	print "</td>\n";
	print "<td>\n";
	print $did->{'published'};
	print "</td>\n";

	print "<td align='center'>\n";
	if( $cta > 0 ) {
		print "<b>";
	}
	print $cto."/".$cta;
	if( $cta > 0 ) {
		print "</b>";
	}
	print "</td>\n";

	print "<td align='right'>";

	# editing on the document only if the user is owner or above
	if( checkuserrights('doc',$did->{'hostid'},$did->{'groupid'},$did->{'documentid'}) ||
		$did->{'author'} eq $userid ) {

		my $icon='';
		my $text='';
		my $link="&amp;current=documents&amp;hostid=".$did->{'hostid'}.
			"&amp;groupid=".$did->{'groupid'}."&amp;documentid=".$did->{'documentid'}.
			"&amp;history=".$history."&amp;parentid=".$parentid;

		# zap the document only if the user is group owner
		# these commands acts on all the version of a document.
		if( checkuserrights('group') ) {
			showminicommand2('delete',$delicon,
				"Delete this document and all the associated comments?",
				$myself."?mode=delete".$link,$current);
		}

		if($did->{'approved'}) {
			$icon=$publishicon;
			$text='click to unpublish'
		} else {
			$icon=$unpublishicon;
			$text='click to publish'
		}
		showminicommand($text,$icon,$myself."?mode=togapproved".$link."#$previewurl",$current,0,0,1);

		if($did->{'display'}) {
			$icon=$enableicon;
			$text='click to delist'
		} else {
			$icon=$disableicon;
			$text='click to list'
		}
		showminicommand($text,$icon,$myself."?mode=togdisplay".$link."#$previewurl",$current,0,0,1);

		if($did->{'comments'}) {
			$icon=$commaddicon;
			$text='click to disable comments'
		} else {
			$icon=$commdelicon;
			$text='click to enable comments'
		}
		showminicommand($text,$icon,$myself."?mode=togcomment".$link."#$previewurl",$current,0,0,1);

		# copy of a document = adding of a document
		if( $isroot || $isgroupowner eq 'yes' ) {
			showminicommand('copy document',$copyicon,
				$myself."?mode=copydoc".$link,$current,$winw,$winh,0);
		}

	}

	# show comments editing only if the user is moderator or above
	if( checkuserrights('comm',$did->{'hostid'},$did->{'groupid'},$did->{'documentid'}) ||
		$did->{'author'} eq $userid ) {
		my $link="?current=comments&amp;hostid=".$did->{'hostid'}."&amp;groupid=".
		$did->{'groupid'}."&amp;documentid=".$did->{'documentid'};
		showminicommand('show comments',$pviewicon,$myself.$link."#$previewurl",$current,$winw,$winh,0);
	}
	print "</td>";
	print "</tr>\n";

	return $color;
}

# Add a new Host Alias
sub addhostalias
{
	my ($hostid,$alias)=@_;
	my $msg='';
	my $q;
	my $s;

	if( ! checkuserrights('host',$hostid)) {
		return '';
	}

	# remove spaces from the alias and turn it into lowercase
	$alias=lc($alias);
	$alias=~s/ //g;

	# check if the alias is a valid hostname (localhost is OK).
	if( $alias ne 'localhost' && $alias ne '' ) {
		if( ! isvalidhostname($alias) ) {
			$msg="Alias $alias is not a valid hostname!";
		} else {
			# check if the alias already exists
			$q='select count(*) from hostaliases where alias=?';
			$s=$dbh->prepare($q);
			$s->execute($alias);
			my ($x)=$s->fetchrow_array();
			if( $x > 0 ) {
				$msg="Alias $alias already present in the system";
			}
			$s->finish();
		}
	}

	if( $msg eq '' ) {
		my $q='insert into hostaliases (hostid,alias) values (?,?)';
		my $s=$dbh->prepare($q);
		if( ! $s->execute($hostid,$alias) ) {
			$msg=$dbh->errstr;
		}
		$s->finish();
	}

	return $msg;
}

# Remove an host alias
sub delhostalias
{
	my ($hostid,$alias)=@_;
	my $msg='';
	my $q;
	my $s;

	if( ! checkuserrights('host',$hostid)) {
		return '';
	}

	my $q='delete from hostaliases where hostid=? and alias=?';
	my $s=$dbh->prepare($q);
	if( ! $s->execute($hostid,$alias) ) {
		$msg=$dbh->errstr;
	}
	$s->finish();
	return $msg;
}

# Add a root group for the host
# Called the first time we get into the document window
sub addrootgroup
{

	my $q;
	my $r;
	my $deficon=getconfparam('defdocicon',$dbh);

	$r=$dbh->prepare("select cssid from hosts where hostid=?");
	$r->execute($hostid);
	my ($css)=$r->fetchrow_array();
	$r->finish();

	$r=$dbh->prepare('select title from templates where hostid=? and isdefault is true');
	$r->execute($hostid);
	my ($tpl)=$r->fetchrow_array();
	$r->finish();

	$q="insert into groups (".
		"hostid, groupname, groupid, parentid, template,".
		"cssid, icon, rssid, author, owner, comments,".
		"moderated, moderator, isdefault) ".
		"values ".
		"(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
	
	$r=$dbh->prepare($q);

	# Default values
	if( ! $r->execute($hostid,'root',0,0,$tpl,$css,$deficon,'none',$userid,$userid,0,1,$userid,1) ) {
		$msg=$dbh->errstr;
	}
	$r->finish();

	return $msg;

}

# Make a group "path" from the id
sub buildgroupfromid( )
{
	my ($hostid,$groupid)=@_;

	my $path='';
	my $q='select groupname,parentid from groups where hostid=? and groupid=?';
	my $s=$dbh->prepare($q);

	if( $debug ) {
		print STDERR "buildfromgroupid: searching group=$groupid...\n";
	}

	# loop on the groups and go back to the 'root'
	while(1) {

		$s->execute($hostid,$groupid);
		my ($g,$p)=$s->fetchrow_array();
		if( $p == $groupid ) {
			$path=~s/^\///;
			return $path;
		}
		$path=$g.$path;
		if( $debug ) {
			print STDERR "buildfromgroupid: found $g for $groupid, path is now $path\n";
		}
		$groupid=$p;
		$path="/".$path;
	}
}
