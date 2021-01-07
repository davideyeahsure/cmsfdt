#!/usr/bin/perl
# CMS FDT 5.1.1 - Edit content using CKEditor 4.
# This form can edit a document, template, fragment, css or comment.
# actually, at the current state, comments have their own little bit.
#

use strict;
use DBI;
use CGI qw/:standard/;
use CGI::Cookie;
use Config::General;
use Date::Format;
use Date::Parse;

require 'cmsfdtcommon.pl';

my $myself=script_name();
my $query= new CGI();
my $clientip=$query->remote_host();
my $today=time2str("%Y-%m-%d",time);

my $dbh=dbconnect("./cms50.conf");
my $debug=getconfparam('debug',$dbh);

# Get parameters from the query
my $hostid=$query->param('hostid');
my $cssid=$query->param('cssid');
my $groupid=$query->param('groupid');
my $documentid=$query->param('documentid');
my $templateid=$query->param('templateid');
my $fragid=$query->param('fragid');
my $language=$query->param('language');
my $mode=$query->param('mode');
my $current=$query->param('current');
my $content=$query->param('content');

my $sth;

# get the info about the user
my ($userid,$user,$icon,$isroot) = getloggedinuser($dbh);

# show the header.
printheader($dbh);

my $q;
my $r;
my $c;

# so... what am I editing today?
if( $mode eq 'doedit' || $mode eq ' doeditandclose') {

	# do the editing
	if( $current eq 'documents' ) {
		# update the document
		$q='update documentscontent set content=? where hostid=? and groupid=? and documentid=? and language=?';
		$r=$dbh->prepare($q);
		$r->execute($content,$hostid,$groupid,$documentid,$language);
		$r->finish();
	}
	if( $current eq 'templates' ) {
		# update the template
		$q='update templates set content=? where hostid=? and title=?';
		$r=$dbh->prepare($q);
		$r->execute($content,$hostid,$templateid);
		$r->finish();
	}
	if( $current eq 'fragments' ) {
		# update the fragment
		$q='update fragments set content=? where hostid=? and fragid=? and language=?';
		$r=$dbh->prepare($q);
		$r->execute($content,$hostid,$fragid,$language);
		$r->finish();
	}
	if( $current eq 'css' ) {
		# update the CSS
		$q='select filename from css where cssid=?';
		$r=$dbh->prepare($q);
		$r->execute($cssid);
		my ($file)=$r->fetchrow_array();
		$r->finish();
		$file=getconfparam('base',$dbh)."/".getconfparam('cssdir',$dbh)."/".$file;
		$file=~s/\/\//\//g;
		open OUTFILE,">$file";
		print OUTFILE $content;
		close OUTFILE;
	}
	if( $current eq 'comment' ) {
		# update the comment
		# placeholder (momentarily it doesn't work
	}
	if( $mode eq 'doeditandclose' ) {
		exit 0;
	}
}

# Show the editing window
if( $current eq 'documents' ) {
	# get the doc
	$q='select content from documentscontent where hostid=? and groupid=? and documentid=? and language=?';
	$r=$dbh->prepare($q);
	$r->execute($hostid,$groupid,$documentid,$language);
}

if( $current eq 'templates' ) {
	# get the template
	$q='select content from templates where hostid=? and title=?';
	$r=$dbh->prepare($q);
	$r->execute($hostid,$templateid);
}

if( $current eq 'fragments' ) {
	# get the fragment
	$q='select content from fragments where hostid=? and fragid=? and language=?';
	$r=$dbh->prepare($q);
	$r->execute($hostid,$fragid,$language);
}

if( $current eq 'css' ) {
	# get the css
	$q='select filename from css where cssid=?';
	$r=$dbh->prepare($q);
	$r->execute($cssid);
	my ($file)=$r->fetchrow_array();
	$file=getconfparam('base',$dbh)."/".getconfparam('cssdir',$dbh)."/".$file;
	$file=~s/\/\//\//g;

	$r->finish();
	open INFILE,"<$file" || die("Can't open $file!\n");
	while(<INFILE>) {
		$c.=$_;
	}
	close INFILE;
} else {
	if( $r->rows > 0 ) {
		($c)=$r->fetchrow_array();
	} else {
		$c=$hostid."-".$groupid."-".$documentid."-".$templateid."-".$fragid."-".$language.":Not found...\n";
	}
}

print "<form method='post' action='".$myself."' name='doeditdoc'>\n";
print "<input type='hidden' name='hostid' value='".$hostid."'>\n";
print "<input type='hidden' name='cssid' value='".$cssid."'>\n";
print "<input type='hidden' name='groupid' value='".$groupid."'>\n";
print "<input type='hidden' name='documentid' value='".$documentid."'>\n";
print "<input type='hidden' name='fragid' value='".$fragid."'>\n";
print "<input type='hidden' name='templateid' value='".$templateid."'>\n";
print "<input type='hidden' name='language' value='".$language."'>\n";
print "<input type='hidden' name='current' value='".$current."'>\n";
print "<input type='hidden' name='mode' value='doedit'>\n";
print "<textarea id='content' name='content' cols='80' rows='60'>\n";
print $c;
print "</textarea>\n";

# enable Editor
print "<script type='text/javascript'>\n";

# initialize CKEditor adding the "file browser" to insert picture directly in the document
print " // <![CDATA[\n";
print "CKEDITOR.replace( 'content', {maximized: 1, filebrowserBrowseUrl: '/cgi-bin/browse.pl?hostid=".$hostid."' } );\n";
print " //]]>\n";

print "</script>\n";
print "<input type='button' name='save' value=' Save ' onclick='document.doeditdoc.submit()'>\n";
print "<input type='button' name='saveandclose' value=' Close ' onclick='window.close()'>\n";
print "</form>\n";
printfooter();

# end page
print "</body>\n";
print "</html>\n";
