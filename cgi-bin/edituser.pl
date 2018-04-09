#!/usr/bin/perl
#
# Edit user screen for CMS FDT 4.5

use strict;
use DBI;
use CGI qw/:standard/;
use CGI::Cookie;
#use Shell qw(dig);
use Config::General;
use Date::Parse;
use Date::Format;

require 'cmsfdtcommon.pl';

my $myself=script_name();
my $query=new CGI();

# Connection to the database
my $dbh=dbconnect("./cms50.conf");

my $cookiehost=getconfparam('cookiehost',$dbh);
my $title=getconfparam('title',$dbh);
my $deflang=getconfparam('deflang',$dbh);
my $fperpage=getconfparam('fperpage',$dbh);
my $pperpage=getconfparam('pperpage',$dbh);
my $base=getconfparam('base',$dbh);
my $css=getconfparam('css',$dbh);
my $iconsdir=getconfparam('iconsdir',$dbh);
my $defavatar=getconfparam('defavatar',$dbh);
my $uploaddir=getconfparam('uploaddir',$dbh);
my $avatardir=getconfparam('avatardir',$dbh);
my $dateformat=getconfparam('dateformat',$dbh);

my $delicon=$iconsdir."/".getconfparam('delicon',$dbh);
my $addicon=$iconsdir."/".getconfparam('addicon',$dbh);

my $maxsizeicon=getconfparam('maxsizeicon',$dbh);

# Get parameters from the query
my $mode=$query->param('mode');
my $email=$query->param('email');
my $signature=$query->param('signature');
my $language=$query->param('language');
my $ticon=$query->param('ticon');
my $ishe=$query->param('isroot');
my $name=$query->param('name');
my $content=$query->param('content');
my $password1=$query->param('password1');
my $password2=$query->param('password2');
my $custom=$query->param('custom');

my $password;
my $msg;

# max 25 Kb of data!
$CGI::POST_MAX=$maxsizeicon*1024;

# get default language if not specified
if ($language eq '') {
	$language=$deflang;
}

my $sth;
my $msg='';

if($mode eq 'logout') {
	logout($dbh);
	print "<script>\n";
	print "window.close();\n";
	print "window.opener.location.reload();\n";
	print "</script>\n";
}

# Load current user data (there must be some)
my ($userid, $user, $icon, $isroot) = getloggedinuser($dbh);

if( $mode eq 'display' || $mode eq '' ) {
	$ticon=$icon;
	$name=$user;
}

if( $mode eq 'optout') {
	sendunregistered($userid,$user,$deflang,$dbh);
	$msg="WARNING: you have requested to be unregistered from the site. In order to process your request ".
	"we will send you a confirmation e-mail that you will need to answer. Once received the answer we will ".
	"process your request.";
	print "<script>\n";
	print "alert('".$msg."');\n";
	print "window.location='".$myself."?mode=logout';\n";
	print "</script>\n";
}

# Begin page
printheader($dbh);

if( $mode eq 'addanewdescription' ) {

	# add a new description for this user
	my $q='insert into userdesc (email,language,content) values (?,?,?)';
	my $r=$dbh->prepare($q);
	$r->execute($email,$language,$content);
	$mode='showdescriptions';
}

if( $mode eq 'deldesc' ) {
	# remove a description
	my $q='delete from userdesc where email=? and language=?';
	my $r=$dbh->prepare($q);
	$r->execute($email,$language);
	$mode='showdescriptions';
}

# Show the descriptions
if( $mode eq 'showdescriptions' ) {


	# display all the descriptions for the current user
	my $col=0;
	my $q='select * from userdesc where email=?';
	my $r=$dbh->prepare($q);
	$r->execute($email);
	print "<table width='100%' border='0' cellspacing='0' cellpadding='3'>\n";
	while( my $u=$r->fetchrow_hashref() ) {
		if( $col == 0 ) {
			print "<tr bgcolor='white'>\n";
			$col=1;
		} else {
			print "<tr bgcolor='lightgrey'>\n";
			$col=0;
		}

		# build the link
		my $formname=$myself."?mode=deldesc&amp;email=".$email."&amp;language=".$u->{'language'};
		my $no=$myself."?mode=display&amp;email=".$email;

		print "<td width='5%' valing='top' align='center'>\n";
		print $u->{'language'};
		print "</td>\n";
		print "<td valign='top'>\n";
		print $u->{'content'};
		print "</td>\n";

		print "<td align='right' width='10%'>\n";
		print "<img src='".$delicon."' alt='Remove description' title='remove description' width='16pt' ";
		print "onclick='askconfirm(\"Remove this description?\",\"$formname\",\"$no\")' ";
		print "onmouseover=\"style.cursor='pointer'\">";
		print "&nbsp;";
		print "</td>\n";

		print "</form>\n";
		print "</tr>\n";
	}

	# always display the 'add a new one'
	print "<tr bgcolor='lightblue'>\n";
	print "<form name='addanewdescription' id='addanewdescription' ";
	print "method='post' action='".$myself."'>\n";
	print "<input type='hidden' name='email' value='".$email."'>\n";
	print "<input type='hidden' name='mode' value='addanewdescription'>\n";
	print "<td width='5%' valing='top' align='center'>\n";
	selectlang('language');
	print "</td>\n";
	print "<td valign='top'>\n";
	print "<textarea name='content' cols='80' rows='3'>\n";
	print "</textarea>\n";
	# start the editor
	print "<script type='text/javascript'>\n";
        print "CKEDITOR.on( 'instanceReady', function(ev)\n";
	print "{ev.editor.dataProcessor.writer.setRules('p',{indent: false, breakBeforeOpen: false, breakAfterOpen: false,";
	print "breakBeforeClose: false, breakAfterClose:false});\n";
	print "})\n";
	print "CKEDITOR.replace('content',\n";
	print "{ toolbar: [['Source','Bold','Italic','Underline','Smiley']], startupMode: 'wysiwyg', width: '100%', ";
	print "height:'50',";
	print "keystrokes: [[ CKEDITOR.CTRL+66, 'bold' ],[ CKEDITOR.CTRL+73, 'italic' ],";
	print "[ CKEDITOR.CTRL+85, 'underline' ],[CKEDITOR.CTRL+83,'smiley']]});\n";
	print "</script>\n";

	print "</td>\n";
	print "<td align='right' width='10%'>\n";
	print "<img src='".$addicon."' alt='Add new description' title='add new description' width='16pt' ";
	print "onclick='javascript:document.addanewdescription.submit()' ";
	print "onmouseover=\"style.cursor='pointer'\">";
	print "&nbsp;";
	print "</td>\n";

	print "</form>\n";
	print "</tr>\n";
	print "</table>\n";

	print "</body>\n";
	print "</html>\n";
	exit;
}

# script to change the icon
print "<!-- user: ".$userid." name: ".$user." icon: ". $icon . " mode: ".$mode." -->\n";
print "<script>\n";
print "function selicon(iconname)\n";
print "{\n";
print " document.edituser.ticon.value=iconname;\n";
print " document.getElementById('me').src='" .$avatardir."/'+iconname;\n";
print "}\n";
print "</script>\n";

# Only root or the user himself can change data for other users, otherwise, bug off.
if( $email ne $userid && $isroot eq 'no' ) {
	closewindow();
}

# What am I supposed to do?
if($mode eq 'edit' || $mode eq 'add' ) {

	# check data
	if(! checkemail($email) ) {
		$msg="Invalid email address ($email)";
	} else {

		# truncate name and signature to 255 chars.
		$name=substr $name,0,255;
		$signature=substr $signature,0,255;

		# if new, check if the user doesn't already exists..
		if( $mode eq 'add' ) {
			my $q='select count(*) from users where email=? or name=?';
			my $r=$dbh->prepare($q);
			$r->execute($email,$name);
			my ($c) = $r->fetchrow_array();
			if( $c > 0 ) {
				$msg="Sorry, but the email or name you entered are already taken.";
			}
		}
	}

	if($msg eq '') {

		if($mode eq 'add') {

			# add a new user
			if($ticon eq '') {
				$ticon=$defavatar;
			}
			my $q=(q{
			insert into users 
			(email,name,signature,icon,password)
			values 
			(?,?,?,?,?)
			});

			my $sth=$dbh->prepare($q);
			$sth->execute($email,$name,$signature,$ticon,'nopass');

			# reset the mode
			$mode='edit';
		}

		# does the user require a custom icon?
		if($custom) {

			# get the name of the file and get rid of all the junk
			my $filename=$custom;
			my $safechar= "a-z0-9_.-";
			$filename=~s/ /_/g;
			$filename=lc $filename;
			$filename=~s/[^$safechar]//g;

			# and force it to be a .png!
			$filename.=".png";

			# now the file name should be reasonably clean
			open ( UPLOADFILE, ">$uploaddir/$filename" ) or die "$!";
			binmode UPLOADFILE;
			while(<$custom>) {
				print UPLOADFILE;
			}
			close UPLOADFILE;

			# is the file really a .png file ?
			my $type=`file $uploaddir/$filename`;
			if($type =~ /PNG/) {
				# custom icons goes in the custom dir
				`cp $uploaddir/$filename $base/$avatardir/custom/$filename`;
				$ticon="/custom/".$filename;
			} else {
				$msg="The uploaded file does not appear to be a PNG image.";
			}
			`rm -f $uploaddir/$filename`;
		}

		if($password1) {
			if($password1 eq $password2) {
				# update password
				$password=cryptpass($password1);
				my $q="update users set password=? where email=?";
				my $sth=$dbh->prepare($q);
				$sth->execute($password,$email);
			} else {
				$msg="Password mismatch!";
			}
		} 
		
		if( $mode eq 'edit' ) {
			# update things like name,icon and signature
			my $q=(q{update users set icon=?,signature=? where email=?
			});
			my $sth=$dbh->prepare($q);
			$sth->execute($ticon,$signature,$email);
		}
	}

	# Alert in case of errors
	if($msg) {
		print "<script>\n";
		print "alert('".$msg."');\n";
		print "</script>\n";

		# If error and add, reset the mode
		if( $mode eq 'add' ) {
			$mode='adduser';
		}
	}
}

# get the info for the user
my $q="select email,icon,name,signature,to_char(registered,'".$dateformat."') as registered,".
"to_char(lastseen,'".$dateformat."') as lastseen, isroot from users where email=?";

my $sth=$dbh->prepare($q);
$sth->execute($email);
my $u=$sth->fetchrow_hashref();

if( $u->{'icon'} eq '' ) {
	$u->{'icon'} = $defavatar;
}

if( $mode eq 'adduser' ) {
	printusertitle("Add new user",'',$defavatar,$avatardir,$dbh);
} else {
	printusertitle('User',$u->{'email'},$u->{'icon'},$avatardir,$dbh);
}

print "<hr>\n";

# show form
print "<form name='edituser' method='post' action='".$myself."' ";
print "enctype='multipart/form-data'>\n";
if( $mode ne 'adduser' ) {
	print "<input type='hidden' name='mode' value='edit'>\n";
	print "<input type='hidden' name='email' value='".$u->{'email'}."'>\n";
	print "<input type='hidden' name='name' value='".$u->{'name'}."'>\n";
} else {
	print "<input type='hidden' name='mode' value='add'>\n";
}

print "<table width='100%' border='0' cellspacing='0' cellpadding='3pt' ";
print "bgcolor='lightgrey'>\n";

print "<tr>\n";
print "<td width='10%' class='msgtext'>\n";
print "Name: ";
print "</td>";
print "<td class='msgtext'>\n";
if( $mode eq 'adduser' ) {
	print "<input type='text' size='60' name='name' value='";
	print scrub($query->param('name'));
	print "'>";
} else {
	print scrub($u->{'name'},$dbh);
}
print "</td>\n";
print "</tr>\n";

print "<tr>\n";
print "<td width='10%' class='msgtext'>\n";
print "e-mail:";
print "</td>";
print "<td class='msgtext'>\n";
if( $mode eq 'adduser' ) {
	print "<input type='text' size='60' name='email' value='";
	print $query->param('email');
	print "'>\n";
} else {
	print $u->{'email'};
}
print "</td>\n";
print "</tr>\n";

print "<tr valign='top'>\n";
print "<td width='10%' class='msgtext'>\n";
print "Signature (short):";
print "</td>";
print "<td class='msgtext'>\n";
print "<textarea name='signature' cols='60', rows='3'>\n";
if( $mode eq 'adduser' ){
	print $query->param('signature');
} else {
	print $u->{'signature'};
}
print "</textarea>\n";
print "</td>\n";
print "</tr>\n";

print "<tr>\n";
print "<td width='10%' class='msgtext'>\n";
print "Password:";
print "</td>";
print "<td class='msgtext'>\n";
print "<input type='password' size='60' name='password1' value=''>";
print "</td>\n";
print "</tr>\n";

print "<tr>\n";
print "<td width='10%' class='msgtext'>\n";
print "Password (repeat):";
print "</td>";
print "<td class='msgtext'>\n";
print "<input type='password' size='60' name='password2' value=''>";
print "</td>\n";
print "</tr>\n";
print "<tr>\n";

print "<tr>\n";
print "<td width='20%' class='msgtext'>\n";
print "First seen: ";
print "</td>";
print "<td class='msgtext'>\n";
if( $mode ne 'adduser' ) {
	print $u->{'registered'};
}
print "</td>\n</tr>\n";

print "<tr>\n";
print "<td width='20%' class='msgtext'>\n";
print "Last login:";
print "</td>";
print "<td class='msgtext'>\n";
if( $mode ne 'adduser' ) {
	print $u->{'lastseen'};
}
print "</td>\n</tr>\n";

print "<tr valign='top'>\n";
print "<td width='20%' class='msgtext'>\n";
print "Avatar:";
print "</td>";
print "<td class='msgtext'>\n";
print "<input type='hidden' name='ticon' value='".$u->{'icon'}."'>\n";

# show all the possible avatars - not 'custom' or CVS
opendir(DIR,$base.$avatardir);
while(my $file=readdir(DIR)) {
	if( $file !~ /^\./ && $file !~ /custom/ && $file !~ /CVS/ ) {
		print "<img src='".$avatardir."/".$file."' ";
		print "onmouseover=\"style.cursor='pointer'\" ";
		print "onclick=\"selicon('".$file."')\">";
		print " ";
	}
}
print "<br>\n";
print "Upload file .png (max ".$maxsizeicon."Kb): <input type='file' size='40' name='custom'>\n";
print "</td>\n";
print "</tr>\n";

print "<tr valign='top'>\n";
print "<td width='10%' class='msgtext' colspan='2'>\n";
print "Descriptions (these are usefull only if you are also authors):";
print "</td>";
print "</tr>\n";
print "<tr valign='top'>\n";
print "<td class='msgtext' colspan='2'>\n";
print "<iframe name='description' src='".$myself."?mode=showdescriptions&email=".$u->{'email'}."' ";
print " height='250px' width='100%'>\n";
print "</iframe>\n";
print "</td>\n";
print "</tr>\n";

print "<tr>\n";

print "<td colspan='2' align='right'>\n";

print "<input type='button' value='Apply' onclick='document.edituser.submit()'>\n";
print "<input type='button' value='Close' onclick='closeandrefresh()'>\n";
print "</table>\n";

print "</td>\n";
print "</tr>\n";
print "</table>\n";

print "</form><p><hr>\n";

printfooter();

exit;

# show a list of languages as a 'select'
sub selectlang
{
	my ($name)=@_;
	my $lang=getconfparam('languages',$dbh);
	my @languages=split / /,$lang;
	print "<select name='$name'>\n";
	foreach my $lang (@languages) {
		print "<option value='".$lang."'>";
		print $lang."\n";
	}
	print "</select>\n";
	return;
}

