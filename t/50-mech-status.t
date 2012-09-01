#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 6;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

my ($site,$estatus) = ('http://'.rand(1000).'.www.doesnotexist.example/',500);
my $res = $mech->get($site);

is $mech->uri, $site, "Navigating to (nonexisting) $site";

if( ! isa_ok $res, 'HTTP::Response', 'The response') {
    SKIP: { skip "No response returned", 1 };
} else {
    my $c = $res->code;
    like $res->code, qr/^(404|5\d\d)$/, "GETting $site gives a 5xx (no proxy) or 404 (proxy)"
        or diag $mech->content;

    like $mech->status, qr/^(404|5\d\d)$/, "GETting $site returns a 5xx (no proxy) or 404 (proxy) HTTP status"
        or diag $mech->content;
};

ok !$mech->success, 'We consider this response not successful';