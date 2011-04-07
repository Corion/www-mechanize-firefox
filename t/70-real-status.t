use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Test::More;

my $mech = eval {WWW::Mechanize::Firefox->new(
    #log => [qw[debug]],
    autodie => 0,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 8;
};

$mech->get('http://google.de');
my $response = $mech->response;

isn't $response, undef, "We identified a response";
is $response->code, 200, 'We got a good response';

undef $mech->{response};
$mech->get('http://doesnotexist.example');
$response = $mech->response;

isn't $response, undef, "We identified a response";
like $response->code, qr/^(404|5\d\d)$/, 'We got a good response for a nonexistent domain';
ok ! $mech->success, "And the response is not considered a success";

$response = $mech->get('http://doesnotexist.example');

isn't $response, undef, "We identified a response, directly";
like $response->code, qr/^(404|5\d\d)$/, 'We got a good response for a nonexistent domain';
ok ! $mech->success, "And the response is not considered a success";

undef $mech;
$MozRepl::RemoteObject::WARN_ON_LEAKS = 1;