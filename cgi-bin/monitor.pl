#!/usr/bin/perl
#
# Monitor simulator for video
# This script reads one or more CSV files containing "server monitor data" and display them as a table in a HTML page. Used to simulate
# a system monitor.

use strict;
use CGI qw/:standard/;
use Date::Parse;
use Date::Format;
use Config::General;

my $datadir='/var/www/cms50/datafiles';
my $query=CGI->new;
my $srvid='main';
my $gid='';

if( $query->param('mode') eq 'view' ) {
	$srvid=$query->param('srvid');
	$gid=$query->param('gid');
}

# initialize the page
print $query->header(
	-type=>'text/html',
	-expires=>'0m',
	-status=>'200 OK',
	-charset=>'iso-8859-15'
);

print "<!doctype html public \"-//W3C//DTD HTML 4.01 Transitional//EN\"";
print "\"http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd\">\n";
print "<html>\n";
print "<!-- this document was produced with the (in)famous Cms FDT v. 5.0 -->\n";
print "<!-- by D.Bianchi (c) 2008-averyfarawaydate -->\n";
print "<!-- see http://www.soft-land.org/ -->\n";
print "<head>\n";
print "<meta http-equiv='Content-type' content='text/html;charset=iso-8859-15' />\n";
print '<meta name="google-site-verification" content="r33YyzPGlgNzbUz6eNHHsApaDLICEOgZ3vl2GRugvZU" />'."\n";
print "<title>System Monitor</title>\n";
print "<link rel='stylesheet' href='/css/softland.css' type='text/css'>\n";
print "</head>\n";
print "<body>\n";
print "<p class='topictitle' style='font-size:16'>System Monitor v 3.12 (c) ShittyHostingProvider</p>\n";
print "<p class='doctext'>\n";
print "<b>Total systems:</b> 498; <b>Active monitors:</b> 3810; <b>Active alerts:</b> 215;<br>\n";
print "<b>Systems overview</b></p>\n";

print "<table width=100% border=0 bgcolor=lightblue>\n";

my $firstline=1;
my $line=0;
my $bgcolor='white';

# now read the requested page
my $inputfile=$datadir."/".$srvid.".dat";
if( -r $inputfile ) {
	open IN, "<$inputfile";
	while(<IN>) {
		chomp();

		my ($srvid,$cust,$type,$cpu,$http,$https,$ssh,$tomcat,$msql,$psql,$disk,$ram,$uptime0,$uptime1,$uptime2,$uptime3,$uptime4)=split /,/,$_;

		if( $firstline==1 ) {
			print "<tr>\n";
                        print "<td style='background-color:blue;text-align:center';color:white;>\n";
			print "<b style='color:white'>$srvid</b>";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$cust</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$type</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$cpu</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$http</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$https</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$ssh</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$tomcat</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$msql</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$psql</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$disk</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$ram</b>\n";
			print "</td>\n";
                        print "<td style='background-color:blue;text-align:center'>\n";
			print "<b style='color:white'>$uptime0</b>";
			print "</td>\n";
			print "</tr>\n";

			$firstline=0;

		} else {

			if( $line==0 ) {
				$bgcolor='white';
				$line=1;
			} else {
				$bgcolor='lightgray';
				$line=0;
			}

			print "<tr bgcolor=$bgcolor>\n";
                        print "<td style='background-color:$bgcolor;text-align:left'";
			print "<b>$srvid</b>\n";
			print "</td>\n";
                        print "<td style='background-color:$bgcolor;text-align:center'>";
			print $cust."\n";
			print "</td>\n";
                        print "<td style='background-color:$bgcolor;text-align:center'>";
			print $type."\n";
			print "</td>\n";
			if( $cpu >= 90 ) {
                        	print "<td style='background-color:red;text-align:center;font-weight:bold;color:white'>";
			} elsif( $cpu >= 80 && $cpu < 90 ) {
                        	print "<td style='background-color:yellow;text-align:center;font-weight:bold;color:black'>";
			} else {
                        	print "<td style='background-color:$bgcolor;text-align:center'>";
			}
			print $cpu."\n";
			print "</td>\n";

			if( $http >= 1.5 ) {
                        	print "<td style='background-color:red;text-align:center;font-weight:bold;'>";
			} else {
	                        print "<td style='background-color:$bgcolor;text-align:center;font-weight:normal;'>";
			}
			print $http."\n";
			print "</td>\n";

			if( $https >= 1.5 ) {
	                        print "<td style='background-color:red;text-align:center;font-weight:bold'>";
			} else {
                        	print "<td style='background-color:$bgcolor;text-align:center'>";
			}
			print $https."\n";
			print "</td>\n";
                        print "<td style='background-color:$bgcolor;text-align:center'>";
			print $ssh."\n";
			print "</td>\n";
                        print "<td style='background-color:$bgcolor;text-align:center'>";
			print $tomcat."\n";
			print "</td>\n";
                        print "<td style='background-color:$bgcolor;text-align:center'>";
			print $msql."\n";
			print "</td>\n";
                        print "<td style='background-color:$bgcolor;text-align:center'>";
			print $psql."\n";
			print "</td>\n";

                        if( $disk >= 80 && $disk < 90 ) {
                                print "<td style='background-color:yellow;text-align:center;font-weight:bold;color:black'";
                        } elsif ( $disk >= 90 ) {
                                print "<td style='background-color:red;text-align:center;font-weight:bold;color:white'";
                        } else {
                                print "<td style='background-color:$bgcolor;text-align:center;font-weight:normal'";
			}
			print ">\n";

			if( $disk >= 90 ) {
				if( $gid =~ $srvid ) {
					print "<a style='color:white' href='/cgi-bin/monitor.pl?gid=$srvid".'&'."srvid=main'>";
				} else {
					print "<a style='color:white' href='/cgi-bin/monitor.pl?mode=view".'&'."gid=$srvid".'&'."srvid=main'>";
				}
			}
			print $disk."\n";
			print "</td>\n";
			if( $disk >= 90 ) {
				print "</a>";
			}

                        if( $ram >= 80 && $ram < 90 ) {
                                print "<td style='background-color:yellow;text-align:center;color:black;font-weight:bold'";
                        } elsif ( $ram >= 90 ) {
                                print "<td style='background-color:red;text-align:center;color:white;font-weight:bold'";
                        } else {
                                print "<td style='background-color:$bgcolor;text-align:center'";
			}
			print ">\n";
			print $ram."\n";
			print "</td>\n";

                        print "<td style='background-color:$bgcolor;text-align:center'>";
			print $uptime0.":".$uptime2.":".$uptime4."\n";
			print "</td>\n";
			print "</tr>\n";


			if( $gid =~ $srvid ) {
				print "<tr style='background-color:$bgcolor'>\n";
				print "<td style='background-color:$bgcolor'>".'&nbsp; </td>';
				print "<td style='background-color:$bgcolor'>".'&nbsp; </td>';
				print "<td colspan=10 align=center style='background-color:$bgcolor'>";
				print "<img src='/img/graph.jpg' width=100%>";
				print "</td>\n";
				print "<td style='background-color:$bgcolor'>".'&nbsp; </td>';
				print "</tr>\n";
			}
		}
	}
	close IN;

}

print "</table>\n";

print "</body>\n";
print "</html>\n";

