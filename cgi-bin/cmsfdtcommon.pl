#!/usr/bin/perl
#
# CMS FDT 5.0 common functions

use strict;
use DBI;
use CGI qw/:standard/;
use CGI::Cookie;
use Config::General;
use Mail::Sendmail;
use Email::Valid;
use Digest::MD5 qw(md5_base64);
#use Shell qw(dig);

my $myself=script_name();
my @salt = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );

# Database Connection
sub dbconnect
{
	my $configfile=shift;

	# get configuration parameters
	my $conf=new Config::General($configfile);
	my %config=$conf->getall;
	
	# open connection to the db
	my $dbname=$config{'dbname'};
	my $dbuser=$config{'dbuser'};
	my $dbpass=$config{'dbpass'};
	my $dbserv=$config{'dbserv'};
	my $dbport=$config{'dbport'};
	my $dbtype=$config{'dbtype'};
	my $dbh;
	my $dsn;

	if( $dbtype eq 'mysql' || $dbtype eq '' ) {
		$dsn="DBI:mysql:database=%s;host=%s;port=%s";
		$dsn=sprintf($dsn,$dbname,$dbserv,$dbport);
		$dbh=DBI->connect($dsn,$dbuser,$dbpass);
	} elsif( $dbtype eq 'pg' ) {
		my $dsn="dbi:Pg:dbname=%s;host=%s;port=%s";
		$dsn=sprintf($dsn,$dbname,$dbserv,$dbport);
		$dbh=DBI->connect($dsn,$dbuser,$dbpass,{AutoCommit=>1});
	}
	return $dbh;
}

# Logout: zap the cookie
sub logout
{
	my $dbh=shift;
	my $query=new CGI();
	my $host=getconfparam('cookiehost',$dbh);

	# build and set the cookie
	my $cookie=new CGI::Cookie(
		-name=>$host,
		-value=>'none',
		-expires=>'-1h',
		-secure=>0);

	# set the cookie.
	print $query->header(-cookie=>$cookie);
}

# print the header
sub printheader
{
	my ($dbh,$msg) = @_;

	my $title=getconfparam('title',$dbh);
	my $css="/".getconfparam('cssdir',$dbh)."/".getconfparam('css',$dbh);
	$css=~s/\/\//\//g;
	my $js=getconfparam('js',$dbh);

	# begin page
	print "<html>\n";
	print "<head>\n";
	print "<link rel='stylesheet' href='".$css."' type='text/css'>\n";
	print "<title>$title</title>\n";

	# if there is a message, show it.
	if( $msg ) {
		print "<script>\n";
		print "alert('".$msg."');\n";
		print "</script>\n";
	}

	# I can have multiple Javascript to load, so loop an all of them
	my @scripts=split /;/,$js;
	foreach my $script (@scripts) {
		print "<script type='text/javascript' src='".$script."'></script>\n";
	}

	print "</head>\n";
	print "<body>\n";
}

# Display the title bar for the comments
sub printcommenttitle
{
	my ($title,$user,$icon,$dbh) = @_;
	
	my $icondir=getconfparam('avatardir',$dbh);

	# get rid of extra '/' in the dir or icon name.
	$icondir=~s/\/$//;
	$icon=~s/^\///;

	print "<table width='100%' border='0' cellspacing='0' cellpadding='5pt'>\n";
	print "<tr valign='top'>\n";
	print "<td class='title' width='90%' align='left'>\n";
	print $title;
	print "</td>\n";
	print "<td align='right' class='title'>\n";
	print "<img id='titleicon' name='titleicon' src='";
	print $icondir."/".$icon;
	print "'>\n";
	print "</td>\n";
	print "</tr>\n";
	print "</table>\n";

}

# Display the title bar for the usermanagement
sub printusertitle
{
	my ($title,$user,$icon,$null,$dbh) = @_;

	my $icondir=getconfparam('buttondir',$dbh);
	$icondir=~s/\/%//;
	my $logouticon=$icondir."/".getconfparam('logouticon',$dbh);
	my $removeicon=$icondir."/".getconfparam('delicon',$dbh);
	my $avatardir=getconfparam('avatardir',$dbh);

	# get rid of extra '/' in the dir or icon name.
	$avatardir=~s/\/$//;
	$icon=~s/^\///;

	print "<table width='100%' border='0' cellspacing='0' cellpadding='5pt'>\n";
	print "<tr valign='top'>\n";
	print "<td class='title' width='90%' align='left'>\n";
	print $title . " " . $user;
	print "</td>\n";
	showcommand('unregister','unregister',$removeicon,
		'/cgi-bin/edituser.pl?mode=optout','usertitle',0,0,1);
	showcommand('logout','logout',$logouticon,
		'/cgi-bin/edituser.pl?mode=logout','usertitle',0,0,1);
	showcommand('me','',$avatardir.'/'.$icon,'','usertitle',400,300,0);
	print "</tr>\n";
	print "</table>\n";

}

# Display a minibutton that ask confirmation before doing something.
# This is always used for in-the-same-window commands, like the delete command
sub showminicommand2
{
	my ($title,$icon,$text,$function,$current) = @_;

	print "<img src='".$icon."' alt='".$title."' title='".$title."' width='16pt' ";
	print "onclick='askconfirm(\"$text\",\"$function\")' ";
	print "onmouseover=\"style.cursor='pointer'\">";
	print "&nbsp;";

}

# Display a minibutton
sub showminicommand
{
	my ($title,$icon,$function,$current,$width,$height,$cur) = @_;

	if( ! $width ) {
		$width=400;
		$height=300;
	}

	print "<img src='".$icon."' alt='".$title."' title='".$title."' width='16pt' ";
	if( $function ne '' ) {
		if( $function =~ /javascript:/ ) {
			print "onclick='".$function."'";
		} else {
			if($cur) {
				print "onclick='execlink(\"".$function."\")' ";
				print "onmouseover=\"style.cursor='pointer'\"";
			} else {
				print "onclick='openwindow(\"".$function."\",\"\",".
					$width.",".$height.")' ";
				print "onmouseover=\"style.cursor='pointer'\"";
			}
		}
	}
	print ">";
	print "&nbsp;";

}

# Display a button
sub showcommand
{
	my ($title,$desc,$icon,$function,$current,$width,$height,$cur) = @_;

	if( ! $width ) {
		$width=400;
		$height=300;
	}

	if( $current eq $title ) {
		print "<td class='currentcommand' width='9%' ";
	} elsif ( $current eq '' ) {
		print "<td ";
	} elsif ( $current eq 'usertitle' ) {
		print "<td class='title' width='9%' ";
	} else {
		print "<td class='command' width='9%' ";
	}

	if( $function ne '' ) {
		if($cur) {
			print "align='center' onclick='execlink(\"".$function."\")' ";
			print "onmouseover=\"style.cursor='pointer'\">";
		} else {
			print "align='center' onclick='openwindow(\"".$function."\",\"\",".
				$width.",".$height.")' ";
			print "onmouseover=\"style.cursor='pointer'\">";
		}
	}
	print "<img name='".$title."' id='".$title."' src='"
	.$icon."' width='24pt' alt='".$desc."' title='".$desc."'>\n";
	print "<br>\n";
	print $title;
	print "</td>\n";

}

# check if the user is logged in correctly or not, update the informations
# in the db and re-generate the cookie.
sub getloggedinuser
{
	my $dbh=shift;
	my $sendheader=shift || -1;

	my $defavatar=getconfparam('defavatar',$dbh);
	my $deflang=getconfparam('deflang',$dbh);
	my $cookiehost=getconfparam('cookiehost',$dbh);
	my $debug=getconfparam('debug',$dbh);

	my $userid='NONE';
	my $userchk;
	my $user='Unknown';
	my $icon=$defavatar;
	my $isroot=0;
	my $query=CGI->new;
	my $debugvalue;


	my $cookies=$query->cookie($cookiehost);

	if($cookies) {

		# split username into userid and random password
		($userchk,$userid) = split /:/,$cookies;
		if($debug) {
			print STDERR "Userid=".$userid." usrcheck: $userchk\n";
		}
		my $q="select name,icon,isroot from users where email=? and userchk=?";
		my $sth=$dbh->prepare($q);
		if( ! $sth->execute($userid,$userchk) ) {
			print "Error executing query!\n";
		}
		if( $sth->rows > 0 ) {
			($user,$icon,$isroot)=$sth->fetchrow_array();
			if( $icon eq '' || ! $icon) {
				$icon=$defavatar;
			}

		} else {
			$userid='NONE';
		}

	}

	# send default header to initialize the page
	if( $sendheader == -1 ) {
		print $query->header(
			-type => 'text/html',
			-expires=> '0m'
		);
	}
			
	return ($userid,$user,$icon,$isroot);
}

# check if the user is logged in without outputting any header
sub getloggedinusernoset
{
	my $dbh=shift;
	return getloggedinuser($dbh,1);
}

# Update a user's entry with the random password used to check the user later
sub upduser
{
	my ($email,$dbh)=@_;
	my $query=CGI->new;

	# make up random signature
	my $chkuser=$query->remote_host . time2str('%r',time);
	$chkuser=md5_base64($chkuser);

	# get the data from the user
	my $q="select name,icon,lastseen from users where email=?";
	my $sth=$dbh->prepare($q);
	$sth->execute($email);
	my ($desc,$icon,$last) = $sth->fetchrow_array();
	$sth->finish();

	#debug
	my $debug=0;
	if( $debug ) {
		print "<p>Desc: $desc, Last: $last, check: $chkuser<br>\n";
	}

	# now update the user
	$q="update users set lastseen=current_timestamp,userchk=? where email=?";
        $sth=$dbh->prepare($q);
        if(! $sth->execute($chkuser,$email) ) {
		print "Error updating the user!\n";
	}
	$sth->finish();

	# return values
	return ($desc,$icon,$last,$chkuser);

}

# print the footer
sub printfooter
{
	print "<div class='copy'>\n";
	print "The ";
print "<a href='http://www.soft-land.org/articoli/cmsfdt'>";
	print "CMSFDT";
	print "</a> is made by D.Bianchi, (C) 2008-averyfarawaydate.\n";
	print "</div>\n";
}

# test a password to see if it matches with the cryptd version
sub testpass
{
	my ($password,$digest) = @_;
	return 1 if crypt( $password, $digest ) eq $digest;
	return 0;
}

# crypt a password
sub cryptpass
{
	my $password = shift;
	return crypt( $password, gensalt(2) );
}

# uses global @salt to construct salt string of requested length
sub gensalt {
	my $count = shift;
	my $salt;
	for (1..$count) {
		$salt .= (@salt)[rand @salt];
	}
	return $salt;
}

# check if an email is valid
sub checkemail {
	my $email=shift;
	return Email::Valid->address($email);
}

# Send a mail
sub sendamail 
{

	my $email=shift;
	my $msg=shift;
	my $subj=shift;
	my $reply=shift;

	# it is important to check the validity of the email address 
	# supplied by the user both to catch genuine (mis-)typing errors 
	# but also to avoid exploitation by malicious users who could 
	# pass arbitrary strings to sendmail through the "send_to" 
	# CGI parameter - including whole email messages 
	if ( ! Email::Valid->address($email) ) {
		return 1;
	} 

	my %mail=(To=>$email, From=>$reply,Message=>$msg,Subject=>$subj);
	sendmail(%mail);
	return 0;

}

# add a small javascript to display a message 
sub warning
{
	my $msg=shift;

	print "<script>\n";
	if( $msg ) {
		print "alert(\"".$msg."\");\n";
	}
	print "</script>\n";
	return;
}

# add a small javascript to close the current window
# optionally, it display a message
sub closewindow
{
	my $msg=shift;

	print "</head>\n";
	print "<body>\n";
	print "<script>\n";
	if( $msg ) {
		print "alert(\"".$msg."\");\n";
	}
	print "window.close();\n";
	print "window.opener.location.reload();\n";
	print "</script>\n";
	print "</body>\n";
	print "</html>\n";
	exit;
}

sub showoptions
{
	my ($name,$curval,$disabled,@values)=@_;

	print "<select name='".$name."' ";
	if( $disabled ) {
		print "disabled";
	}
	print ">\n";
	for(my $i=0;$i<@values;$i++) {
		print "<option value='" . $values[$i] . "'";
		if( $curval eq $values[$i] ) {
			print " selected";
		}
		if( $curval && $values[$i] eq 'yes' ) {
			print " selected";
		}
		if( ! $curval && $values[$i] eq 'no' ) {
			print " selected";
		}
		print ">";
		print $values[$i];
		print "\n";
	}
	print "</select>\n";
	return;
}

sub showbutton
{
	my ($exec,$button,$text,%config)=@_;
	my $bicon=$config{$button};
	my $iconsdir=$config{'iconsdir'};

	print "<td align='center' width='7%' class='command' ";
	print "onmouseover=\"style.cursor='pointer'\" ";
	print " onclick='" . $exec . "''>";
	print "<img src='".$iconsdir."/".$bicon."' title='".$text."' alt='".$text."'><br>".$text."</td>"

}

sub showokbutton
{
	my ($exec,%config)=@_;
	my $button=$config{'okbutton'};
	my $iconsdir=$config{'iconsdir'};

	print "<td align='center' width='15%' class='command' ";
	print "onmouseover=\"style.cursor='pointer'\" ";
	print " onclick='" . $exec . "''>";
	print "<img src='".$iconsdir."/".$button."' title='Ok' alt='Ok'><br>Ok</td>"
}

# show an add button
sub showaddbutton
{
	my ($exec,%config)=@_;
	my $button=$config{'addbutton'};
	my $iconsdir=$config{'iconsdir'};

	print "<td align='center' width='15%' class='command' ";
	print "onmouseover=\"style.cursor='pointer'\" ";
	print " onclick='" . $exec . "''>";
	print "<img src='".$iconsdir."/".$button."' title='Add' alt='Add'><br>Add</td>"

}

# show the cancel button
sub showcancelbutton
{
	my ($exec,%config)=@_;
	my $button=$config{'cancelbutton'};
	my $iconsdir=$config{'iconsdir'};

	print "<td align='center' width='15%' class='command' ";
	print "onmouseover=\"style.cursor='pointer'\" ";
	print " onclick='" . $exec . "''>";
	print "<img src='".$iconsdir."/".$button."' title='Cancel' alt='Cancel'><br>Cancel</td>"

}

# send a mail with a new password
sub sendnewpwd
{
	my ($email,$name,$deflang,$dbh,$newpass) = @_;
	my $msg;
	my $sub;
	my $reply;
	
	# load the message from the db
	my $q="select content from fragments where fragid=? and language=?";
	my $sth=$dbh->prepare($q);
	$sth->execute('newpwd_welcome',$deflang);
	if( $sth->rows == 0 ) {
		$msg=(q{
Dear --NAME--,

Somebody, that could be you, requested a registration and a password to
access my site. The new password is
--PASS--
I suggest you login and change it as soon as possible.

Davide.
});
	} else {
		($msg)=$sth->fetchrow_array;
	}

	$msg=~s/--NAME--/$name/;
	$msg=~s/--PASS--/$newpass/;

	# get default subject 
	$q="select content from deftexts where textid=? and language=?";
	$sth=$dbh->prepare($q);
	$sth->execute('register_subject',$deflang);
	if( $sth->rows == 0 ) {
		$sub='Registration request.';
	} else {
		($sub)=$sth->fetchrow_array;
	}

	# get default reply to address
	$q="select content from deftexts where textid=? and language=?";
	$sth=$dbh->prepare($q);
	$sth->execute('register_replyto',$deflang);
	if( $sth->rows == 0 ) {
		$reply='noreply@soft-land.org';
	} else {
		($reply)=$sth->fetchrow_array;
	}

	# now send the mail
	sendamail($email,$msg,$sub,$reply);

}

# send a mail with a new password
sub sendreset
{
	my ($email,$name,$deflang,$dbh,$newpass) = @_;
	my $msg;
	my $sub;
	my $reply;
	
	# load the message from the db
	my $q="select content from fragments where fragid=? and language=?";
	my $sth=$dbh->prepare($q);
	$sth->execute('reset_welcome',$deflang);

	if( $sth->rows == 0 ) {
		$msg=(q{
Dear --NAME--,

Somebody, that could be you, requested a new password to access my site. 
The new password is
--PASS--
I suggest you login and change it as soon as possible.

Davide.
});
	} else {
		($msg)=$sth->fetchrow_array;
	}

	$msg=~s/--NAME--/$name/;
	$msg=~s/--PASS--/$newpass/;

	# get default subject 
	$q="select content from deftexts where textid=? and language=?";
	$sth=$dbh->prepare($q);
	$sth->execute('register_subject',$deflang);
	if( $sth->rows == 0 ) {
		$sub='Password reset request.';
	} else {
		($sub)=$sth->fetchrow_array;
	}

	# get default reply to address
	$q="select content from deftexts where textid=? and language=?";
	$sth=$dbh->prepare($q);
	$sth->execute('register_replyto',$deflang);
	if( $sth->rows == 0 ) {
		$reply='noreply@soft-land.org';
	} else {
		($reply)=$sth->fetchrow_array;
	}

	# now send the mail
	sendamail($email,$msg,$sub,$reply);

}

# send a confirm request to a user if he wants to un-register.
sub sendunregistered
{
	my ($email,$name,$deflang,$dbh) = @_;
	my $msg;
	my $sub;
	my $reply;
	
	# load the message from the db
	my $q="select content from fragments where fragid=? and language=?";
	my $sth=$dbh->prepare($q);
	$sth->execute('unregister_goodbye',$deflang);
	if( $sth->rows == 0 ) {
		$msg=(q{
Dear --NAME--,
Somebody, that could be you, sent a request to UNregister from my site.
If this is correct, please reply to this email so I know that your request 
was legitimate. If you didn't. Then just ignore this e-mail.
Note: I won't send this mail again and no changes will be made to your
account without a confirmation.

Thanks.

Davide
});
	} else {
		($msg)=$sth->fetchrow_array;
	}

	$msg=~s/--NAME--/$name/g;

	# get default subject 
	$q="select content from deftexts where textid=? and language=?";
	$sth=$dbh->prepare($q);
	$sth->execute('unregister_subject',$deflang);
	if( $sth->rows == 0 ) {
		$sub='DE-Registration request.';
	} else {
		($sub)=$sth->fetchrow_array;
	}

	# get default reply to address
	$reply=getconfparam('registerfrom',$dbh);
	if( ! $reply ) {
		$reply='registerme@onlyforfun.net';
	}

	# now send the mail
	sendamail($email,$msg,$sub,$reply);

}

# send a greeting e-mail if you register.
sub sendregistered
{
	my ($email,$name,$deflang,$dbh) = @_;
	my $msg;
	my $sub;
	my $reply;
	
	# load the message from the db
	my $q="select content from fragments where fragid=? and language=?";
	my $sth=$dbh->prepare($q);
	$sth->execute('register_welcome',$deflang);
	if( $sth->rows == 0 ) {
		$msg=(q{
Dear --NAME--,
Somebody, that could be you, sent a request to register and get a password
to access my website. If this is correct, please reply to this email so I
know that your request was legitimate. If you didn't. Then just ignore this
e-mail.
Note: I won't send this mail again and no account will be created without
a valid registration..

Thanks.

Davide
});
	} else {
		($msg)=$sth->fetchrow_array;
	}

	$msg=~s/--NAME--/$name/g;

	# get default subject 
	$q="select content from deftexts where textid=? and language=?";
	$sth=$dbh->prepare($q);
	$sth->execute('register_subject',$deflang);
	if( $sth->rows == 0 ) {
		$sub='Registration request.';
	} else {
		($sub)=$sth->fetchrow_array;
	}

	# get default reply to address
	$reply=getconfparam('registerfrom',$dbh);
	if( ! $reply ) {
		$reply='registerme@onlyforfun.net';
	}

	# now send the mail
	sendamail($email,$msg,$sub,$reply);

}

# enable a password for a user
sub enableuser
{
	my ($userid,$dbh,$deflang) = @_;

	# search the user in the database
	my $q='select password,name from users where email=?';
	my $s=$dbh->prepare($q);
	$s->execute($userid);
	if( $s->rows == 0 ) {
		# user does not exists!
		return "Email not found in the system.";
	}

	my ($oldpw,$name) = $s->fetchrow_array();
	# is the old password 'nopass' or 'disabled? if so, the user
	# is just registered or disabled and should not receive a new password.
	if( $oldpw ne 'nopass' && $oldpw ne 'disabled') {
		return;
	}

	# generate new (crypted) password
	my $newpass=md5_base64($userid.time2str('%C',time));
	$newpass=substr $newpass, 0, 10;

	# set the password as the user's password
	my $cpass=cryptpass($newpass);
	$q="update users set password=? where email=?";
        my $sth=$dbh->prepare($q);
        if( ! $sth->execute($cpass,$userid) ) {
		return "Error during the update!";
	}

	# send e-mail with the new password
	sendnewpwd($userid,$name,$deflang,$dbh,$newpass);
	return 0;

}

# reset and re-send the password to the user
sub resetpwd
{
	my ($userid,$dbh,$deflang) = @_;

	# search the user in the database
	my $q='select password,name from users where email=?';
	my $s=$dbh->prepare($q);
	$s->execute($userid);
	if( $s->rows == 0 ) {
		# user does not exists!
		return "Email not found in the system.";
	}

	my ($oldpw,$name) = $s->fetchrow_array();
	# is the old password 'nopass' or 'disabled? if so, the user
	# is just registered or disabled and should not receive a new password.
	if( $oldpw eq 'nopass' ) {
		return "You are not yet enabled.";
	}
	if( $oldpw eq 'disabled' ) {
		return "You have been disabled, please contact the administrator.";
	}

	# generate new (crypted) password
	my $newpass=md5_base64($userid.time2str('%C',time));
	$newpass=substr $newpass, 0, 10;

	# set the password as the user's password
	my $cpass=cryptpass($newpass);
	$q="update users set password=? where email=?";
        my $sth=$dbh->prepare($q);
        if( ! $sth->execute($cpass,$userid) ) {
		return "Error during the update!";
	}

	# send e-mail with the new password
	sendreset($userid,$name,$deflang,$dbh,$newpass);
	return 0;

}

# retrieve a configuration parameter from the database and return
# it or '' if no config param can be found.
sub getconfparam
{
	my ($paramid,$dbh) = @_;
	my $q='select value from configuration where paramid=?';
	my $r=$dbh->prepare($q);
	my $s=$r->execute($paramid);
	if( $r->rows == 0 ) {
		$r->finish();
		return '';
	} else {
		my ($value)=$r->fetchrow_array();
		$r->finish();
		return $value;
	}
}

# handle the login in the site.
# the function has been moved here to handle the login directly from the
# frontend 
sub login
{
	my ($email,$password,$dbh,$query)=@_;

	my $q="select password from users where email=?";
	my $chkusr;
	my $msg;
	my $desc;
	my $icon;
	my $last;

	if( ! checkemail($email) ) {
		$msg="Invalid e-mail:".$email;
	} else {
		my $sth=$dbh->prepare($q);
		$sth->execute($email);
		my ($found)=$sth->fetchrow_array();
	
		if( $found eq 'disabled' ) {
			$msg='You have been disabled, please contact the administrator.';
		} elsif( $found eq '' ) {
			$msg='Wrong username or password.';
		} else {
			if(testpass($password,$found)) {
				# Ok, update the user
				($desc,$icon,$last,$chkusr) = upduser($email,$dbh);
				$msg='Welcome back '.$desc.', your last visit was '.$last.'.';
			} else {
				$msg='Wrong username or password.';
			}
		}
	}

	# if successfull login, print the header and set the cookie.
	if( $chkusr) {
		my $host=getconfparam('cookiehost',$dbh);
		my $cookie=$query->cookie(
			-name 	 => $host,
			-value	 => $chkusr.":".$email,
			-expires => '+1d',
			-secure	 => 0
		);
		print $query->header(
			-type   => 'text/html',
			-expires=> '+30m',
			-cookie => [$cookie]
		);

	} else {
		print $query->header(
			-type   => 'text/html',
			-expires=> '0m'
		);
	}
	print "<html>\n";
	print "<head>\n";
	print "<meta http-equiv='refresh' content='0; url=".$myself."'>\n";
	print "<script language='javascript'>\n";
	print "alert('".$msg."');\n";
	print "</script>\n";
	print "</head>\n";
	print "</html>\n";
	exit 0;

}

# show the login form directly on the screen
sub showloginform
{

	my $userid=shift;

	if( $userid eq 'NONE' ) {
		print "<table width='100%' border='0' cellspacing='2' cellpadding='0' ";
		print "bgcolor='lightgrey'>\n";
		print "<tr><td colspan='2'><b>Login</td></tr>\n";
		print "<form name='loginform' method='post' action='".$myself."'>\n";
		print "<input type='hidden' name='mode' value='login'>\n";
		print "<tr><td width='10%'>";
		print "e-mail:";
		print "</td><td><input type='text' name='email' size='20' value=''>";
		print "</td></tr>\n";
		print "<tr>\n";
		print "<td width='10%'>\n";
		print "password:</td>";
		print "<td><input type='password' name='password' size='20' value=''>";
		print "</td></tr>\n";
		print "<tr><td colspan='2' align='right'>";
		print "<input type='submit' value='Login'>";
		print "</td></tr>\n";
		print "</table>\n";
	} else {
		print "<a href='".$myself."?mode=logout'>Logout</a>";
	}

}

# return the default template for the host
sub locatedefaulttpl
{
	my $hostid=shift;
	my $dbh=shift;

	my $q="select title from templates where hostid=? and isdefault='yes'";
	my $r=$dbh->prepare($q);
	$r->execute($hostid);
	my ($g)=$r->fetchrow_array();
	$r->finish();
	return $g;

}

# return the default language for the host
sub locatedefaultlang
{
	my $hostid=shift;
	my $dbh=shift;

	my $q='select language from hosts where hostid=?';
	my $r=$dbh->prepare($q);
	$r->execute($hostid);
	my ($g)=$r->fetchrow_array();
	$r->finish();
	return $g;
}

# process a comment replacing emoticons and other junk
sub processthecomment
{

	my $c=shift;
	my $dbh=shift;


	my $emoticonsdir=getconfparam('emoticonsdir',$dbh);

	my $emocode=getconfparam('emocode',$dbh);
	my $emodecode=getconfparam('emodecode',$dbh);
	my @emoticons=split / /,$emocode;
	my @emoicons=split / /,$emodecode;
	my $x=0;
	my $s;

	# Adjust accented chars and other junk
	#$c=scrub($c,$dbh);

	# remove last '/' in the directory
	$emoticonsdir=~s/\/$//;
	foreach my $i (@emoticons) {

		# adjust emoticons code
		$i=~s/\(/\\(/g;
		$i=~s/\)/\\)/g;

		# replace with icon (fixed height... bad)
		$s="<img src='".$emoticonsdir."\/".$emoicons[$x].".png' ";
		$s.="height='16' alt='".$i."'>";
		$c=~s/ $i/ $s/g;

		# next!
		$x++;
	}

	# now replace simple '<' and '>' - not <something... or something>
	$c=~s/ < / &lt; /g;
	$c=~s/ > / &gt; /g;

	# a bit of style
	$c=~s/ \*([^*]+)\* / <b>$1<\/b> /g;
	$c=~s/ \|([^|]+)\| / <i>$1<\/i> /g;
	$c=~s/ _([^_]+)_ / <u>$1<\/u> /g;

	# last, change CR/LF into <br> or <p>
	$c=~s/+/<p>/g;
	$c=~s//<br>/g;

	# return the processed comment;
	return $c;

}

# un-treat for html stuff
sub unscrub
{
	my ($f,$dbh)=@_;

	if( ! $dbh ) {
		return $f;
	}

	my $htmlcode=getconfparam('htmlcode',$dbh);
	my $htmldecode=getconfparam('htmldecode',$dbh);

	my @htmlcode=split /,/,$htmlcode;
	my @htmldecode=split /,/,$htmldecode;
	my $x=0;

	foreach my $i (@htmldecode) {

		$f=~s/$i/$htmlcode[$x]/g;
		$x++;
	}

	# return the processed stuff
	return $f;
}

# treat for html stuff
sub scrub
{
	my ($f,$dbh)=@_;

	if( ! $dbh ) {
		return $f;
	}

	my $htmlcode=getconfparam('htmlcode',$dbh);
	my $htmldecode=getconfparam('htmldecode',$dbh);

	my @htmlcode=split /,/,$htmlcode;
	my @htmldecode=split /,/,$htmldecode;
	my $x=0;

	foreach my $i (@htmlcode) {

		$f=~s/$i/$htmldecode[$x]/g;
		$x++;
	}

	# return the processed comment;
	return $f;
}

# Recover the groupid from a path
sub getgroupidfrompath
{
	my ($hostid,$path,$dbh)=@_;
	my $debug=getconfparam('debug',$dbh);
	my $nextid=0;
	my $q;
	my $r;

	if($debug) {
		print "Searching for $path<br>\n";
	}
	
	# scan the path and search for the groups in sequence
	my @groups=split(/\//,$path);

	# The root directory has groupid=0, ALWAYS
	# every group is related to the 'root' document
	foreach my $group (@groups) {

		if( $debug ) {
			print "searching for group $group in parent $nextid<br>\n";
		}
			
		# search the first one
		my $q='select groupid from groups where hostid=? and groupname=? and parentid=?';
		my $r=$dbh->prepare($q);
		$r->execute($hostid,$group,$nextid);
		if( $r->rows == 1 ) {
			($nextid)=$r->fetchrow_array();
			if ($debug) {
				print "-found one group: $nextid<br>\n";
			}
		} else {
			if ($debug) {
				print "found group $nextid<br>\n";
			}
			return $nextid;
		}
	}
	return $nextid;
}

# Build a path from a groupid
sub getpathfromgroupid
{
	my ($hostid,$groupid,$dbh)=@_;
	my $debug=getconfparam('debug',$dbh);
	my $path='';
	my $name;

	if($debug) {
		print "Searching for $groupid<br>\n";
	}

	while($groupid > 0 ) {
		($name,$groupid)=getparent($hostid,$groupid,$dbh);
		$path=$name."/".$path;
	}	
	
	# remove double slashes
	$path=~s/\/\//\//g;
	$path=~s/^[^\/]+\///;
	return $path;
}

# get the parent id for a group
sub getparent
{
	my ($hostid,$groupid,$dbh)=@_;
	
	my $q='select name,parentid from groups where hostid=? and groupid=?';
	my $r=$dbh->prepare($q);
	$r->execute($hostid,$groupid);
	my ($name,$parentid)=$r->fetchrow_array();
	$r->finish();
	
	return ($name,$parentid);
	
}

# Test if an hostname is a valid hostname
sub isvalidhostname
{
	my $h=shift;
	my $vh= "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])\$";

	if( $h !~ /$vh/ ) {
		return 0;
	} else {
		return 1;
	}
}
