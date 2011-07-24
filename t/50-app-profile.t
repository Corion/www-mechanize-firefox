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
    plan tests => 9*@instances;
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
        #log => [qw[debug]],
        @launch,
    );

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
    
    if ($firefox_instance) {
        $ff->quit;
        sleep 1; # justin case
    };
};