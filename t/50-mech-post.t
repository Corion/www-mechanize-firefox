#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

use t::helper;

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 8;
};

my $mech=
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        #log => [qw[debug]],
    );

my $server = Test::HTTP::LocalServer->spawn(
    #debug => 1
);

isa_ok $mech, 'WWW::Mechanize::Firefox';

my ($site,$estatus) = ($server->url,200);
my $res = $mech->post($site, params => { query => 'queryValue1', query2 => 'queryValue2' });
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

is $res->code, $estatus, "POSTting $site returns HTTP code $estatus from response"
    or diag $mech->content;

is $mech->status, $estatus, "POSTting $site returns HTTP status $estatus from mech"
    or diag $mech->content;

ok $mech->success, 'We consider this response successful';

like $mech->content, qr/queryValue1/, "We find our parameter 'query'";
like $mech->content, qr/queryValue2/, "We find our parameter 'query2'";