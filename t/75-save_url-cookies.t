use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Test::More;

my $mech = eval {
    WWW::Mechanize::Firefox->new(
       #log => ['debug'],
    )
};

if (! eval {
    use lib '../inc', 'inc';
    require Test::HTTP::LocalServer;
    1;
}) {
    undef $mech;
};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 7;
};

my $server = Test::HTTP::LocalServer->spawn;
my $magic = "$0-shazam";

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
           5, # 5 seconds expiry
);

my $count;
$cookies->load;
#$cookies->scan(sub{ diag "@_" if @_ =~ /hellboy/; $count++; });

$mech->get($server->url);
is $mech->status, 200, "We got the local page";

my $log = $server->get_log;
like $log, qr/^Cookie:.*? \Qwww_mechanize_firefox_test=$magic\E/m, "We sent the magic cookie";
like $log, qr/^Cookie:.*? \Qlog-server\E/m, "We sent the webserver cookie";

my @cleanup;
END { unlink $_ for @cleanup };

$mech->save_url($server->url . "save_url_test" => push @cleanup, "$0.tmp");

$log = $server->get_log;
like $log, qr/^Cookie:.*? \Qwww_mechanize_firefox_test=$magic\E/m, "We sent the magic cookie";
like $log, qr/^Cookie:.*? \Qlog-server\E/m, "We sent the webserver cookie";


$server->stop;
