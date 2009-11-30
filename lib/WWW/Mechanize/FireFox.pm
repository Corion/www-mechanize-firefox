package WWW::Mechanize::Firefox;
use strict;
use Time::HiRes;

use MozRepl::RemoteObject;
use URI;
use Cwd;
use File::Basename;
use HTTP::Response;
use HTML::Selector::XPath 'selector_to_xpath';
use MIME::Base64;
use WWW::Mechanize::Link;
use HTTP::Cookies::MozRepl;
use Scalar::Util qw'blessed weaken';
use Encode qw(encode);
use Carp qw(carp croak);
use Scalar::Util qw(blessed);

use vars qw'$VERSION %link_spec';
$VERSION = '0.12';

=head1 NAME

WWW::Mechanize::Firefox - use Firefox as if it were WWW::Mechanize

=head1 SYNOPSIS

  use WWW::Mechanize::Firefox;
  my $mech = WWW::Mechanize::Firefox->new();
  $mech->get('http://google.com');

  $mech->eval_in_page('alert("Hello Firefox")');
  my $png = $mech->content_as_png();

This will let you automate Firefox through the
Mozrepl plugin, which you need to have installed
in your Firefox.

=head1 METHODS

=cut

sub execute {
    my ($package,$repl,$js) = @_;
    if (2 == @_) {
        $js = $repl;
        $repl = $package->repl;
    };
    $repl->execute($js)
}

=head2 C<< $mech->new( ARGS ) >>

Creates a new instance and connects it to Firefox.

Note that Firefox already must be running and must have the C<mozrepl>
extension installed.

The following options are recognized:

=over 4

=item * 

C<tab> - regex for the title of the tab to reuse. If no matching tab is
found, the constructor dies.

=item * 

C<log> - array reference to log levels, passed through to L<MozRepl::RemoteObject>

=item * 

C<events> - the set of default Javascript events to listen for while
waiting for a reply

=item * 

C<repl> - a premade L<MozRepl::RemoteObject> instance

=item * 

C<pre_events> - the events that are sent to an input field before its
value is changed. By default this is C<[focus]>.

=item * 

C<post_events> - the events that are sent to an input field after its
value is changed. By default this is C<[blur, change]>.

=back

=cut

sub new {
    my ($class, %args) = @_;
    my $loglevel = delete $args{ log } || [qw[ error ]];
    if (! $args{ repl }) {
        $args{ repl } = MozRepl::RemoteObject->install_bridge(log => $loglevel);
    };
    
    if (my $tabname = delete $args{ tab }) {
        if (! ref $tabname) {
            $tabname = qr/\Q$tabname/;
        };
        ($args{ tab }) = grep { $_->{title} =~ /$tabname/ } $class->openTabs($args{ repl });
        if (! $args{ tab }) {
            die "Couldn't find a tab matching /$tabname/";
        }
        $args{ tab } = $args{ tab }->{tab};
    } else {
        my @autoclose = exists $args{ autoclose } ? (autoclose => $args{ autoclose }) : ();
        $args{ tab } = $class->addTab( repl => $args{ repl }, @autoclose );
        my $body = $args{ tab }->__dive(qw[ linkedBrowser contentWindow document body ]);
        $body->{innerHTML} = __PACKAGE__;
    }

    $args{ events } ||= [qw[DOMFrameContentLoaded DOMContentLoaded error abort stop]];
    $args{ pre_value } ||= ['focus'];
    $args{ post_value } ||= ['change','blur'];

    die "No tab found"
        unless $args{tab};
        
    $args{ response } ||= undef;
    $args{ current_form } ||= undef;
        
    bless \%args, $class;
};

sub DESTROY {
    my ($self) = @_;
    #warn "Cleaning up mech";
    local $@;
    my $repl = delete $self->{ repl };
    if ($repl) {
        undef $self->{tab};
        %$self = (); # wipe out all references we keep
        # but keep $repl alive until we can dispose of it
        # as the last thing, now:
        $repl = undef;
    };
}

=head1 JAVASCRIPT METHODS

=head2 C<< $mech->allow OPTIONS >>

Enables or disables browser features for the current tab.
The following options are recognized:

=over 4

=item * 

C<plugins> 	 - Whether to allow plugin execution.

=item * 

C<javascript> 	 - Whether to allow Javascript execution.

=item * 

C<metaredirects> - Attribute stating if refresh based redirects can be allowed.

=item * 

C<frames>, C<subframes> 	 - Attribute stating if it should allow subframes (framesets/iframes) or not.

=item * 

C<images> 	 - Attribute stating whether or not images should be loaded.

=back

Options not listed remain unchanged.

=head3 Disable Javascript

  $mech->allow( javascript => 0 );

=cut

use vars '%known_options';
%known_options = (
    'javascript'    => 'allowJavascript',
    'plugins'       => 'allowPlugins',
    'metaredirects' => 'allowMetaRedirects',
    'subframes'     => 'allowSubframes',
    'frames'        => 'allowSubframes',
    'images'        => 'allowImages',
);

sub allow  {
    my ($self,%options) = @_;
    my $shell = $self->docshell;
    for my $opt (sort keys %options) {
        if (my $opt_js = $known_options{ $opt }) {
            $shell->{$opt_js} = $options{ $opt };
        } else {
            carp "Unknown option '$opt_js' (ignored)";
        };
    };
};

=head2 C<< $mech->js_errors [PAGE] >>

An interface to the Javascript Error Console

Returns the list of errors in the JEC

=head3 Check that your Page has no Javascript compile errors

  $mech->get('mypage');
  my @errors = $mech->js_errors();
  if (@errors) {
      die "Found errors on page: @errors";
  };

Maybbe this should be called C<js_messages> or
C<js_console_messages> instead.

=cut

sub js_console {
    my ($self) = @_;
    my $getConsoleService = $self->repl->declare(<<'JS');
    function() {
        return  Components.classes["@mozilla.org/consoleservice;1"]
                .getService(Ci.nsIConsoleService);
    }
JS
    $getConsoleService->()
}

sub js_errors {
    my ($self,$page) = @_;
    my $console = $self->js_console;
    my $getErrorMessages = $self->repl->declare(<<'JS');
    function (consoleService) {
        var out = {};
        consoleService.getMessageArray(out, {});
        return out.value || []
    };
JS
    my $m = $getErrorMessages->($console);
    @$m
}

=head2 C<< $mech->clear_js_errors >>

Clears all Javascript messages from the console

=cut

sub clear_js_errors {
    my ($self,$page) = @_;
    $self->js_console->reset;

};

=head2 C<< $mech->eval_in_page STR [, ENV] >>

Evaluates the given Javascript fragment in the
context of the web page.
Returns a pair of value and Javascript type.

This allows access to variables and functions declared
"globally" on the web page.

The returned result needs to be treated with 
extreme care because
it might lead to Javascript execution in the context of
your application instead of the context of the webpage.
This should be evident for functions and complex data
structures like objects. When working with results from
untrusted sources, you can only safely use simple
types like C<string>.

If you want to modify the environment the code is run under,
pass in a hash reference as the second parameter. All keys
will be inserted into the C<this> object as well as
C<this.window>. Also, complex data structures are only
supported if they contain no objects.
If you need finer control, you'll have to
write the Javascript yourself.

This method is special to WWW::Mechanize::Firefox.

Also, using this method opens a potential B<security risk> as
the returned values can be objects and using these objects
can execute malicious code in the context of the Firefox application.

=head3 Override the Javascript C<alert()> function

  $mech->eval_in_page('alert("Hello");',
      { alert => sub { print "Captured alert: '@_'\n" } }
  );

=cut

sub eval_in_page {
    my ($self,$str,$env) = @_;
    $env ||= {};
    my $js_env = {};
    
    # do a manual transfer of keys, to circumvent our stupid
    # transformation routine:
    if (keys %$env) {
        $js_env = $self->repl->declare(<<'JS')->();
            function () { return new Object }
JS
        for my $k (keys %$env) {
            $js_env->{$k} = $env->{$k};
        };
    };
    
    my $eval_in_sandbox = $self->repl->declare(<<'JS');
    function (w,d,str,env) {
        var unsafeWin = w.wrappedJSObject;
        var safeWin = XPCNativeWrapper(unsafeWin);
        var sandbox = Components.utils.Sandbox(safeWin);
        sandbox.window = safeWin;
        sandbox.document = sandbox.window.document;
        // Transfer the environment
        for (var e in env) {
            sandbox[e] = env[e]
            sandbox.window[e] = env[e]
        }
        sandbox.__proto__ = unsafeWin;
        var res = Components.utils.evalInSandbox(str, sandbox);
        return [res,typeof(res)];
    };
JS
    my $window = $self->tab->{linkedBrowser}->{contentWindow};
    my $d = $self->document;
    return @{ $eval_in_sandbox->($window,$d,$str,$js_env) };
};

=head2 C<< $mech->unsafe_page_property_access ELEMENT >>

Allows you unsafe access to properties of the current page. Using
such properties is an incredibly bad idea.

This is why the function C<die>s. If you really want to use
this function, edit the source code.

=cut

sub unsafe_page_property_access {
    my ($mech,$element) = @_;
    die;
    my $window = $mech->tab->{linkedBrowser}->{contentWindow};
    my $unsafe = $window->{wrappedJSObject};
    $unsafe->{$element}
};

=head1 UI METHODS

=head2 C<< $mech->addTab( OPTIONS ) >>

Creates a new tab. The tab will be automatically closed upon program exit.

If you want the tab to remain open, pass a false value to the the C< autoclose >
option.

=cut

sub addTab {
    my ($self, %options) = @_;
    my $repl = $options{ repl } || $self->repl;
    my $rn = $repl->name;

    my $tab = $repl->declare(<<'JS')->();
    function (){
        var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                           .getService(Components.interfaces.nsIWindowMediator);
        var win = wm.getMostRecentWindow('navigator:browser');
        if (! win) {
          // No browser windows are open, so open a new one.
          win = window.open('about:blank');
        };
        return win.getBrowser().addTab()
    }
JS
    if (not exists $options{ autoclose } or $options{ autoclose }) {
        #warn "Installing autoclose";
        my $release = join "",
        q{var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]},
        q{                   .getService(Components.interfaces.nsIWindowMediator);},
        q{var win = wm.getMostRecentWindow('navigator:browser');},
        q{if (!win){win = window};},
        q{win.getBrowser().removeTab(self)},
        ;
        #warn $release;
        $tab->__release_action($release);
    };
    
    $tab
};

# This should maybe become MozRepl::Firefox::Util?
# or MozRepl::Firefox::UI ?
sub openTabs {
    my ($self,$repl) = @_;
    $repl ||= $self->repl;
    my $open_tabs = $repl->declare(<<'JS');
function() {
    var idx = 0;
    var tabs = [];
    
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                       .getService(Components.interfaces.nsIWindowMediator);
    var win = wm.getMostRecentWindow('navigator:browser');
    if (win) {
        var browser = win.getBrowser();
        Array.prototype.forEach.call(
            browser.tabContainer.childNodes, 
            function(tab) {
                var d = tab.linkedBrowser.contentWindow.document;
                tabs.push({
                    location: d.location.href,
                    document: d,
                    title:    d.title,
                    "id":     d.id,
                    index:    idx++,
                    panel:    tab.linkedPanel,
                    tab:      tab,
                });
            });
    };

    return tabs;
}
JS
    my $tabs = $open_tabs->();
    return @$tabs
}

=head2 C<< $mech->tab >>

Gets the object that represents the Firefox tab used by WWW::Mechanize::Firefox.

This method is special to WWW::Mechanize::Firefox.

=cut

sub tab { $_[0]->{tab} };

=head2 C<< $mech->progress_listener SOURCE, CALLBACKS >>

Sets up the callbacks for the C<< nsIWebProgressListener >> interface
to be the Perl subroutines you pass in.

Returns a handle. Once the handle gets released, all callbacks will
get stopped. Also, all Perl callbacks will get deregistered from the
Javascript bridge, so make sure not to use the same callback
in different progress listeners at the same time.

=head3 Get notified when the current tab changes

    my $browser = $mech->repl->expr('window.getBrowser()');

    my $eventlistener = progress_listener(
        $browser,
        onLocationChange => \&onLocationChange,
    );

    while (1) {
        $mech->repl->poll();
        sleep 1;
    };

=cut

sub progress_listener {
    my ($mech,$source,%handlers) = @_;
    my $NOTIFY_STATE_DOCUMENT = $mech->repl->expr('Components.interfaces.nsIWebProgress.NOTIFY_STATE_DOCUMENT');
    my ($obj) = $mech->repl->expr('new Object');
    for my $key (keys %handlers) {
        $obj->{$key} = $handlers{$key};
    };
    
    my $mk_nsIWebProgressListener = $mech->repl->declare(<<'JS');
    function (myListener,source) {
        myListener.source = source;
        //const STATE_START = Components.interfaces.nsIWebProgressListener.STATE_START;
        //const STATE_STOP = Components.interfaces.nsIWebProgressListener.STATE_STOP;
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
    
    my $lsn = $mk_nsIWebProgressListener->($obj,$source);
    $lsn->__release_action('self.source.removeProgressListener(self)');
    $lsn->__on_destroy(sub {
        # Clean up some memory leaks
        $_[0]->bridge->remove_callback(values %handlers);
    });
    $source->addProgressListener($lsn,$NOTIFY_STATE_DOCUMENT);
    $lsn
};

=head2 C<< $mech->repl >>

Gets the L<MozRepl::RemoteObject> instance that is used.

This method is special to WWW::Mechanize::Firefox.

=cut

sub repl { $_[0]->{repl} };

=head2 C<< $mech->events >>

Sets or gets the set of Javascript events that WWW::Mechanize::Firefox
will wait for after requesting a new page. Returns an array reference.

This method is special to WWW::Mechanize::Firefox.

=cut

sub events { $_[0]->{events} = $_[1] if (@_ > 1); $_[0]->{events} };

=head2 C<< $mech->cookies >>

Returns a L<HTTP::Cookies> object that was initialized
from the live Firefox instance.

B<Note:> C<< ->set_cookie >> is not yet implemented,
as is saving the cookie jar.

=cut

sub cookies {
    return HTTP::Cookies::MozRepl->new(
        repl => $_[0]->repl
    )
}

=head2 C<< $mech->highlight_node NODES >>

Convenience method that marks all nodes in the arguments
with

  background: red;
  border: solid black 1px;
  display: block; /* if the element was display: none before */

This is convenient if you need visual verification that you've
got the right nodes.

There currently is no way to restore the nodes to their original
visual state except reloading the page.

=cut

sub highlight_node {
    my ($self,@nodes) = @_;
    for (@nodes) {
        my $style = $_->{style};
        $style->{display}    = 'block'
            if $style->{display} eq 'none';
        $style->{background} = 'red';
        $style->{border}     = 'solid black 1px;';
    };
};

=head1 NAVIGATION METHODS

=head2 C<< $mech->get(URL) >>

Retrieves the URL C<URL> into the tab.

It returns a faked L<HTTP::Response> object for interface compatibility
with L<WWW::Mechanize>. It does not yet support the additional parameters
that L<WWW::Mechanize> supports for saving a file etc.

=cut

sub get {
    my ($self,$url) = @_;
    my $b = $self->tab->{linkedBrowser};

    $self->synchronize($self->events, sub {
        $b->loadURI($url);
    });
};

=head2 C<< $mech->get_local $filename >>

Shorthand method to construct the appropriate
C<< file:// >> URI and load it into Firefox.

This method is special to WWW::Mechanize::Firefox but could
also exist in WWW::Mechanize through a plugin.

=cut

sub get_local {
    my ($self, $htmlfile) = @_;
    my $fn = File::Spec->rel2abs(
                 File::Spec->catfile(dirname($0),$htmlfile),
                 getcwd,
             );
    $fn =~ s!\\!/!g; # fakey "make file:// URL"

    $self->get("file://$fn")
}

# Should I port this to Perl?
# Should this become part of MozRepl::RemoteObject?
sub _addEventListener {
    my ($self,$browser,$events) = @_;
    $events ||= $self->events;
    $events = [$events]
        unless ref $events;

# This registers multiple events for a one-shot event
    my $make_semaphore = $self->repl->declare(<<'JS');
function(browser,events) {
    var lock = {};
    lock.busy = 0;
    var b = browser;
    var listeners = [];
    for( var i = 0; i < events.length; i++) {
        var evname = events[i];
        var callback = (function(listeners,evname){
            return function(e) {
                lock.busy++;
                lock.event = evname;
                lock.js_event = {};
                lock.js_event.target = e.originalTarget;
                lock.js_event.type = e.type;
                for( var j = 0; j < listeners.length; j++) {
                    b.removeEventListener(listeners[j][0],listeners[j][1],true);
                };
            };
        })(listeners,evname);
        listeners.push([evname,callback]);
        b.addEventListener(evname,callback,true);
    };
    return lock
}
JS
    return $make_semaphore->($browser,$events);
};

sub _wait_while_busy {
    my ($self,@elements) = @_;
    # Now do the busy-wait
    while (1) {
        for my $element (@elements) {
            if ((my $s = $element->{busy} || 0) >= 1) {
                return $element;
            };
        };
        sleep 0.1;
    };
}

=head2 C<< $mech->synchronize( $event, $callback ) >>

Wraps a synchronization semaphore around the callback
and waits until the event C<$event> fires on the browser.
If you want to wait for one of multiple events to occur,
pass an array reference as the first parameter.

Usually, you want to use it like this:

  my $l = $mech->xpath('//a[@onclick]', single => 1);
  $mech->synchronize('DOMFrameContentLoaded', sub {
      $l->__click()
  });

It is necessary to synchronize with the browser whenever
a click performs an action that takes longer and
fires an event on the browser object.

The C<DOMFrameContentLoaded> event is fired by Firefox when
the whole DOM and all C<iframe>s have been loaded.
If your document doesn't have frames, use the C<DOMContentLoaded>
event instead.

If you leave out C<$event>, the value of C<< ->events() >> will
be used instead.

=cut

sub _install_response_header_listener {
    my ($self) = @_;
    
    weaken $self;
    
    # These should be cached and optimized into one hash query
    my $STATE_STOP = $self->repl->expr('Components.interfaces.nsIWebProgressListener.STATE_STOP');
    my $STATE_IS_DOCUMENT = $self->repl->expr('Components.interfaces.nsIWebProgressListener.STATE_IS_DOCUMENT');
    my $STATE_IS_WINDOW = $self->repl->expr('Components.interfaces.nsIWebProgressListener.STATE_IS_WINDOW');
    my $nsIHttpChannel = $self->repl->expr('Components.interfaces.nsIHttpChannel');

    my $state_change = sub {
        my ($progress,$request,$flags,$status) = @_;
        #printf "State     : <progress> <request> %08x %08x\n", $flags, $status;
        #printf "                                 %08x\n", $STATE_STOP;
        
        if (($flags & ($STATE_STOP | $STATE_IS_DOCUMENT)) == ($STATE_STOP | $STATE_IS_DOCUMENT)) {
            if ($status == 0) {
                $self->{ response } = $request;
            } else {
                undef $self->{ response };
            };
            #if ($status) {
            #    warn sprintf "%08x", $status;
            #};
        };
    };
    my $status_change = sub {
        my ($progress,$request,$status,$msg) = @_;
        #printf "Status     : <progress> <request> %08x %s\n", $status, $msg;
        #printf "                                 %08x\n", $STATE_STOP;
    };

    my $browser = $self->tab->{linkedBrowser};

    # These should mimick the LWP::UserAgent events maybe?
    return $self->progress_listener(
        $browser,
        onStateChange => $state_change,
        #onProgressChange => sub { print  "Progress  : @_\n" },
        #onLocationChange => sub { printf "Location  : %s\n", $_[2]->{spec} },
        #onStatusChange   => sub { print  "Status    : @_\n"; },
    );
};

sub synchronize {
    my ($self,$events,$callback) = @_;
    if (ref $events and ref $events eq 'CODE') {
        $callback = $events;
        $events = $self->events;
    };
    
    $events = [ $events ]
        unless ref $events;
    
    undef $self->{response};
    
    my $need_response = defined wantarray;
    my $response_catcher;
    if ($need_response) {
        $response_catcher = $self->_install_response_header_listener();
    };
    
    # 'load' on linkedBrowser is good for successfull load
    # 'error' on tab is good for failed load :-(
    my $b = $self->tab->{linkedBrowser};
    my $load_lock = $self->_addEventListener($b,$events);
    $callback->();
    $self->_wait_while_busy($load_lock);
    
    if ($need_response) {
        return $self->response
    };
};

=head2 C<< $mech->res >> / C<< $mech->response >>

Returns the current response as a L<HTTP::Response> object.

=cut

sub _headerVisitor {
    my ($self,$cb) = @_;
    my $obj = $self->repl->expr('new Object');
    $obj->{visitHeader} = $cb;
    $obj
};

sub _extract_response {
    my ($self,$request) = @_;
    
    my $nsIChannel = $self->repl->expr('Components.interfaces.nsIChannel');
    warn "Before status";
    if (my $status = $request->{responseStatus}) {
        warn $status;
        my @headers;
        my $v = $self->_headerVisitor(sub{push @headers, @_});
        $request->visitResponseHeaders($v);
        my $res = HTTP::Response->new(
            $request->{responseStatus},
            $request->{responseStatusText},
            \@headers,
            undef, # no body so far
        );
        return $res;
    };
};

sub response {
    my ($self) = @_;
    
    # If we still have a valid JS response,
    # create a HTTP::Response from that
    if (my $js_res = $self->{ response }) {
        my $ouri = $js_res->{originalURI};
        my $scheme;
        if ($ouri) {
            $scheme = $ouri->{scheme};
        };
        if ($scheme and $scheme =~ /^https?/) {
            return $self->_extract_response( $js_res );
        } else {
            # make up a response, below
        };
    };
    
    # Otherwise, make up a reason:
    my $eff_url = $self->document->{documentURI};
    #warn $eff_url;
    if ($eff_url =~ /^about:neterror/) {
        # this is an error
        return HTTP::Response->new(500)
    };   

    # We're cool!
    my $c = $self->content;
    return HTTP::Response->new(200,'',[],encode 'UTF-8', $c)
}
*res = \&response;

=head2 C<< $mech->success >>

Returns a boolean telling whether the last request was successful.
If there hasn't been an operation yet, returns false.

This is a convenience function that wraps C<< $mech->res->is_success >>.

=cut

sub success {
    my $res = $_[0]->response;
    $res and $res->is_success
}

=head2 C<< $mech->status >>

Returns the HTTP status code of the response.
This is a 3-digit number like 200 for OK, 404 for not found, and so on.

=cut

sub status {
    $_[0]->response->code
};

=head2 C<< $mech->reload BYPASS_CACHE >>

Reloads the current page. If C<BYPASS_CACHE>
is a true value, the browser is not allowed to
use a cached page. This is the difference between
pressing C<F5> (cached) and C<shift-F5> (uncached).

Returns the (new) response.

=cut

sub reload {
    my ($self, $bypass_cache) = @_;
    $bypass_cache ||= 0;
    if ($bypass_cache) {
        $bypass_cache = $self->repl->expr('nsIWebNavigation.LOAD_FLAGS_BYPASS_CACHE');
    };
    $self->synchronize( sub {
        $self->tab->{linkedBrowser}->reloadWithFlags($bypass_cache);
    });
}

=head2 C<< $mech->back >>

Goes one page back in the page history.

Returns the (new) response.

=cut

sub back {
    my ($self) = @_;
    $self->synchronize( sub {
        $self->tab->{linkedBrowser}->goBack;
    });
}

=head2 C<< $mech->forward >>

Goes one page back in the page history.

Returns the (new) response.

=cut

sub forward {
    my ($self) = @_;
    $self->synchronize( sub {
        $self->tab->{linkedBrowser}->goForward;
    });
}

=head2 C<< $mech->uri >>

Returns the current document URI.

=cut

sub uri {
    my ($self) = @_;
    my $loc = $self->tab->__dive(qw[
        linkedBrowser
        currentURI
        asciiSpec ]);
    return URI->new( $loc );
};

=head1 CONTENT METHODS

=head2 C<< $mech->document >>

Returns the DOM document object.

This is WWW::Mechanize::Firefox specific.

=cut

sub document {
    my ($self) = @_;
    $self->tab->__dive(qw[linkedBrowser contentWindow document]);
}

=head2 C<< $mech->docshell >>

Returns the C<docShell> Javascript object.

This is WWW::Mechanize::Firefox specific.

=cut

sub docshell {
    my ($self) = @_;
    $self->tab->__dive(qw[linkedBrowser docShell]);
}

=head2 C<< $mech->content >>

Returns the current content of the tab as a scalar.

This is likely not binary-safe.

It also currently only works for HTML pages.

=cut

sub content {
    my ($self) = @_;
    
    my $rn = $self->repl->repl;
    my $d = $self->document; # keep a reference to it!
    
    my $html = $self->repl->declare(<<'JS');
function(d){
    var e = d.createElement("div");
    e.appendChild(d.documentElement.cloneNode(true));
    return e.innerHTML;
}
JS
    $html->($d);
};

=head2 C<< $mech->update_html $html >>

Writes C<$html> into the current document. This is mostly
implemented as a convenience method for L<HTML::Display::MozRepl>.

=cut

sub update_html {
    my ($self,$content) = @_;
    my $data = encode_base64($content,'');
    my $url = qq{data:text/html;base64,$data};
    $self->synchronize($self->events, sub {
        $self->tab->{linkedBrowser}->loadURI($url);
    });
};

=head2 C<< $mech->save_content $localname [, $resource_directory] [, %OPTIONS ] >>

Saves the given URL to the given filename. The URL will be
fetched from the cache if possible, avoiding unnecessary network
traffic.

If C<$resource_directory> is given, the whole page will be saved.
All CSS, subframes and images
will be saved into that directory, while the page HTML itself will
still be saved in the file pointed to by C<$localname>.

Returns a C<<nsIWebBrowserPersist>> object through which you can cancel the
download by calling its C<< ->cancelSave >> method. Also, you can poll
the download status through the C<< ->{currentState} >> property.

If you are interested in the intermediate download progress, create
a ProgressListener through C<< $mech->progress_listener >>
and pass it in the C<progress> option.

The download will
continue in the background. It will not show up in the
Download Manager.

=cut

sub save_content {
    my ($self,$localname,$resource_directory,%options) = @_;
    
    $localname = File::Spec->rel2abs($localname, '.');    
    # Touch the file
    if (! -f $localname) {
    	open my $fh, '>', $localname
    	    or die "Couldn't create '$localname': $!";
    };

    if ($resource_directory) {
        $resource_directory = File::Spec->rel2abs($resource_directory, '.');

        # Create the directory
        if (! -d $resource_directory) {
            mkdir $resource_directory
                or die "Couldn't create '$resource_directory': $!";
        };
    };
    
    my $transfer_file = $self->repl->declare(<<'JS');
function (document,filetarget,rscdir,progress) {
    //new file object
    var obj_target;
    if (filetarget) {
        obj_target = Components.classes["@mozilla.org/file/local;1"]
        .createInstance(Components.interfaces.nsILocalFile);
    };

    //set file with path
    obj_target.initWithPath(filetarget);

    var obj_rscdir;
    if (rscdir) {
        obj_rscdir = Components.classes["@mozilla.org/file/local;1"]
        .createInstance(Components.interfaces.nsILocalFile);
        obj_rscdir.initWithPath(rscdir);
    };

    var obj_Persist = Components.classes["@mozilla.org/embedding/browser/nsWebBrowserPersist;1"]
        .createInstance(Components.interfaces.nsIWebBrowserPersist);

    // with persist flags if desired
    const nsIWBP = Components.interfaces.nsIWebBrowserPersist;
    const flags = nsIWBP.PERSIST_FLAGS_REPLACE_EXISTING_FILES;
    obj_Persist.persistFlags = flags | nsIWBP.PERSIST_FLAGS_FROM_CACHE;
    
    obj_Persist.progressListener = progress;

    //save file to target
    obj_Persist.saveDocument(document,obj_target, obj_rscdir, null,0,0);
    return obj_Persist
};
JS
    #warn "=> $localname / $resource_directory";
    $transfer_file->(
        $self->document,
        $localname,
        $resource_directory,
        $options{progress}
    );
}

=head2 C<< $mech->save_url $url, $localname, [%OPTIONS] >>

Saves the given URL to the given filename. The URL will be
fetched from the cache if possible, avoiding unnecessary network
traffic.

Returns a C<<nsIWebBrowserPersist>> object through which you can cancel the
download by calling its C<< ->cancelSave >> method. Also, you can poll
the download status through the C<< ->{currentState} >> property.

If you are interested in the intermediate download progress, create
a ProgressListener through C<< $mech->progress_listener >>
and pass it in the C<progress> option.

The download will
continue in the background. It will also not show up in the
Download Manager.

=head3 Upload a file to an C<ftp> server

You can use C<< ->save_url >> to I<transfer> files. C<$localname>
can be a local filename, a C<file://> URL or any other URL that allows
uploads, like C<ftp://>.

  $mech->save_url('file://path/to/my/file.txt'
      => 'ftp://myserver.example/my/file.txt');

B< Not implemented > - this requires instantiating and passing
a C< nsIURI > object instead of a C< nsILocalFile >.

=cut

sub save_url {
    my ($self,$url,$localname,%options) = @_;
    
    $localname = File::Spec->rel2abs($localname, '.');
    
    if (! -f $localname) {
    	open my $fh, '>', $localname
    	    or die "Couldn't create '$localname': $!";
    };
    
    my $transfer_file = $self->repl->declare(<<'JS');
function (source,filetarget,progress) {
    //new obj_URI object
    var obj_URI = Components.classes["@mozilla.org/network/io-service;1"]
        .getService(Components.interfaces.nsIIOService).newURI(source, null, null);

    //new file object
    var obj_target;
    if (filetarget) {
        obj_target = Components.classes["@mozilla.org/file/local;1"]
        .createInstance(Components.interfaces.nsILocalFile);
    };

    //set file with path
    obj_target.initWithPath(filetarget);

    //new persitence object
    var obj_Persist = Components.classes["@mozilla.org/embedding/browser/nsWebBrowserPersist;1"]
        .createInstance(Components.interfaces.nsIWebBrowserPersist);

    // with persist flags if desired
    const nsIWBP = Components.interfaces.nsIWebBrowserPersist;
    const flags = nsIWBP.PERSIST_FLAGS_REPLACE_EXISTING_FILES;
    obj_Persist.persistFlags = flags | nsIWBP.PERSIST_FLAGS_FROM_CACHE;
    
    obj_Persist.progressListener = progress;

    //save file to target
    obj_Persist.saveURI(obj_URI,null,null,null,null,obj_target);
    return obj_Persist
};
JS
    $transfer_file->("$url" => $localname, $options{progress});
}

=head2 C<< $mech->base >>

Returns the URL base for the current page.

The base is either specified through a C<base>
tag or is the current URL.

This method is specific to WWW::Mechanize::Firefox

=cut

sub base {
    my ($self) = @_;
    (my $base) = $self->selector('base');
    $base = $base->{href}
        if $base;
    $base ||= $self->uri;
};

=head2 C<< $mech->content_type >>

Returns the content type of the currently loaded document

=cut

sub content_type {
    my ($self) = @_;
    return $self->document->{contentType};
};

*ct = \&content_type;

=head2 C<< $mech->is_html() >>

Returns true/false on whether our content is HTML, according to the
HTTP headers.

=cut

sub is_html {       
    my $self = shift;
    return defined $self->ct && ($self->ct eq 'text/html');
}

=head2 C<< $mech->title >>

Returns the current document title.

=cut

sub title {
    my ($self) = @_;
    return $self->document->{title};
};

=head1 EXTRACTION METHODS

=head2 C<< $mech->links >>

Returns all links in the document.

Currently accepts no parameters.

=cut

%link_spec = (
    a      => { url => 'href', },
    area   => { url => 'href', },
    frame  => { url => 'src', },
    iframe => { url => 'src', },
    link   => { url => 'href', },
    meta   => { url => 'content', xpath => (join '',
                    q{translate(@http-equiv,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',},
                    q{'abcdefghijklmnopqrstuvwxyz')="refresh"}), },
);

# taken from WWW::Mechanize. This should possibly just be reused there
sub make_link {
    my ($self,$node,$base) = @_;
    my $tag = lc $node->{tagName};
    
    if (! exists $link_spec{ $tag }) {
        warn "Unknown tag '$tag'";
    };
    my $url = $node->{ $link_spec{ $tag }->{url} };
    
    if ($tag eq 'meta') {
        my $content = $url;
        if ( $content =~ /^\d+\s*;\s*url\s*=\s*(\S+)/i ) {
            $url = $1;
            $url =~ s/^"(.+)"$/$1/ or $url =~ s/^'(.+)'$/$1/;
        }
        else {
            undef $url;
        }
    };
    
    if (defined $url) {
        my $res = WWW::Mechanize::Link->new({
            tag   => $tag,
            name  => $node->{name},
            base  => $base,
            url   => $url,
            text  => $node->{innerHTML},
            attrs => {},
        });
        
        $res
    } else {
        ()
    };
}

sub links {
    my ($self) = @_;
    my @links = $self->selector( join ",", sort keys %link_spec);
    my $base = $self->base;
    return map {
        $self->make_link($_,$base)
    } @links;
};

# Call croak or cluck, depending on the C< autodie > setting
sub signal_condition {
    my ($self,$msg) = @_;
    if ($self->{autodie}) {
        croak $msg
    } else {
        carp $msg
    }
};

=head2 C<< $mech->find_link_dom OPTIONS >>

A method to find links, like L<WWW::Mechanize>'s
C<< ->find_links >> method.

Returns the DOM object as L<MozRepl::RemoteObject>::Instance.

The supported options are:

C<< text >> - the text of the link

C<< id >> - the C<id> attribute of the link

C<< name >> - the C<name> attribute of the link

C<< url >> - the URL attribute of the link (C<href>, C<src> or C<content>).

C<< class >> - the C<class> attribute of the link

C<< n >> - the (1-based) index. Defaults to returning the first link.

C<< single >> - If true, ensure that only one element is found. Otherwise croak
or carp, depending on the C<autodie> parameter.

C<< one >> - If true, ensure that at least one element is found. Otherwise croak
or carp, depending on the C<autodie> parameter.

The method C<croak>s if no link is found. If the C<single> option is true,
it also C<croak>s when more than one link is found.

=cut

sub quote_xpath($) {
    local $_ = $_[0];
    s/(['"\[])/\\$1/g;
    $_
};

sub find_link_dom {
    my ($self,%opts) = @_;
    my %xpath_options;
    my $document = delete $opts{ document } || $self->document;
    my $node = delete $opts{ node } || $document;
    my $single = delete $opts{ single };
    my $one = delete $opts{ one } || $single;
    if ($single and exists $opts{ n }) {
        croak "It doesn't make sense to use 'single' and 'n' option together"
    };
    my $n = (delete $opts{ n } || 1);
    $n--
        if ($n ne 'all'); # 1-based indexing
    my @spec;
    if (my $p = delete $opts{ text }) {
        push @spec, sprintf 'text() = "%s"', quote_xpath $p;
    }
    # broken?
    #if (my $p = delete $opts{ text_contains }) {
    #    push @spec, sprintf 'contains(text(),"%s")', quotemeta $p;
    #}
    if (my $p = delete $opts{ id }) {
        push @spec, sprintf '@id = "%s"', quote_xpath $p;
    }
    if (my $p = delete $opts{ name }) {
        push @spec, sprintf '@name = "%s"', quote_xpath $p;
    }
    if (my $p = delete $opts{ class }) {
        push @spec, sprintf '@class = "%s"', quote_xpath $p;
    }
    if (my $p = delete $opts{ url }) {
        push @spec, sprintf '@href = "%s" or @src="%s"', quote_xpath $p, quote_xpath $p;
    }
    my @tags = (sort keys %link_spec);
    if (my $p = delete $opts{ tag }) {
        @tags = $p;
    };
    if (my $p = delete $opts{ tag_regex }) {
        @tags = grep /$p/, @tags;
    };
    
    my $q = join '|', 
            map {
                my @full = map {qq{($_)}} grep {defined} (@spec, $link_spec{$_}->{xpath});
                if (@full) {
                    sprintf "//%s[%s]", $_, join " and ", @full;
                } else {
                    sprintf "//%s", $_
                };
            }  (@tags);
    #warn $q;
    
    my @res = $document->__xpath($q, $node);
    
    if (keys %opts) {
        # post-filter the remaining links through WWW::Mechanize
        # for all the options we don't support with XPath
        
        my $base = $self->base;
        require WWW::Mechanize;
        @res = grep { 
            WWW::Mechanize::_match_any_link_parms($self->make_link($_,$base),\%opts) 
        } @res;
    };
    
    if ($one) {
        if (0 == @res) { $self->signal_condition( "No link found matching '$q'" )};
        if ($single) {
            if (1 <  @res) {
                $self->highlight_node(@res);
                $self->signal_condition(
                    sprintf "%d elements found found matching '%s'", scalar @res, $q
                );
            };
        };
    };
    
    if ($n eq 'all') {
        return @res
    };
    $res[$n]
}

=head2 C<< $mech->find_link OPTIONS >>

A method quite similar to L<WWW::Mechanize>'s method.

Returns a L<WWW::Mechanize::Link> object.

=cut

sub find_link {
    my ($self,%opts) = @_;
    my $base = $self->base;
    if (my $link = $self->find_link_dom(%opts)) {
        return $self->make_link($link, $base)
    } else {
        return
    };
};

=head2 C<< $mech->find_all_links OPTIONS >>

Finds all links in the document.

Returns them as list or an array reference, depending
on context.

=cut

sub find_all_links {
    my ($self,%opts) = @_;
    $opts{ n } = 'all';
    my $base = $self->base;
    my @matches = map {
        $self->make_link($_, $base);
    } $self->find_all_links_dom( %opts );
    return @matches if wantarray;
    return \@matches;
};

=head2 C<< $mech->find_all_links_dom OPTIONS >>

Finds all matching linky DOM nodes in the document.

Returns them as list or an array reference, depending
on context.

=cut

sub find_all_links_dom {
    my ($self,%opts) = @_;
    $opts{ n } = 'all';
    my @matches = $self->find_link_dom( %opts );
    return @matches if wantarray;
    return \@matches;
};


=head2 C<< $mech->click NAME [,X,Y] >>

Has the effect of clicking a button on the current form. The first argument
is the C<name> of the button to be clicked. The second and third arguments
(optional) allow you to specify the (x,y) coordinates of the click.

If there is only one button on the form, $mech->click() with no arguments
simply clicks that one button.

If you pass in a hash reference instead of a name,
the following keys are recognized:

=over 4

=item * C<selector> - Find the element to click by the CSS selector

=item * C<xpath> - Find the element to click by the XPath query

=item * C<synchronize> - Synchronize the click (default is 1)

=back

Returns a L<HTTP::Response> object.

As a deviation from the WWW::Mechanize API, you can also pass a 
hash reference as the first parameter. In it, you can specify
the parameters to search much like for the C<find_link> calls.

=cut

sub click {
    my ($self,$name,$x,$y) = @_;
    my %options;
    my $q;
    my @buttons;
    if (ref $name and blessed($name) and $name->can('__click')) {
        $options{ dom } = $name;
        $options{ synchronize } = 1;
    } elsif (ref $name eq 'HASH') { # options
        if (exists $name->{ dom }) {
            @buttons = delete $name->{dom};
        } else {
            my ($method,$q);
            for my $meth (qw(selector xpath)) {
                if (exists $name->{ $meth }) {
                    $q = delete $name->{ $meth };
                    $method = $meth;
                }
            };
            croak "Need either a selector or an xpath key!"
                if not $method;
            @buttons = $self->$method( $q => %$name );
        };
        %options = (%options, %$name);
    } else {
        $options{ name } = $name;
        $options{ synchronize } = 1;
    };
    if (! exists $options{ synchronize }) {
        $options{ synchronize } = 1;
    };
    
    if ($options{ dom }) {
        @buttons = $options{ dom };
        $q = "DOM element";
    } elsif (exists $options{ selector }) {
        @buttons = $self->selector( $options{ selector } );
        $q = "selector = '$options{ selector }'";
    } elsif (exists $options{ xpath }) {
        @buttons = $self->xpath( $options{ xpath } );
        $q = "xpath = '$options{ xpath }'";
    } elsif (exists $options{ name }) {
        my $name = delete $options{ $name };
        $q = "name = '$name'";
        $name = quotemeta($name || '');
        @buttons = (
                       $self->xpath(sprintf q{//button[@name="%s"]}, $name),
                       $self->xpath(sprintf q{//input[(@type="button" or @type="submit") and @name="%s"]}, $name), 
                       $self->xpath(q{//button}),
                       $self->xpath(q{//input[(@type="button" or @type="submit")]}), 
                      );
    };
    if ($options{ one }) {
        if (0 == @buttons) {
            $self->signal_condition(
                "No button matching '$name' found"
            );
        };
        if ($options{ single }) {
            if (1 <  @buttons) {
                $self->highlight_node(@buttons);
                $self->signal_condition(
                    sprintf "%d buttons found found matching '%s'", scalar @buttons, $q
                );
            };
        };
    };
    
    if ($options{ synchronize }) {
        my $event = $self->synchronize($self->events, sub { # ,'abort'
            $buttons[0]->__click();
        });
    } else {
        $buttons[0]->__click();
    }

    if (defined wantarray) {
        return $self->response
    };
}

=head2 C<< $mech->follow_link >>

Follows the given link. Takes the same parameters that C<find_link>
uses.

=cut

sub follow_link {
    my ($self,$link,%opts);
    if (@_ == 2) { # assume only a link parameter
        ($self,$link) = @_
    } else {
        ($self,%opts) = @_;
        $link = $self->find_link_dom(one => 1, %opts);
    }
    $self->synchronize( sub {
        $link->__click();
    });
}

=head1 FORM METHODS

=head2 C<< $mech->current_form >>

Returns the current form.

This method is incompatible with L<WWW::Mechanize>.
It returns the DOM C<< <form> >> object and not
a L<HTML::Form> instance.

=cut

sub current_form {
    $_[0]->{current_form}
};

=head2 C<< $mech->form_name NAME [, OPTIONS] >>

Selects the current form by its name.

=cut

sub form_name {
    my ($self,$name,%options) = @_;
    $self->{current_form} = $self->selector("form:$name",
        user_info => "form id '$name'",
        single => 1,
        %options
    );
};

=head2 C<< $mech->form_id ID [, OPTIONS] >>

Selects the current form by its C<id> attribute.

This is equivalent to calling

    $mech->selector("#$name",single => 1,%options)

=cut

sub form_id {
    my ($self,$name,%options) = @_;
    $self->{current_form} = $self->selector("#$name",
        user_info => "form id '$name'",
        single => 1,
        %options
    );
};

=head2 C<< $mech->form_number NUMBER [, OPTIONS] >>

Selects the I<number>th form.

=cut

sub form_number {
    my ($self,$number,%options) = @_;
    $self->{current_form} = $self->xpath("//form[$number]",
        user_info => "form number $number",
        single => 1,
        %options
    );
};

=head2 C<< $mech->form_with_fields [$OPTIONS], FIELDS >>

Find the form which has the listed fields.

If the first argument is a hash reference, it's taken
as options to C<< ->xpath >>

=cut

sub form_with_fields {
    my ($self,@fields) = @_;
    my $options = {};
    if (ref $fields[0] eq 'HASH') {
        $options = shift @fields;
    };
    my @clauses = map { sprintf '[@name="%s"]', quote_xpath($_) } @fields;
    my $q = "//form" . join "", @clauses;
    $self->{current_form} = $self->xpath($q,
        single => 1,
        user_info => "form fields [@fields]",
        %$options
    );
};

=head2 C<< $mech->forms OPTIONS >>

When called in a list context, returns a list 
of the forms found in the last fetched page.
In a scalar context, returns a reference to
an array with those forms.

The returned elements are the DOM C<< <form> >> elements.

=cut

sub forms {
    my ($self, %options) = @_;
    my @res = $self->selector('form', %options);
    return wantarray ? @res
                     : \@res
};

=head2 C<< $mech->value NAME [, VALUE] [,PRE EVENTS] [,POST EVENTS] >>

Sets the field with the name to the given value.
Returns the value.

Note that this uses the C<name> attribute of the HTML,
not the C<id> attribute.

By passing the array reference C<PRE EVENTS>, you can indicate which
Javascript events you want to be triggered before setting the value.
C<POST EVENTS> contains the evens you want to be triggered
after setting the value.

By default, the events set in the
constructor for C<pre_events> and C<post_events>
are triggered.

=head3 Set a value without triggering events

  $mech->value( 'myfield', 'myvalue', [], [] );

=cut

sub value {
    my ($self,$name,$value,$pre,$post) = @_;
    my @fields;
    if (blessed $name) {
        @fields = $name;
    } else {
        @fields = $self->xpath(sprintf q{//input[@name="%s"] | //select[@name="%s"] | //textarea[@name="%s"]}, 
                                          $name,              $name,                 $name);
    };
    $pre ||= $self->{pre_value};
    $pre = [$pre]
        if (! ref $pre);
    $post ||= $self->{post_value};
    $post = [$post]
        if (! ref $pre);
    $self->signal_condition( "No field found for '$name'" )
        if (! @fields);
    $self->signal_condition( "Too many fields found for '$name'" )
        if (@fields > 1);
    if (@_ >= 3) {
        for my $ev (@$pre) {
            $fields[0]->__event($ev);
        };

        $fields[0]->{value} = $value;

        for my $ev (@$post) {
            $fields[0]->__event($ev);
        };
    }
    $fields[0]->{value}
}

=head2 C<< $mech->set_visible @values >>

This method sets fields of the current form without having to know their
names. So if you have a login screen that wants a username and password,
you do not have to fetch the form and inspect the source (or use the
C<mech-dump> utility, installed with L<WWW::Mechanize>) to see what
the field names are; you can just say

  $mech->set_visible( $username, $password );

and the first and second fields will be set accordingly. The method is
called set_visible because it acts only on visible fields;
hidden form inputs are not considered. 

The specifiers that are possible in WWW::Mechanize are not yet supported.

=cut

sub set_visible {
    my ($self,@values) = @_;
    my $form = $self->current_form;
    my @form;
    if ($form) { @form = (node => $form) };
    my @visible_fields = $self->xpath(q{//input[@type != "hidden" and @type!= "button"]}, 
                                      @form
                                      );
    for my $idx (0..$#values) {
        if ($idx > $#visible_fields) {
            $self->signal_condition( "Not enough fields on page" );
        }
        $visible_fields[ $idx ]->{value} = $values[ $idx ];
    }
}

=head2 C<< $mech->clickables >>

Returns all clickable elements, that is, all elements
with an C<onclick> attribute.

=cut

sub clickables {
    my ($self, %options) = @_;
    $self->xpath('//*[@onclick]', %options);
};

=head2 C<< $mech->xpath QUERY, %options >>

Runs an XPath query in Firefox against the current document.

The options allow the following keys:

=over 4

=item *

C<< document >> - document in which the code is to be executed. Use this to
search a node within a subframe of C<< $mech->document >>.

=item *

C<< node >> - node relative to which the code is to be executed

=item *

C<< single >> - If true, ensure that only one element is found. Otherwise croak
or carp, depending on the C<autodie> parameter.

=item *

C<< one >> - If true, ensure that at least one element is found. Otherwise croak
or carp, depending on the C<autodie> parameter.

=back

Returns the matched nodes.

This is a method that is not implemented in WWW::Mechanize.

In the long run, this should go into a general plugin for
L<WWW::Mechanize>.

=cut

sub xpath {
    my ($self,$query,%options) = @_;
    $options{ document } ||= $self->document;
    $options{ node } ||= $options{ document };
    $options{ user_info } ||= "'$query'";
    my $single = delete $options{ single };
    my $one = delete $options{ one } || $single;
    my @res = $options{ document }->__xpath($query, $options{ node });
    if ($one) {
        if (@res == 0) {
            $self->signal_condition( "No elements found for $options{ user_info }" );
        };
        if ($single) {
            if (@res > 1) {
                $self->highlight_node(@res);
                $self->signal_condition( (scalar @res) . " elements found for $options{ user_info }" );
            }
        };
        return @res ? $res[0] : ();
    } else {
        return @res
    };
};

=head2 C<< $mech->selector css_selector, %options >>

Returns all nodes matching the given CSS selector.

In the long run, this should go into a general plugin for
L<WWW::Mechanize>.

=cut

sub selector {
    my ($self,$query,%options) = @_;
    $options{ user_info } ||= "CSS selector '$query'";
    my $q = selector_to_xpath($query);    
    $self->xpath($q, %options);
};

=head1 IMAGE METHODS

=head2 C<< $mech->content_as_png [TAB, COORDINATES] >>

Returns the given tab or the current page rendered as PNG image.

This is specific to WWW::Mechanize::Firefox.

Currently, the data transfer between Firefox and Perl
is done Base64-encoded. It would be beneficial to find what's
necessary to make JSON handle binary data more gracefully.

If the coordinates are given, that rectangle will be cut out.
The coordinates should be a hash with the four usual entries,
C<left>,C<top>,C<width>,C<height>.

=head3 Save top left corner of the current page as PNG

  my $rect = {
    left  =>    0,
    top   =>    0,
    width  => 200,
    height => 200,
  };
  my $png = $mech->content_as_png(undef, $rect);
  open my $fh, '>', 'page.png'
      or die "Couldn't save to 'page.png': $!";
  binmode $fh;
  print {$fh} $png;
  close $fh;

=cut

sub content_as_png {
    my ($self, $tab, $rect) = @_;
    $tab ||= $self->tab;
    $rect ||= {};
    
    # Mostly taken from
    # http://wiki.github.com/bard/mozrepl/interactor-screenshot-server
    my $screenshot = $self->repl->declare(<<'JS');
    function (tab,rect) {
        var browserWindow = Cc['@mozilla.org/appshell/window-mediator;1']
            .getService(Ci.nsIWindowMediator)
            .getMostRecentWindow('navigator:browser');
        var canvas = browserWindow
               .document
               .createElementNS('http://www.w3.org/1999/xhtml', 'canvas');
        var browser = tab.linkedBrowser;
        var win = browser.contentWindow;
        var left = rect.left || 0;
        var top = rect.top || 0;
        var width = rect.width || win.document.width;
        var height = rect.height || win.document.height;
        canvas.width = width;
        canvas.height = height;
        var ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, width, height);
        ctx.save();
        ctx.scale(1.0, 1.0);
        ctx.drawWindow(win, left, top, width, height, 'rgb(255,255,255)');
        ctx.restore();

        //return atob(
        return canvas
               .toDataURL('image/png', '')
               .split(',')[1]
        // );
    }
JS
    return decode_base64($screenshot->($tab, $rect))
};

=head2 C<< $mech->element_as_png $element >>

Returns PNG image data for a single element

=cut

sub element_as_png {
    my ($self, $element) = @_;
    my $tab = $self->tab;

    my $pos = $self->element_coordinates($element);
    return $self->content_as_png($tab, $pos);
};

=head2 C<< $mech->element_coordinates $element >>

Returns the page-coordinates of the C<$element>
in pixels as a hash with four entries, C<left>, C<top>, C<width> and C<height>.

This function might get moved into another module more geared
towards rendering HTML.

=cut

sub element_coordinates {
    my ($self, $element) = @_;
    
    # Mostly taken from
    # http://www.quirksmode.org/js/findpos.html
    my $findPos = $self->repl->declare(<<'JS');
    function (obj) {
        var res = { 
            left: 0,
            top: 0,
            width: obj.scrollWidth,
            height: obj.scrollHeight
        };
        if (obj.offsetParent) {
            do {
                res.left += obj.offsetLeft;
                res.top += obj.offsetTop;
            } while (obj = obj.offsetParent);
        }
        return res;
    }
JS
    $findPos->($element);
};

1;

__END__

=head1 COOKIE HANDLING

Firefox cookies will be read through L<HTTP::Cookies::MozRepl>. This is
relatively slow currently.

=head1 INCOMPATIBILITIES WITH WWW::Mechanize

As this module is in a very early stage of development,
there are many incompatibilities. The main thing is
that only the most needed WWW::Mechanize methods
have been implemented by me so far.

=head2 Link attributes

In Firefox, the C<name> attribute of links seems always
to be present on links, even if it's empty. This is in
difference to WWW::Mechanize, where the C<name> attribute
can be C<undef>.

=head2 Unsupported Methods

=over 4

=item *

C<< ->form_with_fields >> needs tests

=item *

C<< ->find_all_inputs >>

This function is likely best implemented through C<< $mech->selector >>.

=item *

C<< ->find_all_submits >>

This function is likely best implemented through C<< $mech->selector >>.

=item *

C<< ->images >>

This function is likely best implemented through C<< $mech->selector >>.

=item *

C<< ->find_image >>

This function is likely best implemented through C<< $mech->selector >>.

=item *

C<< ->find_all_images >>

This function is likely best implemented through C<< $mech->selector >>.

=item *

C<< ->field >>

=item *

C<< ->select >>

=item *

C<< ->set_fields >>

This is basically a loop over C<< $mech->value >>.

=item *

C<< ->tick >>

=item *

C<< ->untick >>

=item *

C<< ->submit >>

=back

=head2 Functions that will likely never be implemented

These functions are unlikely to be implemented because
they make little sense in the context of Firefox.

=over 4

=item *

C<< ->add_header >>

=item *

C<< ->delete_header >>

=item *

C<< ->clone >>

=item *

C<< ->credentials( $username, $password ) >>

=item *

C<< ->get_basic_credentials( $realm, $uri, $isproxy ) >>

=item *

C<< ->clear_credentials() >>

=item *

C<< ->put >>

I have no use for it

=item *

C<< ->post >>

I have no use for it

=back

=head1 TODO

=over 4

=item *

Implement download progress via C<nsIWebBrowserPersist.progressListener>
and our own C<nsIWebProgressListener>.

=item *

Make C<< ->click >> use C<< ->click_with_options >>

=item *

Make C<< ->selector >> and C<< ->xpath >> work across subframes.

=item *

Implement "reuse tab if exists, otherwise create new"

=item *

Rip out parts of Test::HTML::Content and graft them
onto the C<links()> and C<find_link()> methods here.
Firefox is a conveniently unified XPath engine.

Preferrably, there should be a common API between the two.

=item *

Spin off XPath queries (C<< ->xpath >>) and CSS selectors (C<< ->selector >>)
into their own Mechanize plugin(s).

=back

=head1 SEE ALSO

=over 4

=item *

The MozRepl Firefox plugin at L<http://wiki.github.com/bard/mozrepl>

=item *

L<WWW::Mechanize> - the module whose API grandfathered this module

=item *

L<https://developer.mozilla.org/En/FUEL/Window> for JS events relating to tabs

=item *

L<https://developer.mozilla.org/en/Code_snippets/Tabbed_browser#Reusing_tabs>
for more tab info

=back

=head1 REPOSITORY

The public repository of this module is 
L<http://github.com/Corion/www-mechanize-Firefox>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2009 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
