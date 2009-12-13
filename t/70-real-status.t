use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Test::More;

my $mech = eval {WWW::Mechanize::Firefox->new()};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 6;
};

$mech->get('http://google.de');
my $response = $mech->response;

isn't $response, undef, "We identified a response";
is $response->code, 200, 'We got a good response';

$mech->get('http://doesnotexist.example');
my $response = $mech->response;

isn't $response, undef, "We identified a response";
is $response->code, 500, 'We got a good response for a nonexistent domain';

$response = $mech->get('http://doesnotexist.example');

isn't $response, undef, "We identified a response, directly";
is $response->code, 500, 'We got a good response for a nonexistent domain, directly';

undef $mech;