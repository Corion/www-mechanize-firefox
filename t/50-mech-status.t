#!perl -w
use strict;
use Test::More tests => 3;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new( autodie => 0 );
isa_ok $mech, 'WWW::Mechanize::FireFox';

my ($site,$estatus) = ('http://doesnotexit.example',500);
my $status = $mech->get($site);

is $mech->uri, $site, "Navigating to $site";

is $status, $estatus, "GETting $site"
    or diag $mech->content;
