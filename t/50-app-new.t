#!perl -w
use strict;
use Test::More;
use File::Basename;

use Firefox::Application;

# What instances of Firefox will we try?
my $instance_port = 4243;
my @instances;
push @instances, undef; # default Firefox instance
if (-d 'firefox-versions') { # author test with local instances
    push @instances, sort glob 'firefox-versions/*/FirefoxPortable.exe'; # sorry, Windows-only
};

# Connect to default instance
my $ff = eval { Firefox::Application->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $ff) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 8*@instances;
};
undef $ff;

for my $firefox_instance (@instances) {
    my $name = $firefox_instance || 'default Firefox';
    if ($firefox_instance) {
        diag "Testing with $firefox_instance";
    };
    
    my @launch = $firefox_instance
               ? ( launch => [$firefox_instance, '-repl', $instance_port],
                   repl => "localhost:$instance_port" )
               : ();
    
    $ff = Firefox::Application->new(
        autodie => 0,
        @launch,
    );

    my $lives;
    my @addons;

    diag sprintf "Connected to %s version %s",
        $ff->appinfo->{name},
        $ff->appinfo->{version};
    
    if (($firefox_instance||'') =~ /\b(\d+\.\d+\.\d+)\b/) {
        my $expected_version = $1;
        is $ff->appinfo->{version}, $expected_version, "We connect to the right instance";
    } else {
        SKIP: {
            skip "Don't know what version to expect", 1;
        };
    };

    eval { @addons = $ff->addons; $lives++ };
    ok $lives, "We can query the addons"
        or diag $@;

    diag "Found " . scalar @addons . " addons";
    ok @addons >= 1, "You have at least one addon"; # The mozrepl addon, duh

    my ($mozrepl) = grep { $_->{id} eq 'mozrepl@hyperstruct.net' } @addons;
    isn't $mozrepl, undef, "We find the mozrepl addon";
    is $mozrepl->{name}, 'MozRepl', 'The name is "MozRepl"';

    my @locales = $ff->locales;
    ok @locales >= 0, "We can ask for ->locales";
    diag $_->{name} for @locales;

    my @themes = $ff->themes;
    ok 1, "We can ask for ->themes";
    my ($standard_theme) = grep { $_->{id} eq '{972ce4c6-7e08-4474-a285-3208198ce6fd}' } @themes;
    isn't $standard_theme, undef, "We find the Standard theme";
    # is $standard_theme->{name}, 'Standard', 'The name is "Standard"';
    # This test fails, as the name is localized. Duh.
    
    if ($firefox_instance) {
        $ff->quit;
        sleep 3; # justin case
    };
};