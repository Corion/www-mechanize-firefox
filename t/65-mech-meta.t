#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

use t::helper;

# What instances of Firefox will we try?
my $instance_port = 4243;
my @instances = t::helper::firefox_instances();

my $err = t::helper::default_unavailable();
if ($err) {
    plan skip_all => "Couldn't connect to MozRepl: $err";
    exit
} else {
    plan tests => 3*@instances;
};

sub new_mech {
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        #log => [qw[debug]],
        @_,
    );
};

my @cleanup;
my $magic = "$0-shazam";
t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($instance, $mech) = @_;

    isa_ok $mech, 'WWW::Mechanize::Firefox';

    $mech->allow( metaredirects => 0 );
    $mech->get_local('65-mech-meta.html');
    sleep 1; # just in case
    is $mech->title, '65-mech-meta.html', 'We can prohibit META redirects';

    $mech->allow( metaredirects => 1 );
    $mech->get_local('65-mech-meta.html');
    sleep 1; # just in case
    is $mech->title, '49-mech-get-file.html', 'We can allow META redirects';
});