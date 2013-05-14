use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Test::More;

use lib '../inc', 'inc';
require Test::HTTP::LocalServer;

use t::helper;

my $err = t::helper::default_unavailable();
if ($err) {
    plan skip_all => "Couldn't connect to MozRepl: $err";
    exit
} else {
    plan tests => 8;
};

my $mech=
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        #log => [qw[debug]],
    );

my @cleanup;
my $magic = "$0-shazam";

my $server = Test::HTTP::LocalServer->spawn(
    #debug => 1,
);

$mech->get($server->url);
is $mech->status, 200, "We got the local page";

unlike $server->get_log, qr/$magic/, "We sent no magic cookie";

my $cookies = $mech->cookies;
$cookies->set_cookie( 
           1,
           'www_mechanize_firefox_test',
           $magic,
           "/",
           $server->url->host,
           $server->url->port,
           undef,
           undef,
           15, # 15 seconds expiry
);

my $count;
$cookies->load;

$mech->get($server->url);
is $mech->status, 200, "We got the local page";

my $log = $server->get_log;
like $log, qr/^Cookie:.*? \Qwww_mechanize_firefox_test=$magic\E/m, "We sent the magic cookie";
like $log, qr/^Cookie:.*? \Qlog-server\E/m, "We sent the webserver cookie";

push @cleanup, "$0.tmp";
END { unlink $_ for @cleanup };

$mech->save_url($server->url . "save_url_test" => $cleanup[-1]);

$log = $server->get_log;
(my $cookie) = ($log =~ /^(Cookie:.*?)$/m);
like $log, qr/^Cookie:.*? \Qwww_mechanize_firefox_test=$magic\E/m, "We sent the magic cookie"
    or diag $cookie;

like $log, qr/^Cookie:.*? \Qlog-server\E/m, "We sent the webserver cookie"
    or diag $cookie;

# Scan for HTTPOnly cookie
$cookies->scan(sub{ $count++ if $_[1] eq 'log-server-httponly' and $_[2] eq 'supersecret' });
is $count, 1, "We found the HTTPOnly cookie";

$server->stop;
