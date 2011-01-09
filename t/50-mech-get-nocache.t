#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]],
    #on_event => 1,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 6;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

my ($site,$estatus) = ('http://search.cpan.org/',200);
my $res = $mech->get($site, no_cache => 1);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

is $res->code, $estatus, "GETting $site returns HTTP code $estatus from response"
    or diag $mech->content;

is $mech->status, $estatus, "GETting $site returns HTTP status $estatus from mech"
    or diag $mech->content;

ok $mech->success, 'We consider this response successful';