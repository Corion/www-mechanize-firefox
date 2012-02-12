#!perl -w
use strict;
use Test::More;
use File::Basename;

use Firefox::Application;

use t::helper;

# What instances of Firefox will we try?
my $instance_port = 4243;
my @instances = t::helper::firefox_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 8*@instances;
};

sub new_mech {
    Firefox::Application->new(
        autodie => 0,
        #log => [qw[debug]],
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($firefox_instance, $ff) = @_;
    
    my $lives;
    my @addons;

    diag sprintf "Connected to %s version %s",
        $ff->appinfo->{name},
        $ff->appinfo->{version};
    
    if (($firefox_instance||'') =~ /\b(\d+(\.\d+)+)\b/) {
        my $expected_version = $1;
        is $ff->appinfo->{version}, $expected_version, "We connect to an instance with version $expected_version";
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
    diag "Using MozRepl version $mozrepl->{version}";

    my @locales = $ff->locales;
    ok @locales >= 0, "We can ask for ->locales";
    diag $_->{name} for @locales;

    my @themes = $ff->themes;
    ok 1, "We can ask for ->themes";
    my ($standard_theme) = grep { $_->{id} eq '{972ce4c6-7e08-4474-a285-3208198ce6fd}' } @themes;
    isn't $standard_theme, undef, "We find the Standard theme";
    # is $standard_theme->{name}, 'Standard', 'The name is "Standard"';
    # This test fails, as the name is localized. Duh.
});