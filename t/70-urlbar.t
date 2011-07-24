use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Test::More;

use t::helper;

# What instances of Firefox will we try?
my $instance_port = 4243;
my @instances = t::helper::firefox_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 2*@instances;
};

sub new_mech {
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        #log => [qw[debug]],
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($instance, $mech) = @_;
    $mech->get_local('70-urlbar.html');

    my @changed_locations;

    my $browser = $mech->tab->{linkedBrowser};

    my $eventlistener = $mech->progress_listener(
        $browser,
        onLocationChange => sub {
            my ($progress,$request,$uri) = @_;
            my $url = $uri->{spec};
            diag "Location changed: $url\n";
            push @changed_locations, $url;
        },

        onStatusChange => sub {
            diag "Status changed:  @_\n";
        },

        onProgressChange => sub {
            #diag "Progress changed:  @_\n";
        }
    );

    my $countdown = 5;
    while ($countdown--) {
        $mech->repl->poll();
        sleep 1;
    };
    is scalar @changed_locations, 1, "We changed the location once";
    like $changed_locations[0], qr!/70-urlbar-2.html$!, "... to that other page";

    #undef $eventlistener;
    #undef $mech;
});