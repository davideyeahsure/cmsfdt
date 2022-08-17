#!/usr/bin/perl
# Also known as "CMS FDT V.5.0" (FdT=FaiDaTe=DoItYourself)
# by D.Bianchi 2008 - All rights reserved
# version 5.1.1 - Jan 2021
# See http://www.soft-land.org

use strict;
use lib(".");
use CGI qw/:standard/;
use DBI;
use Date::Parse;
use Date::Format;
use Config::General;
use LWP::UserAgent;


#use SWISH::API;			# << Swish is disabled in this version

require 'cmsfdtcommon.pl';

my $printed=0;

# open connection with the db
my $dbh=dbconnect("./cms50.conf");

my $ips=getconfparam('ips',$dbh);		# ips from which all documents are available
my $limit=getconfparam('limit',$dbh);		# how many posts in the 'journal'

my $base=adjustdir(getconfparam('base',$dbh));
my $iconsdir=adjustdir(getconfparam('iconsdir',$dbh));
my $cssdir=adjustdir(getconfparam('cssdir',$dbh));
my $dociconsdir=adjustdir(getconfparam('dociconsdir',$dbh));
my $avatardir=adjustdir(getconfparam('avatardir',$dbh));

my $defavatar=getconfparam('defavatar',$dbh);
my $debug=getconfparam('debug',$dbh);

# current user
my $user;
my $icon;
my $isroot;
my $issuperuser;
my $query=CGI->new;
my $myself=script_name();
my $preferredlanguage='';

# load the default language cookie (if any)
my $cookiename=getconfparam('cookiehost',$dbh);
my $cookies=$query->cookie($cookiename);
if($cookies) {
	(undef,undef,$preferredlanguage)=split /:/,$cookies;
}

if( $query->param('mode') eq 'logout' ) {
	logout($dbh,$preferredlanguage);
}

if ($query->param('mode') eq 'setpreferredlanguage' ) {
	# set language to ...
	$preferredlanguage=$query->param('language');
}

if( $query->param('mode') eq 'login' ) {
	login($query->param('email'),$query->param('password'),$preferredlanguage,$dbh,$query);
}

# get the current user (do not print header)
my ($userid,$user,$icon,$isroot) = getloggedinuser($dbh,1);

# this is 'the document'
my $section;			#section (group)
my $template;			#template
my $docid;			#document id

# various parameters that I setup now so I don't have to do it later...
my $ignore=0;
my @fields;
my $date=time2str("%d/%m/%Y",time);
my $year=time2str("%y",time);
my $dday=time2str("%Y%m%d",time);
my $uptime=getuptime();
my %FORM;

# get the host 
my $host=$query->param('host');
if( ! $host ) {
	$host=$ENV{'HTTP_HOST'};
}

my $deflang;
my $css;

my $q=(q{
	select h.hostid as hostid, h.deflang as deflang,
	c.filename as cssid from
	hosts h, hostaliases a, css c
	where h.hostid=a.hostid and c.cssid=h.cssid and a.alias like ?
	});
my $r=$dbh->prepare($q);
$r->execute($host);
if( $r->rows > 0 ) {
	($host,$deflang,$css)=$r->fetchrow_array();
}

# get the "preferred" languages from the browser, I'll check later if the
# language can be used or not.
my @lang;
my $x;
my $y=0;
foreach $x(split(/,/,$ENV{'HTTP_ACCEPT_LANGUAGE'})) {
	$x=~s/(..).*/\1/;
	$lang[$y++]=$x;
	if($debug) {
		print STDERR "lang ".$x.",";
	}
}

# if I got no languages, use the default one
if($y==0) {
	$lang[0]=$deflang;
}

# overwrite language with the preferred one.
if ($preferredlanguage ne '') {
	$lang[0]=$preferredlanguage;
}

# locate the default group and template for the host
my $defsection=locatedefaultgroup($host);
my $deftpl=locatedefaulttpl($host,$dbh);

if( $debug ) {
	print STDERR "Language: $lang[0]\n";
	print STDERR "Default section: $defsection\n";
	print STDERR "Default tpl: $deftpl\n";
}

# Get the IP from the client.
my $clientip=$query->remote_host();
if($debug) {
	print STDERR "Clientip: $clientip\n";
	print STDERR "Host: $host\n";
	print STDERR "Query:  $ENV{'QUERY_STRING'} \n";
}

# check if parameters passed
my @pairs = split( /&/, $ENV{'QUERY_STRING'});
my $pair;
my $FORM;
foreach $pair (@pairs)
{
	my ($name,$value)=split(/=/,$pair);
	$FORM{$name}=$value;
	if($debug) {
		print STDERR "param: $name - $value\n";
	}
}
# did I overrode the language? (useful sometimes)
if( $FORM{'language'}) {
	$lang[0]=$FORM{'language'};
}

# a year? if not, load with the current one
if(!$FORM{'year'}) {
	$FORM{'year'} = $year;
} else {
	# check if the year is actually a number
	if ($FORM{'year'} =~ /\D/) {
		# doesn't look like a year.
		print STDERR "Wrong year passed: $FORM{'year'} - overriding.\n";
		$FORM{'year'} = $year;
	}
}

# For previews, this will ignore the 'approved' status for a document
my @myips=split(/,/,$ips);
if( grep { $_ eq $clientip } @myips ) {
	$ignore=1;
	if($debug) {
		print STDERR "Ignore enabled.\n";
	}
}

# get the requested document or the default one.
if($FORM{'doc'}) {

	$docid=$FORM{'doc'};
	if( $docid =~ /\/$/ ) {
		$docid=~s/\/$//;
	}

} else {
	# no document, get the default one from the default group.
	$section=$defsection;
	$docid='';
}

if($debug) {
	print STDERR "Got group:".$section."\n";
	print STDERR "Got doc:".$docid."\n";
}

# check if the required URL is in a 'forbidden' list
my $forbid = getconfparam('forbidden',$dbh);
my @urls = split /,/,$forbid;
foreach my $u (@urls) {
	if( $docid =~ /$u/ || $ENV{'REQUEST_METHOD'} =~ /CONNECT/ ) {

		if ( $ENV{'REQUEST_METHOD'} =~ /CONNECT/ ) {
			$u = 'Connect used';
		}

		# get the IP that were used
		my $ip = $ENV{"HTTP_X_FORWARDED_FOR"};
		my $ip2 = $ENV{"REMOTE_ADDR"};

		if( $ip =~ /, / ) {
			# IP contains two of them, get the first one
			$ip =~ s/, .*$//;
		}

		# check if the IP is the localhost
		if( $ip eq '82.94.182.66' || $ip eq '127.0.0.1' ) {
			$ip=$ip2;
		}

		# check if the IP is still the localhost
		if( $ip ne '82.94.182.66' && $ip ne '127.0.0.1' ) {

			# report a forbidden url for the iP.
			print STDERR "FORBIDDEN '".$docid."' from $ip\n";

			# add entry to the firewall table with a counter for every request
			my $q='select count(*) from firewall where ip=?';
			my $t=$dbh->prepare($q);
			$t->execute($ip);
			my ($c)=$t->fetchrow_array();
			$t->finish();
			if( $c == 0 ) {
				$q='insert into firewall (ip, comment, enabled) values (?,?,true)';
				$t=$dbh->prepare($q);
				$t->execute($ip,$docid);
				$t->finish();
			} else {
				$q='update firewall set counter = counter+1, updated=now() where ip=?';
				$t=$dbh->prepare($q);
				$t->execute($ip);
				$t->finish();
			}
		}
		# stop processing here. No data will be sent to the requestor
		exit 0;
	}
}

# load the document and the template
my $document=searchdoc($host,$section,$docid,$ignore);

# now load the template
my $template=loadtpl($document->{'template'});

# load the CSS and the Javascript
$css='/'.$cssdir.'/'.$document->{'cssid'};
$css=~s/\/\//\//g;

my $js=getconfparam('js',$dbh);
my @scripts=split /;/,$js;

# Need to save a cookie with the default language, if it has been set.
# if the user has logged in, the cookie has been set already.
my $v1;
my $v2;
if($cookies) {
	($v1,$v2,undef)=split /:/,$cookies;
}
if (!$v1 || !$v2) {
	$v1='none';
	$v2='none';
}
$cookies=$query->cookie(
	-name 	 => $cookiename,
	-value	 => $v1.":".$v2.":".$preferredlanguage,
	-expires => '+1d',
	-secure	 => 0
);

if( $document->{'is404'} eq 1 ) {
	print $query->header(
		-type=>'text/html',
		-expires=>'0m',
		-status=>'404 Not Found',
		-charset=>'iso-8859-15',
		-cookie => [$cookies]
	);
} else {
	print $query->header(
		-type=>'text/html',
		-expires=>'0m',
		-status=>'200 OK',
		-charset=>'iso-8859-15',
		-cookie => [$cookies]
	);
}

print "<!doctype html public \"-//W3C//DTD HTML 4.01 Transitional//EN\"";
print "\"http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd\">\n";
print "<html>\n";
print "<!-- this document was produced with the (in)famous Cms FDT v. 5.0 -->\n";
print "<!-- by D.Bianchi (c) 2008-averyfarawaydate -->\n";
print "<!-- see http://www.soft-land.org/ -->\n";
print "<!-- currently loggedin as ".$userid." - ".$user." - root:".$isroot." - ".$preferredlanguage ."-->\n";
print "<head>\n";
print "<meta http-equiv='Content-type' content='text/html;charset=iso-8859-15' />\n";
print '<meta name="google-site-verification" content="r33YyzPGlgNzbUz6eNHHsApaDLICEOgZ3vl2GRugvZU" />'."\n";
print "<title>".$document->{'title'}."</title>\n";
print "<link rel='stylesheet' href='".$css."' type='text/css'>\n";
print "<link rel='shortcut icon' href='/img/".$host."/favicon.ico' type='image/x-icon'>\n";

foreach my $script (@scripts) {
	print "<script type='text/javascript' src='".$script."'></script>\n";
}

# close the head, begin the body
print "</head>\n";
print "<body>\n";

# get the link to the document, this will be used later (eventually)
my $q='select link from links where hostid=? and groupid=? and documentid=?';
my $r=$dbh->prepare($q);
$r->execute($document->{'hostid'},$document->{'groupid'},$document->{'documentid'});
my ($maindocname)=$r->fetchrow_array();
if($debug) {
	print STDERR "Search links where doc=".$document->{'hostid'}.",". $document->{'groupid'}.",".$document->{'documentid'}."\n";
	print STDERR "Found $maindocname<p>\n";
}

my $position="<a href='/'>[home]</a>";
my $tree='';
if( ! $document->{'isdefault'} ) {
	my @parts=split(/\//,$maindocname);
	foreach my $p (@parts) {
		$tree.=$p;
		if( $tree ne $maindocname ) {
			$tree.="/";
		}
		$position.="/<a href='/".$tree."'>".$p."</a>";
	}
}
$maindocname="/".$maindocname;
$r->finish();
my $referer=$ENV{'HTTP_REFERER'};

# now process the template and the document
processdoc($document,$template);

# now close the page nicely
print "</body>\n";
print "</html>\n";

# that's it folks!

exit 0;

#####################################################
# process the document, that can be a template, a content or whatever
# note that I use sometimes 'doc' (reference to the document that is being
# processed) and 'document' that is the MAIN document.
# this beacause the system call 'processdoc' multiple times to process
# other things, not just the mail document.
sub processdoc
{
	my ($doc,$tpl)=@_;

	# I get some data related to the documet right now, so they can be used
	# later
	if($debug) {
		print STDERR "Search for comments with doc=".$doc->{'hostid'}.",". $doc->{'groupid'}.",".$doc->{'documentid'}."\n";
	}
	my $nc=searchforcomments($doc->{'hostid'},$doc->{'groupid'},$doc->{'documentid'});

	# the icon need to contain the directory, otherwise it doesn't work...
	my $icon=showdocicon($doc->{'icon'});

	# get the link to this document, since it could be a fragment or a
	# list and I don't want to mix it up with the 'main' doc.
	my $q='select link from links where hostid=? and groupid=? and documentid=?';
	my $r=$dbh->prepare($q);
	$r->execute($doc->{'hostid'},$doc->{'groupid'},$doc->{'documentid'});
	my ($docname)=$r->fetchrow_array();
	$docname="/".$docname;
	if($debug) {
		print STDERR "Search links where doc=".$doc->{'hostid'}.",".$doc->{'groupid'}.",".$doc->{'documentid'}."\n";
		print STDERR "Found document '".$docname."'\n";
	}

	# build a date with the correct formatting
	my $docdate=convdate($doc->{'updated'});

	if($debug) {
		print STDERR "Processing document: '".$docname."'\n";
	}

	# If I have a template, start with the template, otherwise go for the real thing.
	my @lines;
	if($tpl) {
		@lines = split( /\n/, $tpl->{'content'});
	} else {
		@lines = split( /\n/, $doc->{'content'});
	}

	my $line;
	my $striphtml;

	# process one line at a time
	foreach $line (@lines) {

		chomp($line);

		# replace some variables into the line
		my $print=1;
		$line=~s/<!--title-->/$doc->{'title'}/;
		$line=~s/<!--data-->/$docdate/i;
		$line=~s/<!--updated-->/$docdate/i;
		$line=~s/<!--date-->/$date/i;
		$line=~s/<!--uptime-->/$uptime/i;
		$line=~s/<!--docname-->/$docname/i;
		$line=~s/<!--maindocname-->/$maindocname/i;
		$line=~s/<!--name-->/$doc->{'name'}/i;
		$line=~s/<!--excerpt-->/$doc->{'excerpt'}/i;
		$line=~s/<!--numcomments-->/$nc/i;
		$line=~s/<!--DOC-->/\//i;
		$line=~s/<!--referer-->/<a href="$referer">back<\/a>/i;
		$line=~s/<!--position-->/$position/i;
		$line=~s/<!--icon-->/$icon/i;

		# check if the line is an assignment and load the value
		if($line=~/<!--[^=-]+-->/) {
			my $var=$line;
			$var=~s/^.*<!--([^=-]+)-->.*$/\1/;
			if($FORM{"$var"}) {
				$line=~s/<!--$var-->/$FORM{"$var"}/g;
			}
		}

		$line=~s/<!--day-->/$dday/i;

		# check if the line has special meanings

		# load a canned text
		if( $line =~ /<!--getatext=/i ) {
			# load and display the text
			my $inc=$line;
			$inc=~s/.*<!--getatext=([^-]+)-->.*/$1/i;
			my $i=getatext($inc);
			$line=~s/<!--getatext=$inc-->/$i/i;
		}

		# build the sym link for a feed
		if( $line =~ /<!--feed=/i ) {
			my $inc=$line;
			$inc=~s/.*<!--feed=([^-]+)-->.*/$1/i;
			my $i=getfeed($inc);
			$line=~s/<!--feed=$inc-->/$i/i;
		}

		# search an image in the system and display it
		if( $line =~ /<!--img=[^-]+-->/i ) {
			my $inc=$line;
			my $imgid;
			my $param;
			my $link;
			$inc=~s/.*<!--img=([^-]+)-->.*$/$1/;
			($imgid,$param,$link) = split /:/,$inc;
			my $i=searchimage($imgid,$param,$link);
			$line=~s/<!--img=$inc-->/$i/i;
		}
		# search a video in the system and display it
		if( $line =~ /<!--video=[^-]+-->/i ) {
			my $inc=$line;
			my $imgid=$line;
			$imgid=~s/.*<!--video=([^-]+)-->.*$/$1/;
			my $i=searchvideo($imgid);
			$line=~s/<!--video=$imgid-->/$i/i;
		}

		# display a raw field from the document
		if( $line =~ /<!--field=[^-]+-->/i ) {
			my $inc=$line;
			$inc=~s/.*<!--field=([^-]+)-->.*$/$1/;
			my $i=$doc->{$inc};
			$line=~s/<!--field=$inc-->/$i/i;
		}

		# pointer to a previous document
		# NOTE: I use here the 'main' document, to avoid problems with 
		# includes and the like.
		if( $line =~ /<!--prev-->/ ) {
			if( $debug ) {
				print STDERR "Searching previous document\n";
			}
			
			my $prev=getprevious($document->{'hostid'},$document->{'groupid'},$document->{'documentid'});
			$line =~ s/<!--prev-->/$prev/;
		}

		# pointer to a next document
		# NOTE: I use here the 'main' document, to avoid problems with 
		# includes and the like.
		if( $line =~ /<!--next-->/ ) {
			if( $debug ) {
				print STDERR "Searching next document\n";
			}
			my $next=getnext($document->{'hostid'},$document->{'groupid'},$document->{'documentid'});
			$line =~ s/<!--next-->/$next/;
		}

		# include a 'fragment'
		if( $line =~ /<!--include=/ ) {
			my $inc=$line;
			$inc=~s/.*<!--include=(.*)-->.*$/$1/;
			$inc=include($inc);

			if( $debug ) {
				print STDERR "Including document '".$inc->{'title'}."'\n";
			}
		
			# here we go.
			processdoc($inc);
			$print=0;
		}

		# display a number of "stars"
		if( $line =~ /<!--stars-->/ ) {
			my $starnum=$doc->{'stars'};
			for(my $i=0;$i<$starnum;$i++) {
				print "<img src='/img/star.gif' alt='*'>";
			}
			$print=0;
		}

		# login/logout link
		if( $line =~ /<!--login-->/ ) {
			showlogin();
			$print=1;
		}

		# setup language link
		if ($line =~ /<!--setlang-->/ ) {
			setpreferredlang();
			$print=1;
		}

		if( $line =~ /<!--loginform-->/ ) {
			showloginform($userid);
			$print=0;
		}

		# search engine
		if( $line =~ /<!--search/ ) {
			my $ref=$line;
			$ref=~s/^.*<!--search=([^-]+)-->.*$/$1/;
			searches($ref);
			$print=0;
		}

		# search for a reference (other document referenced
		# by title instead of URL
		if( $line =~ /<!--ref=/ ) {
			my $ref=$line;
			$ref=~s/^.*<!--ref=(.*)-->.*$/$1/;
			$ref=reference($ref);
			$line=~s/<!--ref=(.*)-->/$ref/;
			$print=1;
		}

		# print author's data
		if( $line =~ /<!--author-->/ ) {
			my $ref=author($doc->{'author'});
			print $ref->{'content'};
			$print=0;
		}

		# here goes the document/content
		if( $line =~ /<!--text-->/ ) {
			if($printed eq 0) {

				# to avoid double calls (yes, I know)
				$printed++;

				# here we go again
				processdoc($document);
			}
			$print=0;
		}

		# show comments on this document
		if( $line =~ /<!--comments[^-]*-->/ ) {
			my $t=$line;
			$t=~s/.*<!--comments=(.*)-->.*/$1/;
			showcomments($document->{'hostid'},$document->{'groupid'},$document->{'documentid'},$t);
			$print=0;
		}

		# process a list of pages
		if($line=~/<!--process=/) {
			my $group=$line;
			$group=~s/.*<!--process=(.*)-->.*/$1/;
			my ($g,$t,$l)=split /:/,$group;
			process($host,$g);
			$print=0;
		}

		# show what are the last news
		if($line=~/<!--whatsupdoc=/) {
			my $group=$line;
			$group=~s/.*<!--whatsupdoc=(.*)-->.*/$1/;
			my ($g,$t,$l)=split /:/,$group;
			journal($host,$g,$t,$limit);
			$print=0;
		}

		# show a list of comments 'blog style'
		if($line=~/<!--journal=/) {
			my $group=$line;
			$group=~s/.*<!--journal=(.*)-->.*/$1/;
			my ($g,$t,$l)=split /:/,$group;
			# default $limit entries
			if(!$l) { $l=$limit; }
			journal($host,$g,$t,$l);
			$print=0;
		}

		# list a series of pages
		if($line=~/<!--list=/) {
			my $group=$line;
			$group=~s/.*<!--list=(.*)-->.*/$1/;
			my ($g,$t,$l)=split /:/,$group;
			list($host,$g,$t,$l);
			$print=0;
		}

		# special version of the 'process' bits just for the 'guests' tales'.
		if($line=~/<!--guests=/) {
			my $group=$line;
			$group=~s/.*<!--guests=(.*)-->.*/$1/;
			my ($g,$t,$l)=split /:/,$group;
			guests($host,$g,$t,$l);
			$print=0;
		}

		# print the icon link with the requested 'specials'
		if($line=~/<!--icon=/) {
			my $special=$line;
			my $i;
			$special=~s/.*<!--icon=(.*)-->.*/$1/;
			$i=showdocicon($doc->{'icon'},$special);
			$line=~s/<!--icon=[^-]+-->/$i/;
			$print=1;
		}

		# turn on or off html-tag stripping, useful for the '<pre>'
		# block
		if($line=~/<!--HTML-->/) {
			if($striphtml==1) {
				$striphtml=0;
			} else {
				$striphtml=1;
			}
			$print=0;
		}

		# no special meanings? print the line!
		if($print) {

			# should I strip html-tags?
			if($striphtml==1) {
				$line=~s/</\&lt;/g;
				$line=~s/>/\&gt;/g;
				$line=~s/\&/\&amp;/g;
			}
			print "$line\n";
		}
	}
}

# search for the given document in the given language, return the found 
# document or the default not found one.
sub searchdoc() {

	my ($hostid,$groupid,$documentid,$ignore)=@_;
	my $r;
	
	if($debug) {
		print STDERR "Searching for ".$hostid." - ".$groupid."/".$documentid. " with ignore=".$ignore."\n";
	}

	# Now, since I added the Links, is going to be easy: I just look up
	# in the links
	my $q=(q{
		select d.hostid as hostid, d.groupid as groupid, d.documentid as documentid,
		d.template as template, c.filename as cssid, d.icon as icon, d.rssid as rssid, 
		d.author as author, d.moderator as moderator, d.moderated as moderated,
		d.comments as comments, d.isdefault as isdefault, d.is404 as is404, 
		d.display as display, d.created as created, d.updated as updated,
		l.link as link,
		dc.language as language, dc.title as title, dc.excerpt as excerpt,
		dc.content as content, dc.approved as approved
		from
		documents d, links l, documentscontent dc, css c where
		d.cssid=c.cssid and
		l.hostid=d.hostid and l.groupid=d.groupid and
		l.documentid=d.documentid and
		dc.hostid=d.hostid and dc.groupid=d.groupid and dc.documentid=d.documentid and
		l.hostid=? and l.link=?
	});

	# Am I root? If so, no problem,
	if( ! $isroot && ! $ignore ) {
		# Only approved documents or the user's documents.
		$q.=" and (dc.approved=true or d.author=?)";
	}
	
	my $sth=$dbh->prepare($q);
	my $link=$groupid."/".$documentid;
	$link=~s/^\///;
	
	if($debug) {
		print STDERR "Query: $q , $hostid, $link, $userid\n";
	}

	if( ! $isroot && ! $ignore ) {
		$sth->execute($hostid,$link,$userid);
	} else {
		$sth->execute($hostid,$link);
	}
	
	if( $sth->rows == 0 ) {
		if ($debug) {
			print STDERR "No documents found.\n";
		}
		$sth->finish();
		# no such document, get the default one for the group (if any)
		$q=(q{
		select d.hostid as hostid, d.groupid as groupid, d.documentid as documentid,
		d.template as template, c.filename as cssid, d.icon as icon, d.rssid as rssid, 
		d.author as author, d.moderator as moderator, d.moderated as moderated,
		d.comments as comments, d.isdefault as isdefault, d.is404 as is404, 
		d.display as display, d.created as created, d.updated as updated,
		l.link as link,
		dc.language as language, dc.title as title, dc.excerpt as excerpt,
		dc.content as content, dc.approved as approved
		from
		documents d, links l, documentscontent dc, css c where
		d.cssid=c.cssid and
		l.hostid=d.hostid and l.groupid=d.groupid and
		l.documentid=d.documentid and
		dc.hostid=d.hostid and dc.groupid=d.groupid and dc.documentid=d.documentid and
		d.isdefault=true and
		l.hostid=? and l.groupid=?
		});

		$sth=$dbh->prepare($q);
		$sth->execute($hostid,$groupid);
		if( $sth->rows == 0 ) {
			# not even that! search the 404!
			$sth->finish();
		
			$q=(q{
			select d.hostid as hostid, d.groupid as groupid, d.documentid as documentid,
			d.template as template, c.filename as cssid, d.icon as icon, d.rssid as rssid, 
			d.author as author, d.moderator as moderator, d.moderated as moderated,
			d.comments as comments, d.isdefault as isdefault, d.is404 as is404, 
			d.display as display, d.created as created, d.updated as updated,
			l.link as link,
			dc.language as language, dc.title as title, dc.excerpt as excerpt,
			dc.content as content, dc.approved as approved
			from
			documents d, links l, documentscontent dc, css c where
			d.cssid=c.cssid and
			l.hostid=d.hostid and l.groupid=d.groupid and
			l.documentid=d.documentid and
			dc.hostid=d.hostid and dc.groupid=d.groupid and dc.documentid=d.documentid and
			d.is404=true and
			l.hostid=? and l.groupid=?
			});
			$sth=$dbh->prepare($q);
			$sth->execute($hostid,$groupid);
			if( $sth->rows == 0 ) {
				$sth->finish();
				# holy camoly!
				$q=(q{
				select d.hostid as hostid, d.groupid as groupid, d.documentid as documentid,
				d.template as template, c.filename as cssid, d.icon as icon, d.rssid as rssid, 
				d.author as author, d.moderator as moderator, d.moderated as moderated,
				d.comments as comments, d.isdefault as isdefault, d.is404 as is404, 
				d.display as display, d.created as created, d.updated as updated,
				l.link as link,
				dc.language as language, dc.title as title, dc.excerpt as excerpt,
				dc.content as content, dc.approved as approved
				from
				documents d, links l, documentscontent dc, css c where
				l.hostid=d.hostid and l.groupid=d.groupid and
				l.documentid=d.documentid and
				dc.hostid=d.hostid and dc.groupid=d.groupid and dc.documentid=d.documentid and
				d.is404=true and d.cssid=c.cssid and
				l.hostid=?
				});
				
				$sth=$dbh->prepare($q);
				$sth->execute($hostid);
				if( $sth->rows == 0 ) {
					# ok, I give up!
					$sth->finish();
					$r->{'hostid'}=$hostid;
					$r->{'groupid'}=$groupid;
					$r->{'documentid'}=-1;
					$r->{'language'}=$deflang;
					$r->{'template'}=$deftpl;
					$r->{'cssid'}=$css;
					$r->{'icon'}='';
					$r->{'rssid'}='';
					$r->{'display'}=1;
					$r->{'approved'}=1;
					$r->{'comments'}=0;
					$r->{'moderated'}=0;
					$r->{'moderator'}='';
					$r->{'author'}='';
					$r->{'created'}=$date;
					$r->{'updated'}=$date;
					$r->{'title'}='Document not found';
					$r->{'excerpt'}="The document couldn't be found, in addition, there is no default document and no 'not found' document could be found either!";
					$r->{'content'}=(q{
						<h1>NOT FOUND</h1>
						The document you were looking for couldn't be found on this system.<br>
						In addition, no <i>default</i> document could be found for the site and no
						<i>error</i> document either.<p>
						This page was automatically generated.<p>
					});
					$r->{'isdefault'}=1;
					$r->{'is404'}=1;
					return $r;
				}
			}
		}
	}
	$r=searchtherightone($sth);
	$sth->finish();
	if($debug) {
		print STDERR "got doc $r->{'title'}\n";
	}
	return $r;

}

# Load the given template in the right language.
sub loadtpl 
{

	my $tpl = shift;
	my $t;

	if($debug) {
		print STDERR "Loading template $tpl\n";
	}

	# prepare a default template in any case..
	$t->{'templateid'}='autogenerated';
	$t->{'language'}=$deflang;
	$t->{'content'}="<!--text-->";
	$t->{'name'}='autogenerated';
	$t->{'updated'}='01-01-2008';
	$t->{'created'}='01-01-2008';

	# Updated 4/1/09: template have no language
	my $q='select * from templates where hostid=? and title=?';
	my $sth=$dbh->prepare($q);
	my $r=$sth->execute($host,$tpl);
	if( ! $r ) {
		print STDERR "Error searching for the template!\n";
		$sth->finish();
		return $t;
	}
	if ( $sth->rows == 0 ) {
		# nope, template doesn't exists, get default
		if( $debug ) {
			print STDERR "Template not found, returning default.\n";
		}
		$sth->finish();
		$sth->execute($host,$deftpl);
	}
	if( $sth->rows > 0 ) {
		# get it
		$t=$sth->fetchrow_hashref();
	}
	$sth->finish();
	return $t;
}

# load infos for the author from the User's table
sub author() 
{
	my $author=shift;

	if( $debug ) {
		print STDERR "Loading author information for $author.\n";
	}
	my $q="select * from userdesc where email=?";
	my $sth=$dbh->prepare($q);
	if( ! $sth->execute($author) ) {
		if( $debug ) {
			print STDERR "Error searching for an author!\n";
		}
		$sth->finish();
		exit 0;
	}
	return searchtherightone($sth);

}

# load a bit of text from the 'fragments' table
sub include
{
	my $include=shift();

	my $q="select * from fragments where hostid=? and fragid=?";
	my $sth=$dbh->prepare($q);

	if($debug) {
		print STDERR "Searching for a fragment $include \n";
	}

	if( ! $sth->execute($host,$include) ) {
		if( $debug ) {
			print STDERR "Error searching for the fragment\n";
		}
		$sth->finish();
		exit 0;
	}

	return searchtherightone($sth);
}

# Generate a list of pages with a canned template, including an excerpt
# of the document, who wrote it and so on
sub process
{
	my ($hostid,$group) = @_;
	my $t;

	if( $debug ) {
		print STDERR "Processing a list with canned template for hostid=$hostid and group $group.\n";
	}

	# build a default template for the list
	$t->{'templateid'}='extendedlist';
	$t->{'title'}='extendedlist';
	$t->{'language'}=$deflang;
	$t->{'content'}=(q{
<div class='doctitle'>
<a href='<!--docname-->'><!--title--></a></div>
<div class='docdetails'>
<!--getatext=by-->
<!--field=name-->
<!--getatext=updated-->
<!--updated-->
-
<!--numcomments-->
</div>
<div class='docexcerpt'>
<!--excerpt-->
</div>
<p>
});
	$t->{'name'}='default list';
	$t->{'updated'}='01-01-2008';
	$t->{'created'}='01-01-2008';

	# now call the 'list' function to do the job
	dolist($hostid,$group,$t,999);
}

# Generate a list of pages in a group from the db applying a given template
# to display each line
# Can be given a limit on the number of record to display
sub dolist
{
	my ($hostid,$group,$tpl,$limit)=@_;

	# get the groupid corresponding to this group
	my $g=getgroupidfrompath($hostid,$group,$dbh);
	
	# the template is loaded by the wrapper function.
	if( $debug ) {
		print STDERR "Going to process group $g ($group)\n";
		print STDERR "Tpl for dolist: ". $tpl->{'title'}."\n";
	}

	my $q=(q{
       	select d.hostid as hostid, d.groupid as groupid, d.documentid as documentid,
	d.template as template, c.filename as cssid, d.icon as icon, d.rssid as rssid, 
	d.author as author, d.moderator as moderator, d.moderated as moderated,
	d.comments as comments, d.isdefault as isdefault, d.is404 as is404, 
	d.display as display, d.created as created, d.updated as updated,
	dc.language as language, dc.title as title, dc.excerpt as excerpt,
	dc.content as content, dc.approved as approved
	from
	documents d, documentscontent dc, css c where
	d.cssid=c.cssid and 
	dc.hostid=d.hostid and dc.groupid=d.groupid and dc.documentid=d.documentid and
	d.hostid=? and d.groupid=? and d.display=true
	});

	if( ! $isroot && ! $ignore ) {
		$q.=" and (dc.approved=true or d.author=?) ";
	}
	$q.=" order by d.documentid,d.updated desc";

	my $sth=$dbh->prepare($q);
	if( $debug ) {
		print STDERR "Query: $q\n";
	}
	if( ! $isroot && ! $ignore ) {
		$sth->execute($hostid,$g,$userid);
	} else {
		$sth->execute($hostid,$g);
	}
	if( ! $sth ) {
		print STDERR "Error listing documents!\n";
		$sth->finish();
		return;
	}

	if( $sth->rows > 0 ) {

		if( $debug ) {
			print STDERR "Found ".$sth->rows." documents.\n";
		}

		# Ok, we've got documents, for each one, search the one in the right language
		my $did;
		while( my $r=$sth->fetchrow_hashref() ) {

			# one document only, if I have multiple language, one is enough
			next if( $r->{'documentid'} eq $did );
			$did=$r->{'documentid'};

			# get the document and the user name for reference
			my $q=(q{
				select d.*,dc.language as language, dc.content as content,dc.title as title,
				dc.excerpt as excerpt,u.name from documents d, users u, documentscontent dc
				where d.author=u.email and
				d.hostid=dc.hostid and d.groupid=dc.groupid and d.documentid=dc.documentid and
				d.hostid=? and d.groupid=? and d.documentid=?
			});

			# get the document in the correct language
			my $s=$dbh->prepare($q);
			if($s->execute($hostid,$g,$r->{'documentid'}) ) {
				# ok, get the right one...
				my $r=searchtherightone($s);
				processdoc($r,$tpl);

			} else {
				$s->finish();
				print 'error searching the document.\n';
			}
		}
	} else {

		if( $debug ) {
			print STDERR "no documents found!\n";
		}	
		print getatext('nothinghere','nothing here');
	}
	$sth->finish();
	return;

}

# Generate a list of pages in a group from the db applying a given template
# to display each line or using a default one.
# Can be given a limit on the number of record to display
sub list
{
	my ($hostid,$group,$tpl,$limit) = @_;

	# if I defined a template for the list, load it otherwise
	# just build one.
	if(! defined $tpl) {
		# build a default template for the list
		$tpl->{'templateid'}='defaultlist';
		$tpl->{'title'}='defaultlist';
		$tpl->{'language'}=$deflang;
		$tpl->{'content'}=
		"<div class='list'><a href='<!--docname-->'><!--title--></a></div>\n";
		$tpl->{'name'}='default list';
		$tpl->{'updated'}='01-01-2008';
		$tpl->{'created'}='01-01-2008';
	} else {
		# load the template
		$tpl=loadtpl($tpl);
	}

	# now do it
	dolist($hostid,$group,$tpl,$limit);
	return;
}

# Special version of the 'list' function just for the 'guest's tales'.
sub guests
{
	my ($hostid,$group,$tpl) = @_;
	my $t;

	my $g=getgroupidfrompath($hostid,$group,$dbh);
	
	# if I defined a template for the list, load it
	if($tpl) {
		$t=loadtpl($tpl);
	} else {
		# build a default template for the list
		$t->{'templateid'}='defaultlist';
		$t->{'title'}='defaultlist';
		$t->{'content'}=
		"<span class='list'><a href='<!--docname-->'><!--title--></a></span>, \n";
		$t->{'name'}='default list';
		$t->{'updated'}='01-01-2008';
		$t->{'created'}='01-01-2008';
	}

	my $q=(q{
       	select d.hostid as hostid, d.groupid as groupid, d.documentid as documentid,
	d.template as template, d.cssid as cssid, d.icon as icon, d.rssid as rssid, 
	d.author as author, d.moderator as moderator, d.moderated as moderated,
	d.comments as comments, d.isdefault as isdefault, d.is404 as is404, 
	d.display as display, d.created as created, d.updated as updated,
	dc.language as language, dc.title as title, dc.excerpt as excerpt,
	dc.content as content, dc.approved as approved, u.name as name
	from
	documents d, documentscontent dc, users u, css c where
	d.cssid=c.cssid and
	dc.hostid=d.hostid and dc.groupid=d.groupid and 
	dc.documentid=d.documentid and d.author=u.email and 
	d.display=true and 
	d.hostid=? and d.groupid=?
	});

	if( ! $ignore && ! $isroot ) {
		$q.=" and (approved=true or author=?)";
	}
	$q.=" order by u.name,d.updated,dc.title,dc.language desc";

	if($debug) {
		print STDERR "Query: ".$q." - ".$group.",".$userid."\n";
	}

	my $sth=$dbh->prepare($q);
	if( ! $ignore && ! $isroot ) {
		$sth->execute($hostid,$g,$userid);
	} else {
		$sth->execute($hostid,$g);
	}

	if( ! $sth ) {
		print "Error listing guest's documents!<br>\n";
		$sth->finish();
		exit 0;
	}

	if( $sth->rows > 0 ) {

		if($debug) {
			print STDERR "Found ".$sth->rows." rows\n";
		}

		# Ok, we've got documents, for each one, search the one in the right language
		my $did;
		my $author;

		while( my $r=$sth->fetchrow_hashref() ) {

			# skip on same document
			next if( $r->{'documentid'} eq $did );
			$did=$r->{'documentid'};

			if( $debug ) {
				print STDERR "Processing $r->{'author'}, $r->{'groupid'}, $r->{'documentid'}, $r->{'title'}\n";
			}

			my $q=(q{
				select 
				d.*,dc.language as language, dc.content as content,dc.title as title,
				dc.excerpt as excerpt, u.name as name
				from 
				documents d, users u, documentscontent dc
				where 
				d.author=u.email and
				d.hostid=dc.hostid and d.groupid=dc.groupid and d.documentid=dc.documentid and
				d.hostid=? and d.groupid=? and d.documentid=?
			});
			if( ! $ignore && ! $isroot ) {
				$q.=" and (dc.approved=true or author=?)";
			}
			if( $debug ) {
				print STDERR $q."\n";
			}
			my $s=$dbh->prepare($q);
			if( ! $ignore && ! $isroot ) {
				$s->execute($hostid,$r->{'groupid'},$r->{'documentid'},$userid);
			} else {
				$s->execute($hostid,$r->{'groupid'},$r->{'documentid'});
			}

			if( $s->rows() > 0 ) {

				# ok, get the right one...
				my $r=searchtherightone($s);

				if( $debug ) {
					print STDERR "Current author: $author, new author: $r->{'author'}\n";
				}
				# print author if break
				if( $author ne $r->{'author'} ) {

					if($debug) {
						print STDERR "Break on author ".$author."\n";
					}

					$author=$r->{'author'};
					print "<p><div class='guests'>";
					print getatext('by','by')." ";
					print $r->{'name'}.": ";
					print "</div>\n";
				}

				# show it
				processdoc($r,$t);
			} else {
				if( $debug ) {
					print STDERR "Can't search a language!\n";
				}
			}
		}
	}
	$sth->finish();

}

# Print a list of documents as a 'journal', the list is sorted by
# publication date in reverse order (newer first)
# only the first <limit> posts are printed.
sub journal
{
	my ($hostid,$group,$tpl,$l)=@_;
	my $t;

	my $g=getgroupidfrompath($hostid,$group,$dbh);
	
	if( $debug ) {
		print STDERR "Searching for a journal named '".$group. "' to print with a tpl $tpl limit $l.\n";
	}

	# load the template or get the default one
	if( $tpl ) {
		$t=loadtpl($tpl);
	} else {
		if($debug) {
			print STDERR "Building a default template.\n";
		}
		# build a default template for the list
		$t->{'templateid'}='defaultjournal';
		$t->{'title'}='defaultjournal';
		$t->{'language'}=$deflang;
		$t->{'content'}=
			"<span>".
			"<!--icon=align='left'-->".
			"<h4><a href='<!--docname-->'>".
			"<!--title-->".
			"</a></h4></span>\n".
			"<div class='docdetails'>\n".
			"<!--getatext=by-->\n".
			"<!--name-->,\n".
			"<!--getatext=updated-->\n".
			"<!--updated-->,\n".
			"<!--numcomments-->\n".
			"</div>\n".
			"<div class='docdesc'><!--excerpt--></div>\n".
			"<p>\n";
		$t->{'name'}='defaultjournal';
		$t->{'updated'}='01-01-2008';
		$t->{'created'}='01-01-2008';
	}

	my $q=(q{
	select distinct 
	d.groupid as groupid,d.documentid as documentid ,d.updated as updated from 
	documents d,documentscontent dc
	where 
	d.hostid=dc.hostid and d.groupid=dc.groupid and
	d.documentid=dc.documentid and d.display=true and
	d.display=true and
	d.hostid=? and d.groupid=?
	});

	if( ! $ignore && ! $isroot ) {
		$q.=" and (dc.approved=true or d.author=?) ";
	}

	$q.=" order by updated desc";

	my $sth=$dbh->prepare($q);
	if( ! $ignore && ! $isroot ) {
		$sth->execute($hostid,$g,$userid);
	} else {
		$sth->execute($hostid,$g);
	}

	if( !  $sth ) {
		$sth->finish();
		print "Error building the journal's list!<p>\n";
		return;
	}

	if( $sth->rows > 0 ) {

		if($debug) {
			print STDERR "Found ".$sth->rows ." rows.\n";
		}

		my $count=0;
		my $did;

		while( my $r=$sth->fetchrow_hashref()) {

			next if($did eq $r->{'documentid'});
			$did=$r->{'documentid'};

			my $q=(q{
				select d.*,dc.language as language, dc.content as content,dc.title as title,
				dc.excerpt as excerpt,u.name from documents d, users u, documentscontent dc
				where d.author=u.email and
				d.hostid=dc.hostid and d.groupid=dc.groupid and d.documentid=dc.documentid and
				d.hostid=? and d.groupid=? and d.documentid=?
			});
			if( ! $ignore && ! $isroot ) {
				$q.=" and (dc.approved=true or author=?) ";
			}
			$q.=" order by language, updated desc";
			if( $debug ) {
				print STDERR "Query: ".$q."\n";
			}
			my $s=$dbh->prepare($q);
			if( ! $ignore && ! $isroot ) {
				$s->execute($hostid,$r->{'groupid'},$r->{'documentid'},$userid);
			} else {
				$s->execute($hostid,$r->{'groupid'},$r->{'documentid'});
			}
			if( ! $s ) {
				print "Error searching for documents!\n";
				exit 0;
			}
			my $x=searchtherightone($s);

			# show data
			processdoc($x,$t);

			$count++;
			if( $l && $count == $l) {
				$sth->finish();
				return;
			}
		}
	}
	$sth->finish();
}

# try to get the 'next' page and return the id
sub getnext
{
	my ($hostid,$groupid,$docid)=@_;
	my $text='';

	if($debug) {
		print STDERR "Searching for the next document of ".  $hostid."-".$groupid."/".$docid."\n";
	}

	my $q=(q{
		select link from 
		links l, documents d, documentscontent dc
		where
		l.hostid=d.hostid and l.groupid=d.groupid and
		l.documentid=d.documentid and 
		l.hostid=dc.hostid and l.groupid=dc.groupid and
		l.documentid=dc.documentid and 
		d.hostid=? and d.groupid=? and d.documentid > ?
		and d.display=true
	});
	if( $ignore==0 ) {
		$q.=" and approved=true";
	}
	$q.=" order by l.groupid,l.documentid asc limit 1";

	my $next=getatext('next','next');
	my $sth=$dbh->prepare($q);

	if( ! $sth->execute($hostid,$groupid,$docid) ) {
		$sth->finish();
		print "Can't search for the next document!\n";
		exit 0;
	}
	if( $sth->rows > 0 ) {
		my $defr;
		my $r=$sth->fetchrow_hashref();
		if($debug) {
			print STDERR "Found ".$sth->{'link'}."\n";
		}
		
		# good, now get the link
		$text="<span class='attention'>";
		$text.="<a href='/".$r->{'link'}."'>";
		$text.=$next;
		$text.="</a></span>";
	}

	$sth->finish();
	return $text;
}

# try to get the 'previous' page and return the id
sub getprevious
{
	my ($hostid,$groupid,$docid)=@_;
	my $text="";

	if($debug) {
		print STDERR "Searching previous document for ".$groupid."/".$docid."\n";
	}

	my $q=(q{
		select link from 
		links l, documents d, documentscontent dc
		where
		l.hostid=d.hostid and l.groupid=d.groupid and
		l.documentid=d.documentid and 
		l.hostid=dc.hostid and l.groupid=dc.groupid and
		l.documentid=dc.documentid and 
		d.hostid=? and d.groupid=? and d.documentid < ?
		and d.display=true
	});
	if( $ignore==0 ) {
		$q.=" and dc.approved=true";
	}
	$q.=" order by l.groupid,l.documentid desc limit 1";

	my $next=getatext('previous','previous');
	my $sth=$dbh->prepare($q);
	if( ! $sth->execute($hostid,$groupid,$docid) ) {
		$sth->finish();
		print "Can't search for the next document!\n";
		exit 0;
	}
	if($debug) {
		print STDERR "found ".$sth->rows." docs\n";
	}

	if( $sth->rows > 0 ) {
		my $r=$sth->fetchrow_hashref();
		$text="<span class='attention'>";
		$text.="<a href='/".$r->{'link'}."'>";
		$text.=$next;
		$text.="</a></span>";
	}
	$sth->finish();
	return $text;
}

# Show comments on a page
# Apply a specific template to the display or a default one
# it can be given a limit to the entries to display
sub showcomments
{
	my ($hostid,$groupid,$docid,$tpl,$limit)=@_;

	if($debug) {
		print STDERR "Searching comments for ".$hostid."-".$groupid."/".$docid." with template $tpl\n";
	}

	# get the template or build a default one
	my $t;
	if( $tpl ) {
		$t=loadtpl($tpl);
	} else {
		$t=();
	}

	# search all the comments on this document to display the count
	my $q="select count(*) from comments where hostid=? and groupid=? and documentid=?";
	if( $ignore==0 ) {
		$q.=" and approved=true";
	}
	my $sth=$dbh->prepare($q);
	if(! $sth->execute($hostid,$groupid,$docid) ) {
		print "Error building the comment's list!\n";
		exit 0;
	}

	# show comments count
	my ($c)=$sth->fetchrow_array();
	$sth->finish();
	printmsgheader($c,$hostid,$groupid,$docid);

	# scan the comments with parentid=0 for this document.
	scancommentbyparentid(0,$hostid,$groupid,$docid);
	
	# if more than 5 messages, repeate the 'add new' links
	if( $c > 5 ) {
		printmsgheader($c,$hostid,$groupid,$docid);
	}

	return;

}

# print the "header" with the links to post new messages
sub printmsgheader
{
	my ($c,$hostid,$groupid,$docid)=@_;

	my $winw=getconfparam('commedit-fw',$dbh);
	my $winh=getconfparam('commedit-fh',$dbh);
	my $mess;

	print "<h6>";
	if( $c == 1 ) {
		print getatext('onemess','one message');
	} elsif( $c == 0 )  {
		print getatext('nomess','no messages');
	} else {
		print $c;
		print " ";
		print getatext('moremess','messages');
	}

	if( $document->{'comments'} ) {
		print " <span class='newcomment'>";
		print "<a href='/cgi-bin/postnew.pl?hostid=".$hostid."&groupid=".$groupid."&documentid=".$docid."' target='_blank'>";
		print getatext('postnew','post');
		print "</a>";
		print "</span>";
	} else {
		print " <span class='newcomment'>";
		print getatext('closed',' this document does not accept new posts');
		print "</span>";
	}
	print "</h6>\n";
	print "<hr>\n";
}

# loop through the comments with a given parentid for threading
sub scancommentbyparentid
{
	my ($pid,$hostid,$groupid,$documentid)=@_;

	if($debug) {
		print STDERR "Scanning comments with pid=".$pid."\n";
	}

	# search for all the comments with this parentid
	my $q=(q{
		select c.*, u.name, u.icon  from 
		comments c, users u 
		where 
		hostid=? and groupid=? and documentid=?
		and c.author=u.email
	});
	# if PID is 0, then I only have to print the comments where the
	# pid==cid, otherwise the comments where pid is NOT equal to cid!
	if( $pid ) {
 		$q.=" and parentid=? and commentid<>parentid";
	} else {
 		$q.=" and parentid=commentid";
	}
	if( ! $ignore ) {
		$q.=" and approved=true";
	}
	$q.=" order by commentid asc";

	my $r=$dbh->prepare($q);
	if( $pid ) {
		$r->execute($hostid,$groupid,$documentid,$pid);
	} else {
		$r->execute($hostid,$groupid,$documentid);
	}

	while( my $c=$r->fetchrow_hashref() ) {
		showasinglecomment($c);
		# now let's process all the "children" comments
		scancommentbyparentid($c->{'commentid'},$hostid,$groupid,$documentid);
	}

	$r->finish();
	return;

}

# show a single comment in the page, called by the scan function above
sub showasinglecomment
{
	my ($c)=@_;

	if($debug) {
		print STDERR "Showing comment ".$c->{'commentid'}." ".$c->{'parentid'}."\n";
	}

	# width and height of the edit window
	my $winw=getconfparam('commedit-fw',$dbh);
	my $winh=getconfparam('commedit-fh',$dbh);
	my $msg;

	# build a ref here
	my $cid="hostid=".$c->{'hostid'}."&#38;groupid=".$c->{'groupid'}.
		"&#38;documentid=".$c->{'documentid'}.
		"&#38;commentid=".$c->{'commentid'}.
		"&#38;parentid=".$c->{'parentid'};

	# Id for fast search
	my $id=$c->{'hostid'}."-".$c->{'groupid'}."-".$c->{'documentid'}."-".
		$c->{'commentid'}."-".$c->{'parentid'};

	if( $c->{'icon'} ne '' && $c->{'icon'} ne 'none' ) {
		print "<img src='".$avatardir."/".$c->{'icon'}."' width='24px' ";
		print "alt=\"".$c->{'username'}."\" align='left'>";
	}
	print "<p>\n";
	print getatext('by','by')." ";
	print "<b>".$c->{'username'}."</b>";
	print getatext('posted','posted')." ";
	print convdate($c->{'created'});
	if( $document->{'comments'} ) {
		# answer
		print " - ";
		print "<span class='command'>";
		print "<a href='/cgi-bin/postnew.pl?hostid=".$c->{'hostid'}."&groupid=".$c->{'groupid'}."&documentid=";
		print $c->{'documentid'}."&commentid=".$c->{'commentid'};
		print "&parentid=".$c->{'parentid'}."' target='_blank'>";
		print getatext('answer','answer');
		print "</a></span>";
	}
	print "</p>\n";
	print "<div class='msgtext'>";
	print processthecomment($c->{'content'},$dbh);
	print "</div>\n";
	print "<hr><p>\n";
	return 0;

}

########################################################################
# try to locate a section with the same name
sub thereisasection {

	my $s=shift();
	my $q='select count(*) as cont from documents where hostid=? and groupid=?';

	if($debug) {
		print STDERR "Searching for a section named ".$s."\n";
	}

	my $sth=$dbh->prepare($q);
	if( ! $sth->execute($host,$s) ) {
		print "Error trying to get a section.\n";
		exit 0;
	}
	my $r=$sth->fetchrow_hashref();
	my $c=$r->{'cont'};
	$sth->finish();
	return $c;
}

# calculate uptime
sub getuptime {
	my $uptime=`uptime`;
	return $uptime;
}

# try to locate a page by name and return a reference
sub reference {

	my $s=shift;
	my $q=(q{
		select link from
		links l,documentscontent d
		where
		l.hostid=d.hostid and l.groupid=d.groupid and
		l.documentid=d.documentid and
		d.hostid=? and d.title=?
	});
	my $x;
	my $sth=$dbh->prepare($q);
	if( ! $sth->execute($host,$s) || $sth->rows==0 ) {
		$x='';
	} else {
		# just get the first one, is enough.
		my $r=$sth->fetchrow_hashref();
		$x="<a href='/".$r->{'link'}."'>";
	}
	$sth->finish();
	return $x;
}

# Get an image from the db and build a suitable <img> tag
sub searchimage
{
	my $imgid=shift;
	my $param=shift;
	my $link=shift;
	my $q='select imageid,filename,created,alternate from images where hostid=? and imageid=?';
	my $x='image '.$imgid.' not found';

	if( $debug ) {
		print STDERR "Searching image '".$imgid."' with param ".$param."\n";
	}

	my $sth=$dbh->prepare($q);
	$sth->execute($host,$imgid);
	if( $sth->rows > 0 ) {
		my $r=$sth->fetchrow_hashref();
		if( $debug ) {
			print STDERR "Found '".$r->{'filename'}."'\n";
		}
		$x='';
		if( $link ) {
			$x="<a href='/img/".$host."/".$r->{'filename'}."' target='__blank'>";
		}
		$x.="<img src='/img/".$host."/thumbs/".$r->{'filename'}.
		"' alt='".$r->{'alternate'}."' title='".$r->{'alternate'}."' border='0' ".$param.">";
		if( $link ) {
			$x.="</a>";
		}

	}
	$sth->finish();
	if( $debug ) {
		print STDERR "Returning '".$x."'\n";
	}
	return $x;
}

# Get a video link from the db and build a suitable tag - this is a modified 'image' function
sub searchvideo
{
	my $vidid=shift;
	my $q='select filename from images where hostid=? and imageid=?';
	my $x='video '.$vidid.' not found';

	if( $debug ) {
		print STDERR "Searching video '".$host."-".$vidid."'\n";
		print STDERR $q."\n";
	}

	my $sth=$dbh->prepare($q);
	$sth->execute($host,$vidid);

	if( $sth->rows > 0 ) {

		my $r=$sth->fetchrow_hashref();
		if( $debug ) {
			print STDERR "found '".$r->{'filename'}."'\n";
		}

		$x="<a style='display:block;width:520px;height:330px;' id='player'> </a>\n";
		$x.="<script language='JavaScript'>\n";
		$x.="\$f('player', '/img/flowplayer-3.2.8.swf',{ \n";
		$x.="clip:{\n";
		$x.="     url: '/img/".$host."/".$r->{'filename'}."',\n";
		$x.="     autoPlay: false,\n";
		$x.="     autoBuffer: true,\n";
		$x.="},\n";
		$x.="plugins: {\n";
		$x.="controls: {\n";
		$x.="url:'/img/flowplayer.controls-3.2.8.swf',\n";
		$x.="timeColor: '#980118',\n";
		$x.="all: false,\n";
		$x.="play: true,\n";
		$x.="scrubber: true,\n";
		$x.="allowfullscreen: true,\n";
		$x.="}  \n";
		$x.="}\n";
		$x.="});\n";
		$x.="</script>\n";

	}
	$sth->finish();
	if( $debug ) {
		print STDERR "Returning '".$x."'\n";
	}
	return $x;
}

# Get a text from the 'deftexts' table
sub getatext 
{
	my $textid=shift;
	my $default=shift;
	my $q='select * from deftexts where hostid=? and textid=?';
	my $x;

	if( $debug ) {
		print STDERR "Searching default text for '".$textid."'\n";
	}

	my $sth=$dbh->prepare($q);
	$sth->execute($host,$textid);
	if( $sth->rows > 0 ) {
		if( $debug ) {
			print STDERR "Searching for the right one '".$textid."'\n";
		}	

		my $r=searchtherightone($sth);
		$x=$r->{'content'};
	} else {
		$x=$default;
	}
	$sth->finish();
	return $x;
}

# Search into a dataset of documents with language, the one that matches
# the preferred language of the user. Otherwise, it returns the default one.
sub searchtherightone
{
	my $sth=shift;
	my $x;

	# ok, we've got something...
	# see if there is one in the correct language
	my $r=$sth->fetchall_hashref('language');

	# check if there is a default language, if so, load it as default answer
	if( $r->{$deflang} ) {
		$x=$r->{$deflang};
	} else {
		# no default language available for this... thing. Get the one that exists.
		foreach my $key ($r) {
			for my $id ( keys %{$key} ) {
				$x=$r->{$id};
			}
		}
	}

	# loop on all user's defined languages and see if there is a match
	foreach my $l (@lang) {
		if( $r->{$l}->{'language'} ) {
			# found a match!
			if($debug) {
				print STDERR "Found right language '".$l."' for the document '".$r->{$l}->{'title'}."'\n";
			}
			$x=$r->{$l};
			return $x;
		}
	}

	# return the default or the 'first one'
	if($debug) {
		print STDERR "Returning default language for $x->{'title'}\n";
	}
	$sth->finish();
	return $x;
}

# Convert a date into the right format
sub convdate
{
	my $date=shift;
	my $format=getatext('dateformat','%d/%m/%Y %H:%M');
	my $d=str2time($date);

	return time2str($format,$d);
}

# search for the number of comments on a specific document
sub searchforcomments
{
	my ($hostid,$groupid,$documentid) = @_;
	my $rt="";
	if($debug) {
		print STDERR "Searching for comments for $hostid,$groupid/$documentid.\n";
	}
	my $q='select count(*) from comments where hostid=? and groupid=? and documentid=?';
	if($ignore==0) {
		$q.=" and approved=true";
	}
	my $r=$dbh->prepare($q);
	$r->execute($hostid,$groupid,$documentid);
	my ($s)=$r->fetchrow_array();
	if($debug) {
		print STDERR "Found $s comments.\n";
	}
	$r->finish();
	if($s == 0) {
		$rt=getatext('nomess','no messages');
	} elsif( $s == 1 ) {
		$rt=getatext('onemess','one message');
	} else {
		$rt=$s . " " . getatext('moremess','messages');
	}
	return $rt;
}

# show the set-preferred language entry
sub setpreferredlang()
{
	my $language;
	#=include('login');
	my @llist = split(/ /,getconfparam('languages',$dbh));

	$language->{'content'}=getatext('getlangprompt','Set language to:');
	$language->{'fragid'}='getlangprompt';
	$language->{'language'}=$deflang;
	$language->{'name'}='getlangprompt';
	$language->{'created'}='01-01-2009';

	foreach my $l (@llist) {
		$language->{'content'}.="<a href='/cgi-bin/doc.pl?mode=setpreferredlanguage&language=".$l."'>".$l."</a> ";
	}
	processdoc($language);
	return;
}

# show the login/logout entry
sub showlogin
{
	my $login;
	my $loginscript;
	my $logindefault=getconfparam('logindefault',$dbh);
	my $userdefault=getconfparam('userdefault',$dbh);

	# are we logged in? If so, I need a logout.
	# otherwise a login.
	if( $userid ne 'NONE' ) {
	
		if($debug) {
			print STDERR "Logout...\n";
		}

		# we are definitively logged in...
		$login=include('logout');
		$loginscript=getconfparam('logout',$dbh);
		if( $login->{'content'} eq '' ) {
		
			if($debug) {
				print STDERR "Building a default frag...\n";
			}

			# build a default fragment
			$login->{'fragid'}='defaultlogin';
			$login->{'language'}=$deflang;
			$login->{'content'}="<a href=''><span onclick='openwindow(\"".
			$loginscript."?email=".$userid."&#38;language=".$deflang."\",".
			"\"\",1000,630)' onmouseover=\"style.cursor='pointer'\">".
			"Logout/User Config</span></a>\n";
			$login->{'name'}='defaultlogin';
			$login->{'created'}='01-01-2009';
		}
	} else {
		if($debug) {
			print STDERR "Login...\n";
		}
		$login=include('login');
		$loginscript=getconfparam('login',$dbh);
		if( $login->{'content'} eq '' ) {
			if($debug) {
				print STDERR "Building a default frag...\n";
			}
			# build a default fragment
			$login->{'fragid'}='defaultlogin';
			$login->{'language'}=$deflang;
			$login->{'content'}="<a href=''><span onclick='openwindow(\"".
			$loginscript."\",\"\",780,530)' onmouseover=\"style.cursor='pointer'\">".
			"Login/Register</span></a>\n";
			$login->{'name'}='defaultlogin';
			$login->{'created'}='01-01-2009';
		}
	}

	# print the text
	processdoc($login);
	return;
}

# used to adjust a directory with the various '/'
sub adjustdir
{
	my $dir=shift;

	# add first slash
	$dir="/".$dir;
	# fix double slashes
	$dir=~s/\/\//\//g;
	return $dir;
}

# show an icon on screen.
# used to get rid of all the problems with directory/nodirectory in
# the icons options.
sub showdocicon
{
	my ($icon,$special)=@_;
	my $ret;

	if( $debug ) {
		print STDERR "Showing icon '".$icon."' with specials '".$special."'\n";
	}

	$icon=~s/^\///;
	$icon=~s/^.*\///;
	my $dociconsdir=getconfparam('dociconsdir',$dbh);
	$dociconsdir="/".$dociconsdir;
	$dociconsdir=~s/^\/\//\//;
	$dociconsdir=~s/\/$//;
	$ret="<img src='".$dociconsdir."/".$icon."' ".$special.">";
	return $ret;
}

# return the default group for the host
sub locatedefaultgroup
{
	my $hostid=shift;
	my $q="select groupid from groups where hostid=? and isdefault=true";
	my $r=$dbh->prepare($q);
	$r->execute($hostid);
	my ($g)=$r->fetchrow_array();
	$r->finish();
	return $g;
}

sub getfeed
{
	my $feedid=shift;
	my $q='select filename from rssfeeds where hostid=? and filename=?';
	my $r=$dbh->prepare($q);

	# add '.rss' to the filename
	if( $feedid !~ /\.rss$/ ) {
		$feedid.=".rss";
	}
	$r->execute($host,$feedid);
	my ($f)=$r->fetchrow_array();
	$r->finish();

	# now recover the main dir
	my $rssdir=getconfparam('rssfeeddir',$dbh);
	$f="/".$rssdir."/".$host."/".$f;
	$f=~s/\/\//\//g;

	return $f;
}

# function to perform a search in the database using the swish-e
# search engine. It require that the engine is working (of course)
sub searches
{

	# swish seems to have disappeared...
	return;

#	# get the template (if specified)
#	my $tpl=shift;
#	my $t;
#
#	# get the position of the index
#	my $swishdir=getconfparam('swishdir',$dbh);
#	if( ! $swishdir || ! -d $swishdir )  {
#		return;
#	}
#
#	# the index is in a subdir of $swishdir
#	my $index=$swishdir."/".$host."/index.swish-e";
#	if( ! -f $index ) {
#		return;
#	}
#	
#	my $words=$query->param('words');
#	if( $words eq '' ) {
#		return;
#	}
#
#	if( $debug ) {
#		print STDERR "Doing search with template '".$tpl."'\n";
#	}
#
#	if( $tpl ) {
#
#		# make a default template
#		$t->{'templateid'}='searchlist';
#		$t->{'title'}='searchlist';
#		$t->{'language'}=$deflang;
#		$t->{'content'}=(q{
#		<p>
#		<div class='doctitle'>
#		<a href='<!--docname-->'><!--title--></a>
#		<!--stars-->
#		</div>
#		<div class='docdetails'>
#		<!--getatext=by-->
#		<!--field=name-->
#		<!--getatext=updated-->
#		<!--updated-->
#		-
#		<!--numcomments-->
#		</div>
#		<div class='docexcerpt'>
#		<!--excerpt-->
#		</div>
#		</p>
#		});
#		$t->{'name'}='default search list';
#		$t->{'updated'}='01-01-2008';
#		$t->{'created'}='01-01-2008';
#	} else {
#		# load the template
#		$t=loadtpl($tpl);
#	}
#
#	# build the Swish object to search the index
#	my $swish=SWISH::API->new($index);
#	$swish->abort_last_error if $swish->Error;
#
#	my $result=$swish->query($words);
#	$swish->abort_last_error if $swish->Error;
#	my $hits=$result->hits;
#
#	if( ! $hits ) {
#		print "<p><b>\n";
#		print getatext('nothingfoundfor','No document matches your query.');
#		print "</b></p>\n";
#	} else {
#		my $f=getatext('docsfounds','Found %d documents matching your query.');
#		print "<p><b>\n";
#		printf($f, $hits );
#		print "</b></p>\n";
#
#		# prepare to search for the document's informations
#		my $q=(q{
#			select 
#				d.*, dc.language, dc.title, dc.excerpt, u.name 
#			from 
#				documents d, documentscontent dc, users u, links l
#			where 
#				dc.hostid=l.hostid and
#				dc.groupid=l.groupid and
#				dc.documentid=l.documentid and
#				d.author=u.email and
#				d.hostid=l.hostid and
#				d.groupid=l.groupid and
#				d.documentid=l.documentid and
#				dc.approved=true and 
#				l.link=?
#		});
#		my $r=$dbh->prepare($q);
#
#		while( my $tok=$result->next_result ) {
#
#			my $rank=$tok->property("swishrank");
#			my $title=$tok->property("swishtitle");
#			my $updated=$tok->property("swishlastmodified");
#			my $doc=$tok->property("swishdocpath");
#
#			# if the doc contains 'http...' it is not a
#			# relative link so I have to process it
#			if( $doc=~/host=/ ) {
#				$doc=~s/^.*doc=//;
#			}
#
#			my $stars;
#
#			# compute number of 'stars'
#			$stars=int($rank/200);
#
#			# if too long a document or not enough stars, don't display it.
#			if( length $title <= 60 && $stars > 0 ) {
#
#				# search the doc
#				my $d=$doc;
#				$d=~s/^http:\/\/[^\/]+\///;
#				$r->execute($d);
#
#				if( $r->rows > 0 ) {
#					# get one document with the right language
#					my $x=searchtherightone($r);
#					$x->{'stars'}=$stars;
#					processdoc($x,$t);
#				} 
#				$r->finish();
#			}
#		}
#	}
}
