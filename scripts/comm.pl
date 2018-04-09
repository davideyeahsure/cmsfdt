#!/usr/bin/perl
# Send reminder about un-approved comments. = only comments that
# are not marked as spam are sent
# 

use strict;
use DBI;
use Mail::Sendmail;
use Config::General;

require '/var/www/cms50/cgi-bin/cmsfdtcommon.pl';

# open connection to the database.
my $dbh=dbconnect("/var/www/cms50/cgi-bin/cms50.conf");

# search for unapproved comments
my $q=(q{
	select 
	count(*) as num, d.hostid as host, d.documentid as documentid, 
	dc.title as title, u.email as email, u.name as name 
	from 
	comments c, documents d, documentscontent dc, users u 
	where
	d.comments=true and
	d.hostid=c.hostid and
	d.groupid=c.groupid and 
	d.documentid=c.documentid and 
	d.hostid=dc.hostid and
	d.groupid=dc.groupid and 
	d.documentid=dc.documentid and 
	c.approved=false and 
	c.spam=false and
	d.moderator=u.email 
	group by d.hostid,d.documentid,dc.title, u.email, u.name 
	order by u.email
});

my $s=$dbh->prepare($q);
$s->execute();

# loop
my $oldemail='';
my $oldname='';
my $document='';
my $olddoc='';

if( $s->rows > 0 ) {
	while( my $r=$s->fetchrow_hashref() ) {

		if ($oldemail eq '' ) {
			$oldemail=$r->{'email'};
			$oldname=$r->{'name'};
		}

		if( $oldemail ne $r->{'email'} ) {
			printletter( $oldname,$oldemail,$document );
			$oldemail=$r->{'email'};
			$oldname=$r->{'name'};
			$document='';
			$olddoc='';
		}

		if( $olddoc ne $r->{'documentid'} ) {
			$document.=$r->{'host'}.": \"$r->{'title'}\" commenti da approvare: $r->{'num'}\n";
			$olddoc=$r->{'documentid'};
		}

	}
	printletter($oldname,$oldemail,$document );
}
exit;

sub printletter()
{
	my $name=shift;
	my $email=shift;
	my $doc=shift;

	my $sub='Hai dei commenti da approvare...';
	my $msg='';
	my $reply='autopost@soft-land.org';

	$msg="Hey $name, solo per farti sapere che hai dei commenti da \n";
	$msg.="approvare su alcuni dei tuoi articoli.\n";
	$msg.="Non per metterti fretta ma... 'momento...\n";
	$msg.="Hummm... Davide dice: 'muovi il culo e dagli un'occhiata'...\n\n";
	$msg.="I documenti che hanno commenti sono i seguenti:\n\n";
	$msg.=$doc;
	$msg.="\nHoi, non prendertela con me eh... sono solo uno stupido programma.\n\n";
	$msg.="CMS FDT: https://cms.onlyforfun.net/cgi-bin/bo.pl\n";

	#print $msg;
	
	my %mail=(To=>$email, From=>$reply,Message=>$msg,Subject=>$sub);
	sendmail(%mail);
}
# And that's all folks!
