#!/usr/bin/perl

# publish a document in a given group for a given host
# part of the CMS Fdt 5.0 - (C) Davide Bianchi 2009.

use warnings;
use strict;

use DBI;
use Config::General;

require '../cgi-bin/cmsfdtcommon.pl';

# connect to the db
my $configfile="../cgi-bin/cms50.conf";
my $dbh=dbconnect($configfile);

# Get hostid and groupid
my $hostid=shift;
my $groupid=shift;

if( ! $hostid || $hostid eq '-h' ) {
	print "Usage: autopub.pl hostid groupid\n";
	print "Publish the next unpublished document in the given group\n";
	exit;
}

# get the groupid
my $gid=searchgroup($hostid,$groupid);
my $query=(q{
	select documentid 
	from documentscontent 
	where hostid=? and groupid=? and 
	approved=false
	order by documentid asc
	limit 1
	});

# search the first unpublished document	
my $s=$dbh->prepare($query);
$s->execute($hostid,$gid);
my ($docid)=$s->fetchrow_array();
$s->finish();

# update
$query="update documentscontent set approved=true where hostid=? and groupid=? and documentid=?";
$s=$dbh->prepare($query);
$s->execute($hostid,$gid,$docid);
$s->finish();
$query="update documents set updated=current_timestamp where hostid=? and groupid=? and documentid=?";
$s=$dbh->prepare($query);
$s->execute($hostid,$gid,$docid);
$s->finish();

exit;

sub searchgroup
{
	my ($hostid,$groupname)=@_;
	my @path=split(/\//,$groupname);
	my $pid=0;
	my $r=$dbh->prepare('select groupid from groups where hostid=? and parentid=0');
	$r->execute($hostid);
	my ($rootid)=$r->fetchrow_array();
	$r->finish();
	$r=$dbh->prepare('select groupid from groups where hostid=? and parentid=? and groupname=?');

	foreach my $dir (@path) {
		$r->execute($hostid,$rootid,$dir);
		($rootid)=$r->fetchrow_array();
	}
	return $rootid;
}
