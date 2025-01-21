#!/usr/bin/perl
# Registration/login screen

use strict;
use DBI;
use CGI qw/:standard/;
#use Shell qw(dig);
use Config::General;
use Date::Parse;
use Date::Format;

require './cmsfdtcommon.pl';

my $myself=script_name();
my $configfile="./cms50.conf";
my $query=CGI->new;
my $dbh=dbconnect($configfile);

# Get parameters from the query
my $mode=$query->param('mode');
my $email=$query->param('email');
#	$email=scrub($query->param('email'),$dbh);
#} else {
#	$email='';
#}
my $password=$query->param('password');
my $description=$query->param('description');
$description=scrub($description,$dbh);

if ($email eq 'NONE') { $email=''; }

# load defaults
my $deflang=getconfparam('deflang',$dbh);
my $defavatar=getconfparam('defavatar',$dbh);
my $css=getconfparam('css',$dbh);
my $js=getconfparam('js',$dbh);
my $debug=getconfparam('debug',$dbh);

# try locate the host from the server name
my $host=$ENV{'HTTP_HOST'};
if( $debug ) {
	print "searching host ".$host."<br>\n";
}

my $q="select h.* from hosts h, hostaliases ha where h.hostid=ha.hostid and ha.alias=?";
my $r=$dbh->prepare($q);
$r->execute($host);

if( $r->rows == 1 ) {
	# ok, load the defaults for the host
	my $h=$r->fetchrow_hashref();
	if( $debug ) {
		print "found ".$h->{'hostname'}."<br>\n";
	}
	$host=$h->{'hostname'};
	$deflang=$h->{'deflang'};
	$css=$h->{'css'};
}

$css="/".$css;
my $desc;
my $icon;
my $last;
my $sth;
my $found;
my $chkusr;

my $msg="";
my $cookie;
my $debug=0;
my $res='';

if( $mode ne '' ) {

	if( $mode eq 'resetpwd' ) {
		$msg=resetpwd($email,$dbh,$deflang);
	}

	if( $mode eq 'login' ) {
		my $q="select password from users where email=?";
		$sth=$dbh->prepare($q);
		$sth->execute($email);
		($found)=$sth->fetchrow_array();

		if( $sth->rows() == 0 ) {
			$msg="Wrong email or password.";
			$res='wrong';
		} else {

			if( $found eq 'disabled' ) {
				$msg='You have been disabled, please contact the administrator.';
				$res='ok';
			} elsif(testpass($password,$found)) {
				# Ok, update the user.
				($desc,$icon,$last,$chkusr) = upduser($email,$dbh,$query,$deflang);
				$msg="Welcome back $desc, your last visit was $last.";
				$res='ok';
			} else {
				$msg="Wrong email password.";
				$res='wrong';
			}
		}
	}

	if( $mode eq 'register' ) {

		# register a new user, check if the mail address is a correct
		# mail address
		if( checkemail($email) ) {

			my $date=time2str("%Y-%m-%d",time);
			my $q="insert into users (email,name,registered,icon) values (?,?,?,?)";
			$sth=$dbh->prepare($q);
			if( $sth->execute($email,$description,$date,$defavatar)) {
				$msg="Thanks for registering with us. We will send your password ".
				"as soon as possible to the mail address you specified.";
				sendregistered($email,$description,$deflang,$dbh);
				$res='ok';
			} else {
				$msg=$dbh->{'mysql_error'};
				if($msg =~ /Duplicate/) {
					$msg="The e-mail address entered appear to be already present. ";
					$res='wrong';
				} else {
					$msg='error';
					$res='wrong';
				}
			}
		} else {
			$msg="The email you typed is invalid. Please specify a VALID ".
			"email address for registration.";
			$res='wrong';
		}
	}

	$mode='';

}

# Begin page - setup cookie if necessary
if( $res eq 'ok' && $chkusr ) {
	# prepare cookie
	my $host=getconfparam('cookiehost',$dbh);
	my $cookie=$query->cookie(
		-name    => $host,
		-value   => $chkusr.":".$email,
		-expires => '+1d',
		-secure  => 0
	);
	print $query->header(
		-type   => 'text/html',
		-expires=> '0m',
		-cookie => [$cookie]
	);
} else {
	print $query->header(
		-type   => 'text/html',
		-expires=> '0m'
	);
}

printheader($dbh,$msg);

if( $debug ) {
	print "Last: $last<br>\n";
}

# print result (if any)
if($res eq 'ok') {
	print "<script>\n";
	print "closeandrefresh();\n";
	print "</script>\n";
}

print "<table width='100%' cellspacing=0 cellpadding=0 border=0>\n";
print "<tr valign=center class='pageheader'>\n";
print "<td width='90%' class='title'>";
print "Login or Register";
print "</td>";
print "</tr></table>\n";
print "<hr>\n";

# show form
print "<table width='100%' border='0' cellspacing='0' cellpadding='10pt' ";
print "bgcolor='lightgrey'>\n";
print "<tr><td>\n";
print "<div class='topictitle'>Login</div>\n";
print "Enter your e-mail and your password to login.\n";
print "</td></tr>\n";
print "<form name='loginform' method='post' action='".$myself."'>\n";
print "<input type='hidden' name='mode' value='login'>\n";
print "<tr>\n";
print "<td width='70%'>\n";
print "<table width='100%'>";
print "<tr><td width='10%'>";
print "E-mail:";
print "</td><td><input type='text' name='email' size='40' value='".$email."'></td></tr>\n";
print "<tr>\n";
print "<td width='10%'>\n";
print "Password:</td>";
print "<td><input type='password' name='password' size='40' value='";
print $password."'></td></tr>\n";
print "<tr>\n";
print "</table>\n";
print "</td><td>";
print "<table width='100%'>";
print "<tr>";
print "<input type='submit' value='Ok'>\n";
print "<input type='button' value='Cancel' onclick='javascript:closeandrefresh()'>\n";
print "</tr>\n";
print "</table>\n";
print "</td></tr>\n";
print "<tr><td>\n";
print "Or maybe you ";
print "<a href='".$myself."?mode=resetpwd&email=".$email."'>forgot your password?</a>\n";
print "</td><td></td></tr>\n";
print "</table>\n";
print "</form>\n";
print "<hr>\n";

print "<table width='100%' bgcolor='lightgrey' cellspacing='0' ";
print "cellpadding='10pt'>\n";
print "<tr><td colspan='2'>\n";
print "<div class='topictitle'>Register</div>\n";
print "If you don't have a login name yet, you need to <i>register</i>. ";
print "To register you need a valid e-mail address. ";
print "The address will also work as your login name. The password will ";
print "be generated and sent to your e-mail address, so ";
print "<b>your e-mail need to be a valid one</b>.<br>";
print "<b>WARNING:</b> It seems that Gmail is refusing mails sent by this IP-block, so if you don't get ";
print "any answer in a few days, please contact me via either mail or fb.<p>";
print "<form name='register' method='post' action='/cgi-bin/login.pl'>\n";
print "<input type='hidden' name='mode' value='register'>\n";
print "<tr>";
print "<td width='70%'>\n";
print "<table width='100%' border='0' cellspacing='0' cellpadding='0'>";
print "<tr>\n";
print "<td width='20%'>";
print "E-mail:";
print "</td>\n";
print "<td><input type='text' name='email' size='40' value='";
print $email."'></td>\n";
print "</tr>\n";
print "<tr>\n";
print "<td width='20%'>\n";
print "Your name:</td>";
print "<td><input type='text' name='description' size='40' value='";
print $description."'></td>\n";
print "</tr>\n";
print "</table>\n";
print "</td>\n";
print "<td>\n";
print "<input type='submit' value='Ok'>\n";
print "<input type='button' value='Cancel' onclick='javascript:closeandrefresh()'>\n";
print "</td>\n";
print "</tr>\n";
print "</table>\n";
print "</form>\n";
print "<b>Warning:</b> the password is not sent immediately, don't worry if ";
print "you don't receive a response in a matter of minutes. It can take up to ";
print "24 hours for the registration to work.\n";
print "<hr>\n";

print "<div class='copy'>\n";
print "The ";
print "<a href='http://www.soft-land.org/articoli/cmsfdt30'>";
print "CMS Fdt 3.0";
print "</a> is made by D.Bianchi, (C) 2008-averyfarawaydate.\n";
print "</div>\n";

print $query->end_html;
exit;
