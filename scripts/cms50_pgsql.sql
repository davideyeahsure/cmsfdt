/* CMS 5.0 PgSQL script */
/* For the creation of the basic db for PostGre */

# drop everything if already there.
drop table if exists configuration cascade;
drop table if exists templates cascade;
drop table if exists images;
drop table if exists rssfeeds;
drop table if exists fragments cascade;
drop table if exists deftexts cascade;
drop table if exists comments cascade;
drop table if exists documentscontent cascade ;
drop table if exists links cascade;
drop table if exists documents cascade;
drop table if exists groups cascade;
drop table if exists hostaliases cascade;
drop table if exists hosts cascade;
drop table if exists userdesc cascade;
drop table if exists users cascade;
drop table if exists css cascade;

/* configuration parameters */
create table configuration (
	paramid		varchar(255)	not null,
	value		varchar(255)	not null,
	updated		timestamp	not null default now(),
	description	varchar(255)	not null default '',
	primary key (paramid)
);

/* Add the default parameters to the system */
insert into configuration (paramid,value,updated,description) values ('404icon','warning.png','2009-06-19 05:56:18','icon used for the 404 document');
insert into configuration (paramid,value,updated,description) values ('accepticon','accept.png','2009-06-16 06:38:06','confirm/accept icon');
insert into configuration (paramid,value,updated,description) values ('addbutton','add.png','2009-06-12 12:19:04','add button icon');
insert into configuration (paramid,value,updated,description) values ('addicon','add.png','2009-06-14 04:59:28','add icon');
insert into configuration (paramid,value,updated,description) values ('articles','article.png','2009-06-12 02:34:45','articles icon');
insert into configuration (paramid,value,updated,description) values ('avatardir','/icons/avatars','2009-06-14 12:38:56','subdir where the avatars icons are placed');
insert into configuration (paramid,value,updated,description) values ('base','/var/www/cms40','2009-07-05 07:26:26','base directory');
insert into configuration (paramid,value,updated,description) values ('buttondir','/icons/32x32','2009-06-14 12:39:22','directory for the buttons');
insert into configuration (paramid,value,updated,description) values ('closeicon','remove.png','2009-06-14 12:25:41','icon used in the close command');
insert into configuration (paramid,value,updated,description) values ('commaddicon','comment_add.png','2009-06-23 14:23:51','icon used in the enable comments command');
insert into configuration (paramid,value,updated,description) values ('commdelicon','comment_remove.png','2009-06-23 14:24:01','icon used in the disable comments command');
insert into configuration (paramid,value,updated,description) values ('commedit-fh','480','2009-06-19 11:04:01','height for the edit comment wnd');
insert into configuration (paramid,value,updated,description) values ('commedit-fw','770','2009-06-19 11:03:39','width for the edit comment wnd');
insert into configuration (paramid,value,updated,description) values ('comments-fh','600','2009-12-07 18:14:51','height for the edit comment window');
insert into configuration (paramid,value,updated,description) values ('comments-fw','800','2009-12-07 18:14:43','width for the edit comment window');
insert into configuration (paramid,value,updated,description) values ('commentsicon','comments.png','2009-06-14 12:25:59','comments icon');
insert into configuration (paramid,value,updated,description) values ('config-fh','230','2009-06-12 02:34:45','height for the edit configuration parameters wnd');
insert into configuration (paramid,value,updated,description) values ('config-fw','750','2009-06-12 02:34:45','width for the edit configuration parameters wnd');
insert into configuration (paramid,value,updated,description) values ('configicon','process.png','2009-06-14 12:26:06','config params icon');
insert into configuration (paramid,value,updated,description) values ('cookiehost','softland','2009-06-12 05:24:16','identification cookie');
insert into configuration (paramid,value,updated,description) values ('copybutton','accept.png','2009-06-13 04:21:24','icon used in the copy command');
insert into configuration (paramid,value,updated,description) values ('copyicon','windows.png','2009-06-13 04:21:37','icon used in the copy button');
insert into configuration (paramid,value,updated,description) values ('css','cms3.css','2009-06-15 07:42:43','default CSS');
insert into configuration (paramid,value,updated,description) values ('debug','','2009-06-28 13:00:32','enable/disable debugging');
insert into configuration (paramid,value,updated,description) values ('defaultfoldericon','folder_full_accept.png','2009-06-29 10:00:34','icon used for the open folder function');
insert into configuration (paramid,value,updated,description) values ('defavatar','user.png','2009-06-12 02:34:45','default avatar icons');
insert into configuration (paramid,value,updated,description) values ('defdocicon','fdcba9c2680d8f9b435c9292fadf602e.png','2009-06-16 05:15:01','default document\'s icon');
insert into configuration (paramid,value,updated,description) values ('deflang','en','2009-06-13 12:16:40','default language');
insert into configuration (paramid,value,updated,description) values ('delicon','remove.png','2009-06-13 04:21:56','icon used in the delete or remove command');
insert into configuration (paramid,value,updated,description) values ('disableicon','search_remove.png','2009-06-13 12:21:50','icon used in the disable display command');
insert into configuration (paramid,value,updated,description) values ('dociconsdir','/icons/docicons','2009-06-14 12:39:38','documents icon directory');
insert into configuration (paramid,value,updated,description) values ('documents-fh','720','2009-06-29 18:27:03','height for the edit document window');
insert into configuration (paramid,value,updated,description) values ('documents-fw','980','2009-06-12 02:34:45','width for the edit document window');
insert into configuration (paramid,value,updated,description) values ('documentsicon','calendar_empty.png','2009-06-14 12:26:19','document icon');
insert into configuration (paramid,value,updated,description) values ('downicon','user.png','2009-06-17 05:02:10','Demote to user icon');
insert into configuration (paramid,value,updated,description) values ('editicon','comment_edit.png','2009-06-23 14:25:27','icon used in the edit comments command');
insert into configuration (paramid,value,updated,description) values ('edituserheight','800','2009-06-16 05:36:27','height for the edit user window');
insert into configuration (paramid,value,updated,description) values ('edituserwidth','900','2009-06-12 02:34:45','width for the edit user window');
insert into configuration (paramid,value,updated,description) values ('emocode','&gt:( &gt;:-( 8-) 8) :-D :D :-) :) ;-) ;) :-( :( ;-P ;-p ;P ;p :-P :P :-p :p :-O :O','2009-06-23 13:05:18','Code for the emoticons');
insert into configuration (paramid,value,updated,description) values ('emodecode','mad mad cool cool happy happy glad glad wink wink sad sad tongue tongue tongue tongue tongue tongue tongue tongue surprise suprise','2009-07-17 20:33:03','Decode for the emoticons');
insert into configuration (paramid,value,updated,description) values ('emoticonsdir','/icons/emo/','2009-06-14 12:39:49','subdir where the emoticons icons are placed');
insert into configuration (paramid,value,updated,description) values ('enableicon','search_add.png','2009-06-13 12:21:25','icon used in the enable display command');
insert into configuration (paramid,value,updated,description) values ('feed-fh','500','2009-06-13 05:42:31','height for the edit RSS feed window');
insert into configuration (paramid,value,updated,description) values ('feed-fw','930','2009-06-13 05:42:40','width for the edit RSS feed window');
insert into configuration (paramid,value,updated,description) values ('folderadd','folder_add.png','2009-06-30 15:47:44','Add a folder icon');
insert into configuration (paramid,value,updated,description) values ('foldericon','folder_full.png','2009-06-29 09:59:23','icon used for the open folder function');
insert into configuration (paramid,value,updated,description) values ('fragments-fh','300','2009-06-14 05:48:41','height for the edit fragments window');
insert into configuration (paramid,value,updated,description) values ('fragments-fw','850','2009-06-14 05:48:33','width for the edit fragments windows');
insert into configuration (paramid,value,updated,description) values ('fragmentsicon','attachment.png','2009-06-14 12:26:26','fragment icon');
insert into configuration (paramid,value,updated,description) values ('genrssicon','rss.png','2009-06-13 05:47:48','rss feed icon');
insert into configuration (paramid,value,updated,description) values ('groups-fh','420','2009-06-13 06:32:49','height for the edit group window');
insert into configuration (paramid,value,updated,description) values ('groups-fw','900','2009-06-13 06:32:59','width for the edit group window');
insert into configuration (paramid,value,updated,description) values ('groupsicon','folder_full.png','2009-06-14 12:26:33','icon for the groups');
insert into configuration (paramid,value,updated,description) values ('helpicon','help.png','2009-06-18 07:02:07','icon for the help function');
insert into configuration (paramid,value,updated,description) values ('helplink','http://helpcms.onlyforfun.net/','2009-07-17 07:27:35','where is the help?');
insert into configuration (paramid,value,updated,description) values ('hosts-fh','400','2009-06-16 07:46:06','height for the edit host window');
insert into configuration (paramid,value,updated,description) values ('hosts-fw','900','2009-06-16 07:46:13','width for the edit host window');
insert into configuration (paramid,value,updated,description) values ('hostsicon','home.png','2009-06-14 12:26:40','hosts icon');
insert into configuration (paramid,value,updated,description) values ('htmlcode','<[^>]+>,& ,ÃÂ¨,ÃÂ©,Ãâ°,ÃË,ÃÂ­,ÃÂ¬,ÃÂ²,ÃÂ³,ÃÂ¹,ÃÂº,Ãâ¬,ÃÂ,ÃÂ¡,ÃÂ ,",\',ò,è,à,é,ù','2009-06-24 18:02:43','Code for the char replacement in comments');
insert into configuration (paramid,value,updated,description) values ('htmldecode',',&amp; ,&egrave;,&eacute;,&Egrave;,&Eacute;,&igrave;,&iacute&,&ograve;,&oacute;,&ugrave;,&uacutre&,&Agrave;,&Aacute;,&agrave;,&aacute;,&quot;,&#39;,&ograve;,&egrave;,&agrave;,&eacute;,&ugrave;','2009-06-23 13:10:21','Char for the char replacement in comments');
insert into configuration (paramid,value,updated,description) values ('iconsdir','/icons/16x16','2009-06-14 12:40:01','icons');
insert into configuration (paramid,value,updated,description) values ('images-fh','480','2009-06-20 06:16:53','height for the edit image wnd');
insert into configuration (paramid,value,updated,description) values ('images-fw','770','2009-06-20 06:16:38','width for the edit image wnd');
insert into configuration (paramid,value,updated,description) values ('imgdir','img','2009-06-20 05:35:56','base directory for images');
insert into configuration (paramid,value,updated,description) values ('imgicon','image.png','2009-06-20 04:33:47','icon for the Images function');
insert into configuration (paramid,value,updated,description) values ('imgmaxsize','250','2009-06-20 06:58:14','maximum size (in kbyte) o picture to upload');
insert into configuration (paramid,value,updated,description) values ('ips','','2009-06-12 02:34:45','list of IPs with no viewing restrictions');
insert into configuration (paramid,value,updated,description) values ('js','/default.js','2009-06-12 02:34:45','default javascript name');
insert into configuration (paramid,value,updated,description) values ('languages','en it fr nl de','2009-06-14 02:00:06','supported languages');
insert into configuration (paramid,value,updated,description) values ('limit','4','2009-06-12 02:34:45','max document to list');
insert into configuration (paramid,value,updated,description) values ('lockicon','lock.png','2009-06-17 04:06:50','lock closed icon');
insert into configuration (paramid,value,updated,description) values ('login','/cgi-bin/login.pl','2009-06-12 02:34:45','login script to use');
insert into configuration (paramid,value,updated,description) values ('logindefault','"scrollbars=1,location=0,toolbar=no,menubar=no,status=0,width=790,height=590,resizable=yes"','2009-06-12 02:34:45','default options for the login screen');
insert into configuration (paramid,value,updated,description) values ('loginicon','repeat.png','2009-06-14 12:33:12','login icon');
insert into configuration (paramid,value,updated,description) values ('logout','/cgi-bin/edituser.pl','2009-06-12 02:34:45','logout user script to use');
insert into configuration (paramid,value,updated,description) values ('logouticon','eject.png','2009-06-14 12:31:52','logout icon');
insert into configuration (paramid,value,updated,description) values ('maxsizeicon','10','2009-06-20 07:00:54','Maximum size of a user icon (in Kb)');
insert into configuration (paramid,value,updated,description) values ('mkthumb','/usr/local/bin/convert -resize 300x200','2009-07-17 17:04:24','instruction used to resize and create thumbnails');
insert into configuration (paramid,value,updated,description) values ('pageadd','page_add.png','2009-06-30 15:48:04','page add icon');
insert into configuration (paramid,value,updated,description) values ('postnew','/cgi-bin/postnew.pl','2009-06-12 02:34:45','postnew script to use');
insert into configuration (paramid,value,updated,description) values ('preview','/cgi-bin/doc.pl','2009-06-12 02:34:45','preview script to use');
insert into configuration (paramid,value,updated,description) values ('previewicon','search.png','2009-06-14 12:26:53','preview icon (document edit form)');
insert into configuration (paramid,value,updated,description) values ('publishicon','favorite_add.png','2009-06-13 04:22:20','icon used in the publish command');
insert into configuration (paramid,value,updated,description) values ('pviewicon','search.png','2009-06-14 04:53:50','icon used for the preview (small)');
insert into configuration (paramid,value,updated,description) values ('replyicon','comment.png','2009-06-14 00:28:13','icon used in the reply comments command');
insert into configuration (paramid,value,updated,description) values ('resetpwd','key.png','2009-06-12 02:34:45','reset password icon');
insert into configuration (paramid,value,updated,description) values ('rssfeeddir','rss','2009-06-21 11:46:18','directory for RSS feed (relative to the base dir)');
insert into configuration (paramid,value,updated,description) values ('rssicon','rss.png','2009-06-14 12:27:03','rss feed icon');
insert into configuration (paramid,value,updated,description) values ('selecticon','accept.png','2009-06-13 04:44:40','icon used for the select command');
insert into configuration (paramid,value,updated,description) values ('swishdir','/var/www/cms40/swish','2009-07-22 17:43:03','Directory where the swish indexes are located');
insert into configuration (paramid,value,updated,description) values ('templates-fh','270','2009-06-12 02:34:45','height for the edit template window');
insert into configuration (paramid,value,updated,description) values ('templates-fw','940','2009-06-12 02:34:45','width for the edit template window');
insert into configuration (paramid,value,updated,description) values ('templatesicon','application.png','2009-06-14 12:27:20','template icon');
insert into configuration (paramid,value,updated,description) values ('texts-fh','240','2009-06-12 02:34:45','height for the edit text window');
insert into configuration (paramid,value,updated,description) values ('texts-fw','750','2009-06-12 02:34:45','width for the edit text window');
insert into configuration (paramid,value,updated,description) values ('textsicon','word.png','2009-06-14 12:27:14','texts icon');
insert into configuration (paramid,value,updated,description) values ('thumbdir','thumbs','2009-06-20 05:39:08','subdir of the image/host dir where the thumbs are');
insert into configuration (paramid,value,updated,description) values ('title','CMS Fdt 4.0','2009-09-09 11:00:10','main title of the web site');
insert into configuration (paramid,value,updated,description) values ('topics','home.png','2009-06-12 02:34:45','document icon');
insert into configuration (paramid,value,updated,description) values ('unlockicon','lock_off.png','2009-06-17 04:06:39','lock open icon');
insert into configuration (paramid,value,updated,description) values ('unpublishicon','favorite_remove.png','2009-06-13 04:22:36','icon used in the un-publish command');
insert into configuration (paramid,value,updated,description) values ('upicon','user_accept.png','2009-06-17 05:01:55','Promote to root icon');
insert into configuration (paramid,value,updated,description) values ('uploaddir','/tmp/upload','2009-06-12 02:34:45','temporary directory for uploading');
insert into configuration (paramid,value,updated,description) values ('userdefault','"scrollbars=1,location=0,toolbar=no,menubar=no,status=0,width=1000,height=630,resizable=yes"','2009-06-12 02:34:45','default options for the user edit screen');
insert into configuration (paramid,value,updated,description) values ('userremoveicon','user_remove.png','2009-06-16 06:38:45','user remove icon');
insert into configuration (paramid,value,updated,description) values ('users-fh','690','2009-06-12 02:34:45','height fo the edit user window');
insert into configuration (paramid,value,updated,description) values ('users-fw','900','2009-06-12 02:34:45','width for the edit user window');
insert into configuration (paramid,value,updated,description) values ('usersicon','users.png','2009-06-14 12:27:29','users icon');


/* User's table */
create table users (
	email		varchar(255)	not null,
	icon		varchar(255)	not null,
	name		varchar(255)	not null,
	signature	varchar(255)	not null default '',
	registered	timestamp	not null default current_timestamp,
	lastseen	timestamp 	not null default current_timestamp,
	password	varchar(255)	not null default 'disabled',
	random		varchar(255)	default null,
	isroot		boolean		default false,
	userchk		varchar(255)	default null,
	primary key (email)
);

create index users_names on users (name);

/* add default 'admin' user */
insert into users (email,icon,name,signature,password,isroot)
	values ('root@inexistent.com','boy_8.png','administrator','nosign',
		'xurjAt6CAJVDc',true);

/* descriptions for the users */
create table userdesc (
	email 		varchar(255) 	references users (email),
	language	char(2)		not null default 'en',
	content		text,
	primary key (email,language)
);

/* add default description for the admin user */
insert into userdesc (email,content) values 
	('root@inexistent.com','The Administrator');

/* CSS Table */
create table css (
	cssid 		varchar(255) 	not null default 'default',
	filename	varchar(255)	not null default 'default.css',
	description	varchar(255)	not null default 'Default CSS',
	created		timestamp	default now(),
	updated		timestamp	default now(),
	primary key (cssid)
);

/* Hosts table */
create table hosts (
	hostid		varchar(255)	not null,
	created		timestamp	default now(),
	cssid		varchar(255)	references css (cssid),
	deflang		char(2)		default 'en',
	owner		varchar(255)	references users (email),
	primary key (hostid)
);

/* Host aliases */
create table hostaliases (
	hostid		varchar(255)	references hosts (hostid),
	alias		varchar(255)	not null,
	primary key (hostid,alias)
);

create index host_aliases on hostaliases (alias);

/* Image table */
create table images (
	hostid		varchar(255)	references hosts (hostid),
	imageid		varchar(255)	not null default 'image',
	created		timestamp	default now(),
	filename	varchar(255)	not null,
	author		varchar(255)	references users (email),
	primary key (hostid,imageid)
);

create index images_authors on images (author);

/* RSS Feeds */
create table rssfeeds (
	hostid		varchar(255)	references hosts (hostid),
	filename	varchar(255)	not null,
	title		varchar(255)	not null,
	description	text		not null,
	link		varchar(255)	not null,
	language	char(5)		not null default 'it-it',
	author		varchar(255)	references users (email),
	copyright	varchar(255)	not null,
	subject		varchar(255)	not null,
	taxo		varchar(255)	not null,
	lastdone	timestamp,
	primary key (hostid,filename)
);

create index rsstitle on rssfeeds(title);

/* Templates */
create table templates (
	hostid		varchar(255)	references hosts (hostid),
	title		varchar(255)	not null,
	content		text		not null,
	updated		timestamp	default now(),
	isdefault	boolean		default false,
	primary key (hostid,title)
);

/* Default texts */
create table deftexts (
	hostid		varchar(255)	references hosts (hostid),
	textid		varchar(255)	not null,
	language	char(2)		not null default 'en',
	content		varchar(255)	not null,
	primary key (hostid,textid,language)
);

/* Fragments */
create table fragments (
	hostid		varchar(255)	references hosts (hostid),
	fragid		varchar(255)	not null,
	language	char(2)		not null default 'en',
	content		text		not null,
	primary key (hostid,fragid,language)
);

/* Groups
   The UNIQUE constraint on parentid is to ensure that two groups can't have the same name
   at the same level (duplicated directories)
*/
create table groups (
	hostid		varchar(255)	references hosts,
	groupname	varchar(255)	not null default '/',
	groupid 	numeric		not null default 0,
	parentid	numeric 	not null default 0,
	template	varchar(255)    not null,
	cssid		varchar(255)	references css,
	icon		varchar(255)	not null default '',
	rssid		varchar(255)	not null default '',
	author		varchar(255)	references users,
	owner		varchar(255)	references users,
	comments	boolean		default false,
	moderated	boolean		default true,
	moderator	varchar(255)	references users,
	isdefault	boolean		default false,
	primary key (hostid,groupid),
	foreign key (hostid,parentid) references groups,
	foreign key (hostid,template) references templates,
	unique (hostid,parentid,groupname)
);

/* Documents */
create table documents (
	hostid		varchar(255)	references hosts,
	groupid 	numeric		not null,
	documentid	numeric 	not null,
	template	varchar(255)    not null,
	cssid		varchar(255)	references css,
	icon		varchar(255)	not null default '',
	rssid		varchar(255)	not null default '',
	author		varchar(255)	references users,
	moderator 	varchar(255)	references users,
	moderated	boolean		default true,
	comments	boolean		default false,
	isdefault	boolean		default false,
	is404		boolean		default false,
	display		boolean		default false,
	created		timestamp	default now(),
	updated		timestamp	default now(),
	updated		timestamp	default null,
	primary key (hostid,groupid,documentid),
	foreign key (hostid,template) references templates
);

/* Documents' content
   Note that the title has to be UNIQUE per host in order to use the 'REF' tag.
*/
create table documentscontent (
	hostid		varchar(255)	references hosts,
	groupid 	numeric 	not null,
	documentid	numeric 	not null,
	language	char(2)		default 'en',
	title		varchar(255)	not null,
	excerpt		text		not null,
	content		text		not null,
	approved	boolean		default false,
	primary key (hostid,groupid,documentid,language),
	foreign key (hostid,groupid,documentid) references documents,
	unique (hostid,title)
);

/* Documents' links */
/* The PK is the host + link, 'cause you can't have the same link twice in an host. */
create table links (
	link		varchar(255) 	not null,
	hostid		varchar(255)	references hosts,
	groupid 	numeric 	not null,
	documentid	numeric		not null,
	primary key (hostid,link),
	foreign key (hostid,groupid,documentid) references documents
);

/* Comments */
/* Comments have no "language" */
create table comments (
	hostid		varchar(255)	references hosts,
	groupid 	numeric		not null,
	documentid	numeric		not null,
	commentid	numeric		not null default 0,
	parentid	numeric 	not null default 0,
	author		varchar(255)	references users (email),
	username	varchar(255)	not null default 'Anonymous Coward',
	clientip	varchar(255)	not null default 'unknown',
	created		timestamp	default now(),
	approved	boolean		default false,
	spam		boolean		default false,
	spamscore	varchar(255)	default '',
	title		varchar(255)	default 'no title',
	content		text		default 'no comment',
	primary key (hostid,groupid,documentid,commentid),
	foreign key (hostid,groupid,documentid) references documents,
	foreign key (hostid,groupid,documentid,parentid) references comments
);

grant all privileges on comments to cms50;
grant all privileges on configuration to cms50;
grant all privileges on css to cms50;
grant all privileges on deftexts to cms50;
grant all privileges on documents to cms50;
grant all privileges on documentscontent to cms50;
grant all privileges on firewall to cms50;
grant all privileges on fragments to cms50;
grant all privileges on groups to cms50;
grant all privileges on hostaliases to cms50;
grant all privileges on hosts to cms50;
grant all privileges on images to cms50;
grant all privileges on links to cms50;
grant all privileges on rssfeeds to cms50;
grant all privileges on templates to cms50;
grant all privileges on userdesc to cms50;
grant all privileges on users to cms50;

