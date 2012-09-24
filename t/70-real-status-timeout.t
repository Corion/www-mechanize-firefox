use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Test::More;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

my $mech = eval {WWW::Mechanize::Firefox->new(
    #log => [qw[debug]],
    autodie => 0,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 5;
};

my $server = Test::HTTP::LocalServer->spawn(
    #debug => 1
);
$mech->get($server->url);

my $response = $mech->response;

isn't $response, undef, "We identified a response";
is $response->code, 200, 'We got a good response';

my $timeout = 2;

$mech->update_html(<<HTML);
<html><body>
<h1>Testing Firefox timeout reaction ($timeout s)</h1>
<h2>Please stand by</h2>
</body></html>
HTML

$mech->get($server->error_close($timeout)); # closes the connection after $timeout seconds?
$response = $mech->response;

isn't $response, undef, "We identified a response";
ok !$mech->success, "The response is an error response";
is $response->code, 500, 'We got some internal error (500)';

$server->kill; # it might still be waiting to time out

# ->get( sync => 0 )
# sleep 5
# ->stop
# response / ->code()

undef $mech;
$MozRepl::RemoteObject::WARN_ON_LEAKS = 1;