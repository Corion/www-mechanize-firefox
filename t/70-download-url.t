use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Test::More;
use File::Spec;
use Shell::Command qw(rm_rf);

my $mech = eval {WWW::Mechanize::Firefox->new(
    #log => ['debug'],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 4;
};

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

my $download = $mech->save_url('http://google.de' => $target);
isa_ok $download, 'MozRepl::RemoteObject::Instance', 'Downloading google.de';

my $countdown = 30; # seconds until we decide that Google isn't answering
while ($countdown-- and $download->{currentState} != 3) {
    sleep 1;
};
is $download->{currentState}, 3, "Download finished properly";
unlink $target  or warn "Couldn't remove tempfile '$target': $!";

$mech->get('http://google.de');
$download = $mech->save_content($target,$target_dir);
isa_ok $download, 'MozRepl::RemoteObject::Instance', 'Downloading complete page of google.de';

$countdown = 30; # seconds until we decide that Google isn't answering
while ($countdown-- and $download->{currentState} != 3) {
    sleep 1;
};
is $download->{currentState}, 3, "Download finished properly";
