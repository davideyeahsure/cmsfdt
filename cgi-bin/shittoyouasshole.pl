#!/usr/bin/perl
# rude response to peoples trying to do nasty things.
#
use strict;
use CGI;
use DBI;
use Config::General;

require 'cmsfdtcommon.pl';

my $configfile='cms50.conf';
my $query=new CGI();
my $begin;
my $myself=script_name();

my $ip1=$ENV{"HTTP_X_FORWARDED_FOR"};
my $ip2=$ENV{"REMOTE_ADDR"};
my $ip='';

if( $ip1 && $ip1 ne '' ) {
	$ip=$ip1;
} else {
	$ip=$ip2;
}

if( ! $ip ) {
	print "Ip is null.\n";
	exit 0;
}

my $comment=$ENV{'reason'};
if( $comment eq '' ) {
	$comment=$ENV{"REQUEST_URI"};
	if( $comment eq '' ) {
		$comment='added automatically';
	}
}

# Check IP
$ip=~s/^.*, //;
if( $ip =~ /127.0.0.1/ || $ip =~ /^$/ || $ip=~ /82.94.182.66/ ) {
	if( $query->param('ip') ) {
		$ip=$query->param('ip');
		if( $ip =~ /127.0.0.1/ || $ip =~ /^$/ || $ip=~ /82.94.182.66/ ) {
			# Can't add mysel - broken!
			print "ERROR: IP is broken! $ip\n";
			exit 1;
		}
	}
}

my $dbh=dbconnect($configfile);
my $q='insert into firewall (ip,comment) values (?,?)';
my $s=$dbh->prepare($q);
$s->execute($ip,$comment);
$s->finish();

print "Content-Type: text/plain\n\n";
#print $ip1 ." ".$ip2."\n";
print "Eat shit asshole!\n";
print "Your IP ".$ip." will be banned.\n";
