#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::FireFox;

my $mech = eval { WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 4;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

my ($site,$estatus) = ('http://search.cpan.org/',200);
my $res = $mech->get($site);

is $mech->uri, $site, "Navigating to $site";

is $res->code, $estatus, "GETting $site"
    or diag $mech->content;

ok $mech->success, 'We consider this response successful';