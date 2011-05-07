use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Test::More;
use File::Spec;
use Shell::Command qw(rm_rf);
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

my $mech = eval {WWW::Mechanize::Firefox->new(
    #log => ['debug'],
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

my $target = "$0.tmp";
my $target_dir = "$0.tmp_files";
END {
    if (-f $target) {
        unlink $target 
            or warn "Couldn't remove tempfile '$target': $!";
    };
    if (-d $target_dir) {
        rm_rf( $target_dir )
            or warn "Couldn't remove tempdir '$target_dir': $!";
    };
}

my $download = $mech->save_url($server->url => $target);
isa_ok $download, 'MozRepl::RemoteObject::Instance', 'Downloading ' . $server->url;

my $countdown = 30; # seconds until we decide that the server isn't answering
while ($countdown-- and $download->{currentState} != 3) {
    sleep 1;
};
is $download->{currentState}, 3, "Download finished properly";
unlink $target  or warn "Couldn't remove tempfile '$target': $!";

$mech->get($server->url);
$download = $mech->save_content($target,$target_dir);
isa_ok $download, 'MozRepl::RemoteObject::Instance', 'Downloading complete page of '.$server->url;

$countdown = 30; # seconds until we decide that the server isn't answering
while ($countdown-- and $download->{currentState} != 3) {
    sleep 1;
};
is $download->{currentState}, 3, "Download finished properly";

undef $download;

my $destroyed;
no warnings 'redefine';
*WWW::Mechanize::Firefox::DESTROY = sub {
    $destroyed++
};
undef $mech;
is $destroyed, 1, "Nothing keeps the instance alive";
