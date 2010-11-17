#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;

my $mech = WWW::Mechanize::Firefox->new(
    #log => ['debug'],
);
$mech->get('http://www.cpan.org');

my $mk_listener = $mech->repl->declare(<<'JS');
function (myListener,source) {
    myListener.source = source;
    const STATE_START = Components.interfaces.nsIWebProgressListener.STATE_START;
    const STATE_STOP = Components.interfaces.nsIWebProgressListener.STATE_STOP;
    var callbacks = ['onStateChange',
                   'onLocationChange',
                   "onProgressChange",
		   "onStatusChange",
		   "onSecurityChange",
                        ];
    for (var h in callbacks) {
        var e = callbacks[h];
        if (! myListener[e]) {
            myListener[e] = function(){}
        };
    };
    myListener.QueryInterface = function(aIID) {
	if (aIID.equals(Components.interfaces.nsIWebProgressListener) ||
	   aIID.equals(Components.interfaces.nsISupportsWeakReference) ||
	   aIID.equals(Components.interfaces.nsISupports))
	    return this;
	throw Components.results.NS_NOINTERFACE;
    };
    return myListener
}
JS

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

sub onStateChange {
    my ($progress,$request,$flag,$status) = @_;
    print "@_\n";
}

sub onLocationChange {
    my ($progress,$request,$uri) = @_;
    print "Location :", $uri->{spec},"\n";
}

my $NOTIFY_STATE_DOCUMENT = $mech->repl->expr('Components.interfaces.nsIWebProgress.NOTIFY_STATE_DOCUMENT');
sub event_listener {
    my ($source,%handlers) = @_;
    my ($obj) = $mech->repl->expr('new Object');
    for my $key (keys %handlers) {
        $obj->{$key} = $handlers{$key};
    };
    my $lsn = $mk_listener->($obj,$source);
    $lsn->__release_action('self.source.removeEventListener(self)');
    $source->addProgressListener($lsn,$NOTIFY_STATE_DOCUMENT);
    $lsn;
};

my $browser = $mech->repl->expr('window.getBrowser()');

my $eventlistener = event_listener(
    $browser,
    onLocationChange => \&onLocationChange,
);

while (1) {
    $mech->repl->poll();
    sleep 1;
};
