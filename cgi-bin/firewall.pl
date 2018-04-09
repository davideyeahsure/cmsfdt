#!/usr/bin/perl -w
#
use strict;
use Config::General;
use DBI;
use CGI qw/:standard/;
use CGI::Cookie;
#use Shell qw(dig);
use Mail::Sendmail;

require '/var/www/cms50/cgi-bin/cmsfdtcommon.pl';

my $configfile='/var/www/cms50/cgi-bin/cms50.conf';
my $query=new CGI();
my $begin='';
my $myself=script_name();
my $ip=$query->param('ip') || '';
my $comment=$query->param('comment') || '';
my $srchip=$query->param('srchip') || '';
my $newip=$query->param('newip') || '';
my $mode=$query->param('mode') || '';
my $last=$query->param('last') || '';

# open connection to the db
my $dbh=dbconnect($configfile);
my $dsn;

my $dateformat=getconfparam('dateformat',$dbh);
my $iconsdir=getconfparam('iconsdir',$dbh);
my $delicon=$iconsdir."/".getconfparam('delicon',$dbh);
my $addicon=$iconsdir."/".getconfparam('addicon',$dbh);

my $mm=shift || '';
if( $mm eq 'do' ) {
	# dump a list of the ips in a file for processing
	my $sql='select ip from firewall where enabled is true order by ip ';
	my $s=$dbh->prepare($sql);
	$s->execute();
	system("/usr/sbin/iptables -F goaway");
	while( my ($r)=$s->fetchrow_array() ) {
		system("/usr/sbin/iptables -A goaway -s $r -j DROP");
	}
	$s->finish();
	exit 0;
}

# adjust the search mode
if( $srchip ne '' ) {
	# trim spaces
	$srchip=~s/ //g;
	if( $srchip !~ /%/ ) {
		$srchip.='%';
	}
}

# add a new ip in the table
if( $mode eq 'addanew' && $newip ne '' && $comment ne '' ) {
	my $sql='insert into firewall (ip,comment,enabled) values (?,?,true)';
	my $s=$dbh->prepare($sql);
	$s->execute($newip,$comment);
	$s->finish();
	$srchip=$newip;
	$mode='showall';
}

# remove an ip from the table
if( $mode eq 'delete' && $ip ne '' ) {
	my $sql='delete from firewall where ip=?';
	my $s=$dbh->prepare($sql);
	$s->execute($ip);
	$s->finish();
	$mode='showall';
}

# disable or enable an ip
if( $mode eq 'disable' && $ip ne '' ) {
	my $sql='update firewall set enabled=false where ip=?';
	my $s=$dbh->prepare($sql);
	$s->execute($ip);
	$s->finish();
	$mode='showall';
}
if( $mode eq 'enable' && $ip ne '' ) {
	my $sql='update firewall set enabled=true where ip=?';
	my $s=$dbh->prepare($sql);
	$s->execute($ip);
	$s->finish();
	$mode='showall';
}

if( $mode eq '' ) {
	$mode = 'showall';
}

print "Content-Type: text/html\n\n";
print "<html>\n";
print "<head>\n";
print "<title>Firewall Config</title>\n";
print "<head>\n";
print "<script language='javascript' src='/default.js'></script>\n";
print "<body>\n";

print "<hr>\n";
print "<a href='".$myself."'>show all</a> \n";
print "<a href='".$myself."?mode=addnew'>add new</a> \n";
#print "<a href='".$myself."?mode=activate'>activate</a> \n";
print "<hr>\n";

if ( $mode eq 'activate' ) {
	generate();
}

if( $mode eq 'addnew' ) {

	print "<form action='".$myself."' method='post'>\n";
	print "<input type='hidden' name='mode' value='addanew'>\n";
	print "<table width='100%'>\n";
	print "<tr><td>Ip/mask:</td> <td><input type='text' name='newip' value='' size='15'></td></tr>\n";
	print "<tr><td>comment:</td> <td><input type='text' name='comment' value='' size='50'></td></tr>\n";
	print "</table>\n";
	print "<input type='submit'>\n";
	print "</form>\n";

}

if( $mode eq 'showall' ) {
	showall();
}

print "</body>\n";
print "</html>\n";

exit 0;

sub showenabled
{

	my $enabled=shift;

	print "<input type='checkbox'";
	if( $enabled ) {
		print " checked ";
	} else {
		print " unchecked ";
	}
	print " onclick='javascript:submit()' ";
	print ">\n";

	return;

}

sub showall
{
	
	# count how many records we have
	my $sql='select count(*) as count from firewall';
	my $sth=$dbh->prepare($sql);
	$sth->execute();
	my ($tot)=$sth->fetchrow_array();
	$sth->finish();
	
	$begin=$query->param('begin') || '';
	if( $begin eq '' ) {
		$begin=0;
	}
	
	#now show them
	if( $srchip ne '' ) {
		# search for IP or comment
		if( $srchip =~ /^D/ ) {
			$srchip=~s/^D//;
			$sql="select text(ip) as ip,to_char(date,'".$dateformat.
			"') as date,comment,enabled from firewall where comment like ? order by comment";
		} else {
			$sql="select text(ip) as ip,to_char(date,'".$dateformat.
			"') as date,comment,enabled from firewall where text(ip) like ? order by ip";
		}
		$sth=$dbh->prepare($sql);
		$sth->execute($srchip);
	} else {
		if( $last ne '' ) {
			$sql="select text(ip) as ip,to_char(date,'".$dateformat.
			"') as date,comment,enabled from firewall ".
			" where date > now() - time '".$last."' ".
			"offset $begin";
		} else {
			$sql="select text(ip) as ip,to_char(date,'".$dateformat.
			"') as date,comment,enabled from firewall order by ip limit 30 ".
			"offset $begin";
		}
		$sth=$dbh->prepare($sql);
		$sth->execute();
	}
	
	print "<p>\n";
	print "Total: $tot records<br>\n";
	
	# show pagination commands
	for( my $pg=0; $pg < $tot; $pg+=30 ){
		if ( $pg == $begin && $srchip eq '' ) {
			print " $pg ";
		} else {
			print " <a href='".$myself."?begin=".$pg."'>$pg</a> \n";
		}
	}
	print "<hr>\n";

	# show 'last 15/30 minutes' link
	print "Show last ";
	print "<a href='".$myself."?last=00:15'>15 min</a> \n";
	print "<a href='".$myself."?last=00:30'>30 min</a> \n";
	print "<a href='".$myself."?last=01:00'>60 min</a> \n";
	print "<a href='".$myself."?last=06:00'>6 hours</a> \n";
	print "<a href='".$myself."?last=12:00'>12 hours</a> \n";
	print "<a href='".$myself."?last=24:00'>12 hours</a> \n";
	print "additions/changes - \n";
	
	# show search box
	print "<form name='search' action='".$myself."' method='post'>\n";
	print "<input type='text' name='srchip' value='' size='15'>\n";
	print "<input type='submit' value='search'>\n";
	print "</form>\n";
	print "</p>\n";
	print "<hr>\n";
	
	# show the records
	print "<table width='100%' boder='1' cellspacing='0' cellpadding='0'>\n";
	print "<tr>\n";
	print "<th align='left'>ip/mask</th>\n";
	print "<th align='left'>added</th>\n";
	print "<th align='left'>comment</th>\n";
	print "<th align='left'>&nbsp;</th>\n";
	print "</tr>\n";
	
	my $id;
	
	while( my $r=$sth->fetchrow_hashref() ) {
	
		$id='ip='.$r->{'ip'}."&amp;srchip=".$srchip;
		print "<tr>\n";
		print "<form action='/cgi-bin/firewall.pl' method='post'>\n";
		print "<inpyt type='hidden' name='mode' value='showall'>\n";
		if( $r->{'enabled'} ) {
			print "<input type='hidden' name='mode' value='disable'>\n";
		} else {
			print "<input type='hidden' name='mode' value='enable'>\n";
		}
		print "<input type='hidden' name='srchip' value='".$srchip."'>\n";
		print "<input type='hidden' name='begin' value='".$begin."'>\n";
		print "<input type='hidden' name='ip' value='".$r->{'ip'}."'>\n";
		print "<td>";
		showenabled($r->{'enabled'});
		print " ";
		print "</form>\n";
		print $r->{'ip'};
		print "</td>";
		print "<td>";
		print $r->{'date'};
		print "</td>";
		print "<td>";
		print $r->{'comment'};
		print "</td>";
		print "<td align='right'>";
		showminicommand2('delete',$delicon,"remove ip ".$r->{'ip'}." ?",
		$myself."?mode=delete&".$id,'');
		print "</td>";
		print "</tr>\n";
	}
	
	print "</table>\n";
	print "<hr>\n";

	return;

}

sub generate
{

	my $sql='select ip from firewall where enabled is true order by ip ';
	my $s=$dbh->prepare($sql);
	$s->execute();
	system( "/usr/sbin/iptables -F goaway");
}
