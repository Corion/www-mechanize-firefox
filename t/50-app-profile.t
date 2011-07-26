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
    plan tests => 9*@instances;
};

sub new_app {
    Firefox::Application->new(
        autodie => 0,
        #log => [qw[debug]],
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_app, sub {
    my ($firefox_instance, $ff) = @_;

    my $lives;
    my $profile;

    eval { $profile = $ff->current_profile; $lives++ };
    ok $lives, "We can query the current profile"
        or diag $@;

    ok $profile, "You have a valid profile"; # At least 'default'

    my $found_profile = $ff->find_profile($profile->{name});
    ok $found_profile, "We can (re)find the current profile";
    is $found_profile->{name}, $profile->{name}, "And we find the correct name";

    my $default_profile = $ff->find_profile('default'); # hopefully this always exists
    ok $default_profile, "You have a valid 'default' profile"; # At least 'default'
    is $default_profile->{name}, 'default';

    my @profiles = $ff->profiles;
    cmp_ok 0+@profiles, '>=', 1, "You have at least one profile"; # see above

    ok( 0+(grep {$_->{name} eq $profile->{name}} @profiles), "We find the current profile");
    ok( 0+(grep {$_->{name} eq $found_profile->{name}} @profiles), "We find the default profile");
});