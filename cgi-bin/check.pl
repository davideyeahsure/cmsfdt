#!/usr/bin/perl

use CGI qw/:standard/;

my $method=$ENV{'REQUEST_METHOD'};

print "<!doctype html public \"-//W3C//DTD HTML 4.01 Transitional//EN\"";
print "\"http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd\">\n";
print "\n";
print "<html>";
print "<body>\n";
print "Method: $method\n";
print "</body>\n";
print "</html>\n";

