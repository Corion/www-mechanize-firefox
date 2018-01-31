#!perl -w
use strict;
use Test::More;
use File::Basename;

use Firefox::Application;
use lib '.';

use Log::Log4perl ':easy';
Log::Log4perl->easy_init($TRACE);

use t::helper;
if (! t::helper::firefox_instances) {
    plan skip_all => "Couldn't find Firefox instances to run tests with";
    exit
} else {
    plan tests => 3;
};

my $exe = 'firefox-versions\\58.0.1\\firefoxPortable.exe';

my $ff = Firefox::Application->new(
    autodie => 0,
    launch_exe => $exe,
    headless => 1,
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

    $ff->quit->get;

    ok !kill(0, $pid), "PID $pid is gone";

} else {
    SKIP: {
        skip "Don't know what version to expect", 3;
    };
};
