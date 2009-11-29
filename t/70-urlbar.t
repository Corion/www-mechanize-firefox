use strict;
use WWW::Mechanize::FireFox;
use Time::HiRes;
use Test::More;

my $mech = eval {WWW::Mechanize::Firefox->new()};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 2;
};

$mech->get_local('70-urlbar.html');

my @changed_locations;
sub onLocationChange {
    my ($progress,$request,$uri) = @_;
    my $url = $uri->{spec};
    diag "Location changed: $url\n";
    push @changed_locations, $url;
}

sub onStatusChange {
    diag "Status changed:  @_\n";
}

sub onProgressChange {
    diag "Progress changed:  @_\n";
}

my $browser = $mech->tab->{linkedBrowser};

my $eventlistener = $mech->progress_listener(
    $browser,
    onProgressChange => \&onProgressChange,
    onLocationChange => \&onLocationChange,
    onStatusChange => \&onStatusChange,
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