#!perl -w
use strict;
use Test::More;
use File::Basename;

use File::Temp 'tempdir';
use Firefox::Application;
use lib '.';

use Log::Log4perl ':easy';
Log::Log4perl->easy_init($TRACE);

use t::helper;
if (! t::helper::firefox_instances) {
    plan skip_all => "Couldn't find Firefox instances to run tests with";
    exit
} else {
    plan tests => 2;
};

#my $exe = 'firefox-versions\\58.0.1\\firefoxPortable.exe';
my $exe = 'firefox-versions\\58.0.1\\App\\Firefox64\\firefox.exe';

my $ff = Firefox::Application->new(
    autodie => 0,
    launch_exe => $exe,
    profile => tempdir( CLEANUP => 1 ),
    headless => 1,
    private => 1,
    #log => [qw[debug]],
)->connect->get;

my $lives;
my @addons;

my $info = $ff->appinfo->get;
diag sprintf "Connected to %s version %s",
    $info->{browserName},
    $info->{browserVersion};

my $pid = $info->{'moz:processID'};

# This test is broken as we don't pass the expected version around anymore...
if (($exe) =~ /\b(\d+(\.\d+)+)\b/) {
    my $expected_version = $1;
    is $info->{browserVersion}, $expected_version, "We connect to an instance with version $expected_version";

    ok kill(0, $pid), "PID $pid is alive";
    warn kill(0, $pid);

    $ff->set_tab_content("<html>Hello World</html>")->get;
    sleep 10;

    $ff->quit->get;

    # This one fails on Windows 7 at least, even though the PID is gone...
    #ok !kill(0, $pid), "PID $pid is gone";

} else {
    SKIP: {
        skip "Don't know what version to expect", 2;
    };
};
