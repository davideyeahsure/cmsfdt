#!/usr/bin/perl -w
# Image browser for inserting pictures directly into the posts

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
use lib (".");

# load common lib
require 'cmsfdtcommon.pl';

my $today=time2str("%Y-%m-%d %H:%M",time);
my $myself=script_name();
my $query=CGI->new;
my $dbh=dbconnect('./cms50.conf');
my $msg='';
my $debug=0;
my $current='imagebrowser';

my ($userid,$user,$icon,$isroot) = getloggedinuser($dbh);

# now show the header

printheader($dbh);

# now get the parameters that have been passed.
my $hostid=$query->param('hostid');
my $editor=$query->param('CKEditor');
my $func=$query->param('CKEditorFuncNum');
my $lang=$query->param('langCode');

# query to show the pictures
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
print "<script>\n";
print "function returnFile( link ) {\n";
print "	var num=".$func.";\n\n";
print "	window.opener.CKEDITOR.tools.callFunction( num, link );\n";
print " window.close();\n";
print "}\n";
print "</script>\n";
print "<table width='100%' bgcolor='lightgrey' border='0' cellspacing='0' cellpadding='5pt'>";
print "<tbody>\n";

if( $debug ) {
	print "Showing images ".$q." with hostid=".$hostid."<br>\n";
}

my $col=1;

my $r=$dbh->prepare($q);
$r->execute($hostid);
while( my $x=$r->fetchrow_hashref() ) {

	my $metatag='&lt;!--img='.$x->{'imageid'}."--&gt;";
	my $link="/img/".$hostid."/".$x->{'filename'};

	if( $col==1 ) {
		print "<tr>";
	}
	print "<td align='center' valign='middle'>";
	print "<img src='".$thumbdir."/".$x->{'filename'}."' height='128' border='1' onclick='returnFile(\"".$link."\")'><br>";
	print $link;
	print "</td>\n";

	if( $col==3 ) {
		print "</tr>\n";
		$col=1;
	} else {
		$col++;
	}

}
print "</tbody>\n";
print "</table>\n";
print "Click on an image to select it.";

# end page
print "</body>\n";
print "</html>\n";
