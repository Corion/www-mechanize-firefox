#!perl -w
use strict;
use Getopt::Long;
use Firefox::Application;

my $ff = Firefox::Application->new();

# Check the network proxy settings
my $prefs = $ff->repl->expr(<<'JS');
  Components.classes["@mozilla.org/preferences-service;1"]
    .getService(Components.interfaces.nsIPrefBranch);
JS

print "Your proxy settings are\n";
print "Proxy type\t",  $prefs->getIntPref('network.proxy.type'),"\n";
print "HTTP  proxy\t", $prefs->getCharPref('network.proxy.http'),"\n";
print "HTTP  port\t",  $prefs->getIntPref('network.proxy.http_port'),"\n";
print "SOCKS proxy\t", $prefs->getCharPref('network.proxy.socks'),"\n";
print "SOCKS port\t",  $prefs->getIntPref('network.proxy.socks_port'),"\n";

# Switch off the proxy
if ($prefs->getIntPref('network.proxy.type') != 0) {
    $prefs->setIntPref('network.proxy.type',0);
};

# Switch on the manual proxy configuration
$prefs->setIntPref('network.proxy.type',1);


=head1 NAME

proxy-settings.pl - display and change the proxy settings of Firefox

=head1 SYNOPSIS

proxy-settings.pl

=head1 DESCRIPTION

This shows how to read and write configuration settings
from L<about:config> . Particularly, it shows how
to switch the proxy settings in Firefox on and off.

=cut