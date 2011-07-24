use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Test::More;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

use t::helper;

# What instances of Firefox will we try?
my $instance_port = 4243;
my @instances = t::helper::firefox_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 11*@instances;
};

sub new_mech {
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        #log => [qw[debug]],
        @_,
    );
};

my $server = Test::HTTP::LocalServer->spawn(
    #debug => 1
);

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($instance, $mech) = @_;
    $mech->get($server->url);

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

    $mech->get($server->error_notfound('foo'));
    $response = $mech->response;

    isn't $response, undef, "We identified a response";
    ok !$mech->success, "The response is an error response";
    is $response->code, 404, 'We got the correct error number (404)';

    # The browser has no chance to identify this one
    # as we don't send a content-length header here
    #$mech->get($server->error_after_headers);
    #$response = $mech->response;

    #isn't $response, undef, "We identified a response";
    #ok !$mech->success, "The response is an error response";
    #is $response->code, 500, 'We got the correct error number (500)';

    undef $mech;
});
$MozRepl::RemoteObject::WARN_ON_LEAKS = 1;
