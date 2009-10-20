#!perl -w
use strict;
use Test::More tests => 3;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new( autodie => 0 );
isa_ok $mech, 'WWW::Mechanize::FireFox';

#my ($site,$estatus) = ('http://doesnotexit.example',500);
my ($site,$estatus) = ('http://corion.net/test',200);
my $status = $mech->get($site);

is $mech->uri, $site, "Navigating to $site";

#diag $mech->uri;

is $status, $estatus, "GETting $site"
    or diag $mech->content;
