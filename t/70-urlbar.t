use strict;
use WWW::Mechanize::FireFox;
use Time::HiRes;
use Test::More;

my $mech = eval {WWW::Mechanize::FireFox->new()};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 2;
};

$mech->get_local('70-urlbar.html');

=begin JSDoc

      "onStateChange": handlers[
      function(aWebProgress, aRequest, aFlag, aStatus)
      {
       // If you use myListener for more than one tab/window, use
       // aWebProgress.DOMWindow to obtain the tab/window which triggers the state change
       if(aFlag & STATE_START)
       {
	 // This fires when the load event is initiated
        onLoadStart(aWebProgress,aRequest,aStatus);
       }
       if(aFlag & STATE_STOP)
       {
	 // This fires when the load finishes
        onLoadStop(aWebProgress,aRequest,aStatus);
       }
      },

      "onLocationChange": function(aProgress, aRequest, aURI)
      {
       // This fires when the location bar changes; i.e load event is confirmed
       // or when the user switches tabs. If you use myListener for more than one tab/window,
       // use aProgress.DOMWindow to obtain the tab/window which triggered the change.
      },

      // For definitions of the remaining functions see related documentation
      "onProgressChange": function(aWebProgress, aRequest, curSelf, maxSelf, curTot, maxTot) { },
      "onStatusChange": function(aWebProgress, aRequest, aStatus, aMessage) { },
      "onSecurityChange": function(aWebProgress, aRequest, aState) { },
    };
=cut

my @changed_locations;
sub onLocationChange {
    my ($progress,$request,$uri) = @_;
    my $url = $uri->{spec};
    diag "Location changed: $url\n";
    push @changed_locations, $url;
}

sub onStatusChange {
    #my ($progress,$request,$uri) = @_;
    
    #my ($progress,$request,$uri) = @_;
    #my $url = $uri->{spec};
    diag "Status changed:  @_\n";
    #push @changed_locations, $url;
}

sub onProgressChange {
    #my ($progress,$request,$uri) = @_;
    
    #my ($progress,$request,$uri) = @_;
    #my $url = $uri->{spec};
    diag "Progress changed:  @_\n";
    #push @changed_locations, $url;
}

#my $browser = $mech->repl->expr('window.getBrowser()');
#my $browser = $mech->document;
#my $browser = $mech->docshell;
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

undef $eventlistener;
undef $mech;