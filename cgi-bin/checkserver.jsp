#!/usr/bin/perl

use warnings;
use DBI;
use CGI qw/:standard/;
use CGI::Cookie;
#use Shell qw(dig);
use Config::General;

# load common lib
require 'cmsfdtcommon.pl';

my $myself=script_name();
my $query=CGI->new;

my $dbh=dbconnect('./cms50.conf');
my $user=$query->param('user');

print "Content-Type: text/plain\n\n";

# Ok, now I know the user name, check if he is allowed to login!
if( $user =~ /^davideb$/ || $user =~ /^Elliastra$/ ) {
	print 'YES';
} else {
	print 'NO';
}
