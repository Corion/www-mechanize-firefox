#!perl -w
use strict;
use Test::More tests => 4;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new( autodie => 0 );
isa_ok $mech, 'WWW::Mechanize::FireFox';

my ($site,$estatus) = ('http://www.doesnotexit.example/',500);
my $res = $mech->get($site);

is $mech->uri, $site, "Navigating to $site";

is $res->code, $estatus, "GETting $site"
    or diag $mech->content;

ok !$mech->success, 'We consider this response not successful';