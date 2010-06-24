use strict;
use lib 'C:/Projekte/MozRepl-RemoteObject/lib';
use WWW::Mechanize::Firefox;
use Time::HiRes;

my $mech = WWW::Mechanize::Firefox->new(
    #log => ['debug'],
);

my ($window, $type) = $mech->eval('window');

print "Going fullscreen\n";
$window->{fullScreen} = 1;

sleep 10;

print "Going back to normal\n";
$window->{fullScreen} = 0;