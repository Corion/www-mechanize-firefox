package WWW::Mechanize::FireFox;
use strict;
use Time::HiRes;

use MozRepl::RemoteObject;
use URI;
use HTTP::Response;
use HTML::Selector::XPath 'selector_to_xpath';
use MIME::Base64;
use WWW::Mechanize::Link;
use HTTP::Cookies::MozRepl;
use Carp qw(carp croak);

use vars qw'$VERSION %link_spec';
$VERSION = '0.07';

=head1 NAME

WWW::Mechanize::FireFox - use FireFox as if it were WWW::Mechanize

=head1 SYNOPSIS

  use WWW::Mechanize::FireFox;
  my $mech = WWW::Mechanize::FireFox->new();
  $mech->get('http://google.com');

This will let you automate FireFox through the
Mozrepl plugin, which you need to have installed
in your FireFox.

=head1 METHODS

=cut

# This should maybe become MozRepl::FireFox::Util?
# or MozRepl::FireFox::UI ?
sub openTabs {
    my ($self,$repl) = @_;
    $repl ||= $self->repl;
    my $open_tabs = $repl->declare(<<'JS');
function() {
    var idx = 0;
    var tabs = [];

    Array.prototype.forEach.call(
        window.getBrowser().tabContainer.childNodes, 
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
    return tabs;
}
JS
    my $tabs = $open_tabs->();
    return @$tabs
}

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

C<tab> - regex for the title of the tab to reuse. If no matching tab is
found, the constructor dies.

C<log> - array reference to log levels, passed through to L<MozRepl::RemoteObject>

C<events> - the set of default Javascript events to listen for while
waiting for a reply

C<repl> - a premade L<MozRepl::RemoteObject> instance

C<pre_events> - the events that are sent to an input field before its
value is changed. By default this is C<[focus]>.

C<post_events> - the events that are sent to an input field after its
value is changed. By default this is C<[blur, change]>.

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
        
    bless \%args, $class;
};

=head2 C<< $mech->addTab( OPTIONS ) >>

Creates a new tab. The tab will be automatically closed upon program exit.

If you want the tab to remain open, pass a false value to the the C< autoclose >
option.

=cut

sub addTab {
    my ($self, %options) = @_;
    my $repl = $options{ repl } || $self->repl;
    my $rn = $repl->name;
    my $tab = $repl->expr(<<'JS');
        window.getBrowser().addTab()
JS
    if (not exists $options{ autoclose } or $options{ autoclose }) {
        $tab->__release_action('window.getBrowser().removeTab(self)');
    };
    
    $tab
};

=head2 C<< $mech->tab >>

Gets the object that represents the FireFox tab used by WWW::Mechanize::FireFox.

This method is special to WWW::Mechanize::FireFox.

=cut

sub tab { $_[0]->{tab} };

=head2 C<< $mech->repl >>

Gets the L<MozRepl::RemoteObject> instance that is used.

This method is special to WWW::Mechanize::FireFox.

=cut

sub repl { $_[0]->{repl} };

=head2 C<< $mech->events >>

Sets or gets the set of Javascript events that WWW::Mechanize::FireFox
will wait for after requesting a new page. Returns an array reference.

This method is special to WWW::Mechanize::FireFox.

=cut

sub events { $_[0]->{events} = $_[1] if (@_ > 1); $_[0]->{events} };


=head2 C<< $mech->get(URL) >>

Retrieves the URL C<URL> into the tab.

It returns a faked L<HTTP::Response> object for interface compatibility
with L<WWW::Mechanize>. It does not yet support the additional parameters
that L<WWW::Mechanize> supports for saving a file etc.

Currently, the response will only have the status
codes of 200 for a successful fetch and 500 for everything else.

=cut

sub get {
    my ($self,$url) = @_;
    my $b = $self->tab->{linkedBrowser};

    my $event = $self->synchronize($self->events, sub {
        $b->loadURI($url);
    });
    
    # The event we get back is not necessarily indicative :-(
    # Let's just look at the kind of response we get back
    
    return $self->response
};

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
                //alert(evname);
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

  my $l = $mech->xpath('//a[@onclick]');
  $mech->synchronize('DOMFrameContentLoaded', sub {
      $l->__click()
  });

It is necessary to synchronize with the browser whenever
a click performs an action that takes longer and
fires an event on the browser object.

The C<DOMFrameContentLoaded> event is fired by FireFox when
the whole DOM and all C<iframe>s have been loaded.
If your document doesn't have frames, use the C<DOMContentLoaded>
event instead.

If you leave out C<$event>, the value of C<< ->events() >> will
be used instead.

=cut

sub synchronize {
    my ($self,$events,$callback) = @_;
    if (ref $events and ref $events eq 'CODE') {
        $callback = $events;
        $events = $self->events;
    };
    
    $events = [ $events ]
        unless ref $events;
    
    # 'load' on linkedBrowser is good for successfull load
    # 'error' on tab is good for failed load :-(
    my $b = $self->tab->{linkedBrowser};
    my $load_lock = $self->_addEventListener($b,$events);
    $callback->();
    $self->_wait_while_busy($load_lock);
};

=head2 C<< $mech->document >>

Returns the DOM document object.

This is WWW::Mechanize::FireFox specific.

=cut

sub document {
    my ($self) = @_;
    $self->tab->__dive(qw[linkedBrowser contentWindow document]);
}

=head2 C<< $mech->docshell >>

Returns the C<docShell> Javascript object.

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

=head2 C<< $mech->res >> / C<< $mech->response >>

Returns the current response as a L<HTTP::Response> object.

=cut

sub response {
    my ($self) = @_;
    my $eff_url = $self->document->{documentURI};
    if ($eff_url =~ /^about:neterror/) {
        # this is an error
        return HTTP::Response->new(500)
    };   

    # We're cool!
    return HTTP::Response->new(200,'',[],$self->content)
}
*res = \&response;

=head2 C<< $mech->success >>

Returns a boolean telling whether the last request was successful.
If there hasn't been an operation yet, returns false.

This is a convenience function that wraps C<< $mech->res->is_success >>.

=cut

sub success {
    $_[0]->response->is_success
}

=head2 C<< $mech->status >>

Returns the HTTP status code of the response. This is a 3-digit number like 200 for OK, 404 for not found, and so on.

Currently can only return 200 (for OK) and 500 (for error)

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
    $self->response
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
    $self->response
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
    $self->response
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

=head2 C<< $mech->base >>

Returns the URL base for the current page.

The base is either specified through a C<base>
tag or is the current URL.

This method is specific to WWW::Mechanize::FireFox

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

=head2 C<< $mech->title >>

Returns the current document title.

=cut

sub title {
    my ($self) = @_;
    return $self->document->{title};
};


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
    meta   => { url => 'content', xpath => q{translate(@http-equiv,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')="refresh"}, },
);

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
        $url = URI->new($url);
        WWW::Mechanize::Link->new({
            tag   => $tag,
            name  => $node->{name},
            base  => $base,
            url   => $url,
            text  => $node->{innerHTML},
            attrs => {},
        })
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

=head2 C<< $mech->find_link_dom OPTIONS >>

A method to find links, like L<WWW::Mechanize>'s
C<< ->find_links >> method.

Returns the DOM object as L<MozRepl::RemoteObject>::Instance.

The supported options are:

C<< text >> - the text of the link

C<< id >> - the C<id> attribute of the link

C<< name >> - the C<name> attribute of the link

C<< class >> - the C<class> attribute of the link

C<< n >> - the (1-based) index. Defaults to returning the first link.

C<< single >> - If true, ensure that only one element is found.

The method C<croak>s if no link is found. If the C<single> option is true,
it also C<croak>s when more than one link is found.

=cut

sub find_link_dom {
    my ($self,%opts) = @_;
    my $document = delete $opts{ document } || $self->document;
    my $single = delete $opts{ single };
    if ($single and exists $opts{ n }) {
        croak "Cannot use 'single' and 'n' option together"
    };
    my $n = (delete $opts{ n } || 1);
    $n--
        if ($n ne 'all'); # 1-based indexing
    my @spec;
    if (my $p = delete $opts{ text }) {
        push @spec, sprintf 'text() = "%s"', quotemeta $p;
    }
    # broken?
    #if (my $p = delete $opts{ text_contains }) {
    #    push @spec, sprintf 'contains(text(),"%s")', quotemeta $p;
    #}
    if (my $p = delete $opts{ id }) {
        push @spec, sprintf '@id = "%s"', quotemeta $p;
    }
    if (my $p = delete $opts{ name }) {
        push @spec, sprintf '@name = "%s"', quotemeta $p;
    }
    if (my $p = delete $opts{ class }) {
        push @spec, sprintf '@class = "%s"', quotemeta $p;
    }
    if (my $p = delete $opts{ url }) {
        push @spec, sprintf '@href = "%s"', quotemeta $p;
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
                my @full = grep {defined} (@spec, $link_spec{$_}->{xpath});
                if (@full) {
                    sprintf "//%s[%s]", $_, join " and ", @full;
                } else {
                    sprintf "//%s", $_
                };
            }  (@tags);
    
    my @res = $document->__xpath($q);
    
    if (keys %opts) {
        # post-filter the remaining links through WWW::Mechanize
        # for all the options we don't support with XPath
        
        my $base = $self->base;
        require WWW::Mechanize;
        @res = grep { 
            WWW::Mechanize::_match_any_link_parms($self->make_link($_,$base),\%opts) 
        } @res;
        #for (@res) {
        #    warn "<$_->{tagName}>";
        #};
    };
    
    if ($single) {
        if (0 == @res) { croak "No link found matching '$q'" };
        if (1 <  @res) {
            $self->highlight_node(@res);
            croak sprintf "%d elements found found matching '%s'", scalar @res, $q;
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


=head2 C<< $mech->click >>

Has the effect of clicking a button on the current form. The first argument
is the name of the button to be clicked. The second and third arguments
(optional) allow you to specify the (x,y) coordinates of the click.

If there is only one button on the form, $mech->click() with no arguments
simply clicks that one button.

Returns a L<HTTP::Response> object.

=cut

sub click {
    my ($self,$name,$x,$y) = @_;
    $name = quotemeta($name || '');
    my @buttons = (
                   $self->xpath(sprintf q{//button[@name="%s"]}, $name),
                   $self->xpath(sprintf q{//input[(@type="button" or @type="submit") and @name="%s"]}, $name), 
                   $self->xpath(q{//button}),
                   $self->xpath(q{//input[(@type="button" or @type="submit")]}), 
                  );
    if (! @buttons) {
        croak "No button matching '$name' found";
    };
    my $event = $self->synchronize($self->events, sub { # ,'abort'
        $buttons[0]->__click();
    });
    return $self->response
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
        my $link = $self->find_link_dom(%opts);
    }
    $self->synchronize( sub {
        $link->__click();
    });
    $self->response
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
    my @visible_fields = $self->xpath(q{//input[@type != "hidden" and @type!= "button"]});
    for my $idx (0..$#values) {
        if ($idx > $#visible_fields) {
            croak "Not enough fields on page";
        }
        $visible_fields[ $idx ]->{value} = $values[ $idx ];
    }
}

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
    my @fields = $self->xpath(sprintf q{//input[@name="%s"] | //select[@name="%s"] | //textarea[@name="%s"]}, 
                                          $name,              $name,                 $name);
    $pre ||= $self->{pre_value};
    $pre = [$pre]
        if (! ref $pre);
    $post ||= $self->{post_value};
    $post = [$post]
        if (! ref $pre);
    croak "No field found for '$name'"
        if (! @fields);
    croak "Too many fields found for '$name'"
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

=head2 C<< $mech->clickables >>

Returns all clickable elements, that is, all elements
with an C<onclick> attribute.

=cut

sub clickables {
    my ($self) = @_;
    $self->xpath('//*[@onclick]');
};

=head2 C<< $mech->xpath QUERY, %options >>

Runs an XPath query in FireFox against the current document.

The options allow the following keys:

=over 4

=item *

C<< node >> - node relative to which the code is to be executed

=back

Returns the matched nodes.

This is a method that is not implemented in WWW::Mechanize.

In the long run, this should go into a general plugin for
L<WWW::Mechanize>.

=cut

sub xpath {
    my ($self,$query,%options) = @_;
    $options{ node } ||= $self->document;
    my @res = $self->document->__xpath($query, $options{ node });
    if ($options{single}) {
        if (@res != 1) {
            if (@res == 0) {
                croak "No element found for '$query'";
            } else {
                $self->highlight_nodes(@res);
                croak scalar @res . " elements found for '$query'";
            }
        };
        return $res[0];
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
    my $q = selector_to_xpath($query);
    
    my @res = $self->xpath($q);
    if ($options{single}) {
        if (@res != 1) {
            if (@res == 0) {
                croak "No element found for '$query'";
            } else {
                $self->highlight_nodes(@res);
                croak scalar(@res) . " elements found for '$query'";
            }
        };
        return $res[0];
    } else {
        return @res
    }
};

=head2 C<< $mech->cookies >>

Returns a L<HTTP::Cookies> object that was initialized
from the live FireFox instance.

B<Note:> C<< ->set_cookie >> is not yet implemented,
as is saving the cookie jar.

=cut

sub cookies {
    return HTTP::Cookies::MozRepl->new(
        repl => $_[0]->repl
    )
}

=head2 C<< $mech->content_as_png [TAB, COORDINATES] >>

Returns the given tab or the current page rendered as PNG image.

This is specific to WWW::Mechanize::FireFox.

Currently, the data transfer between FireFox and Perl
is done Base64-encoded. It would be beneficial to find what's
necessary to make JSON handle binary data more gracefully.

If the coordinates are given, that rectangle will be cut out.
The coordinates should be a hash with the four usual entries,
C<left>,C<top>,C<width>,C<height>.

=head3 Save top left corner the current page as PNG

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

=head2 C<< $mech->allow OPTIONS >>

Enables or disables browser features for the current tab.
The following options are recognized:

C<plugins> 	 - Whether to allow plugin execution.

C<javascript> 	 - Whether to allow Javascript execution.

C<metaredirects> - Attribute stating if refresh based redirects can be allowed.

C<frames>, C<subframes> 	 - Attribute stating if it should allow subframes (framesets/iframes) or not.

C<images> 	 - Attribute stating whether or not images should be loaded.

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

1;

__END__

=head1 COOKIE HANDLING

FireFox cookies will be read through L<HTTP::Cookies::MozRepl>. This is
relatively slow currently.

=head1 INCOMPATIBILITIES WITH WWW::Mechanize

As this module is in a very early stage of development,
there are many incompatibilities. The main thing is
that only the most needed WWW::Mechanize methods
have been implemented by me so far.

=head2 Link attributes

In FireFox, the C<name> attribute of links seems always
to be present on links, even if it's empty. This is in
difference to WWW::Mechanize, where the C<name> attribute
can be C<undef>.

=head2 Unsupported Methods

=over 4

=item *

C<< ->put >>

=item *

C<< ->find_all_inputs >>

=item *

C<< ->find_all_submits >>

=item *

C<< ->images >>

=item *

C<< ->find_image >>

=item *

C<< ->find_all_images >>

=item *

C<< ->forms >>

=item *

C<< ->form_number >>

=item *

C<< ->form_name >>

=item *

C<< ->form_id >>

This one certainly would be easier done
by C<< $mech->document->getElementById() >>

=item *

C<< ->form_with_fields >>

=item *

C<< ->field >>

=item *

C<< ->select >>

=item *

C<< ->set_fields >>

=item *

C<< ->tick >>

=item *

C<< ->untick >>

=item *

C<< ->click >>

=item *

C<< ->submit >>

=item *

C<< ->add_header >>

Likely will never be implemented

=item *

C<< ->delete_header >>

Likely will never be implemented

=item *

C<< ->clone >>

Likely will never be implemented

=item *

C<< ->credentials( $username, $password ) >>

Unlikely to be implemented

=item *

C<< ->get_basic_credentials( $realm, $uri, $isproxy ) >>

Unlikely to be implemented

=item *

C<< ->clear_credentials() >>

Unlikely to be implemented

=back

=head1 TODO

=over 4

=item *

Implement C<autodie>

=item *

Implement "reuse tab if exists, otherwise create new"

=item *

Rip out parts of Test::HTML::Content and graft them
onto the C<links()> and C<find_link()> methods here.
FireFox is a conveniently unified XPath engine.

Preferrably, there should be a common API between the two.

=item *

Spin off XPath queries and CSS selectors into
their own Mechanize plugin.

=item *

Implement C<element_to_png> to render single elements
as PNG graphics.

=back

=head1 SEE ALSO

=over 4

=item *

The MozRepl FireFox plugin at L<http://wiki.github.com/bard/mozrepl>

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
L<http://github.com/Corion/www-mechanize-firefox>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2009 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
