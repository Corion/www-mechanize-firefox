package WWW::Mechanize::FireFox;
use strict;
use Time::HiRes;

use MozRepl::RemoteObject;
use URI;
use HTTP::Response;
use HTML::Selector::XPath 'selector_to_xpath';
use MIME::Base64;
use WWW::Mechanize::Link;
use Carp qw(croak);

use vars qw'$VERSION %link_tags';
$VERSION = '0.03';

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

sub new {
    my ($class, %args) = @_;
    my $loglevel = delete $args{ log } || [qw[ error ]];
    if (! $args{ repl }) {
        $args{ repl } = MozRepl::RemoteObject->install_bridge();
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
        $args{ tab } = $class->addTab( repl => $args{ repl });
        my $body = $args{ tab }->__dive(qw[ linkedBrowser contentWindow document body ]);
        $body->{innerHTML} = __PACKAGE__;
    }
    
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

    my $event = $self->synchronize(['DOMContentLoaded','error'], sub { # ,'abort'
        #'readystatechange'
        $b->loadURI($url);
    });
    
    # The event we get back is not necessarily indicative :-(
    # if ($event->{event} eq 'DOMContentLoaded') {
    
    return $self->response
};

# Should I port this to Perl?
# Should this become part of MozRepl::RemoteObject?
sub _addEventListener {
    my ($self,$browser,$events) = @_;
    $events ||= "DOMFrameContentLoaded";
    $events = [$events]
        unless ref $events;

    my $id = $browser->__id;
    
    my $rn = $self->repl->repl;
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
                // Copy the original JS event
                lock.js_event.target = e.target;
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
    my ($self,$element) = @_;
    # Now do the busy-wait
    my $s;
    while ((my $s = $element->{busy} || 0) < 1) {
        sleep 0.1;
    };
    return $element;
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

=cut

sub synchronize {
    my ($self,$events,$callback) = @_;
    
    $events = [ $events ]
        unless ref $events;
    
    my $b = $self->tab->{linkedBrowser};
    my $lock = $self->_addEventListener($b,$events);
    $callback->();
    $self->_wait_while_busy($lock);
};

=head2 C<< $mech->document >>

Returns the DOM document object.

This is WWW::Mechanize::FireFox specific.

=cut

sub document {
    my ($self) = @_;
    $self->tab->__dive(qw[linkedBrowser contentWindow document]);
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
    $self->synchronize('load', sub {
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

The objects are not yet as nice as L<WWW::Mechanize::Link>,
but they try to come close.

=cut

%link_tags = (
    a      => 'href',
    area   => 'href',
    frame  => 'src',
    iframe => 'src',
    link   => 'href',
    meta   => 'content',
);

sub links {
    my ($self) = @_;
    my @links = $self->selector('a,area,frame,iframe,link,meta');
    (my $base) = $self->selector('base');
    $base = $base->{href}
        if $base;
    $base ||= $self->uri;
    return map {
        my $tag = lc $_->{tagName};
        
        my $loc = $_->{ $link_tags{ $tag }};
        if (defined $loc) {
            my $url = URI->new_abs($loc,$base);
            WWW::Mechanize::Link->new({
                node  => $_,
                tag   =>  $tag,
                name  => $_->{name},
                base  => $base,
                url   => $url,
                text  => $_->{innerHTML},
                attrs => {},
            })
        } else {
            ()
        };
    } @links;
};

=head2 C<< $mech->click >>

Has the effect of clicking a button on the current form. The first argument is the name of the button to be clicked. The second and third arguments (optional) allow you to specify the (x,y) coordinates of the click.

If there is only one button on the form, $mech->click() with no arguments simply clicks that one button.

Returns a L<HTTP::Response> object.

=cut

sub click {
    my ($self,$name,$x,$y) = @_;
    $name = quotemeta $name;
    my @buttons = (
                   $self->xpath(sprintf q{//button[@name="%s"]}, $name),
                   $self->xpath(sprintf q{//input[(@type="button" or @type="submit") and @name="%s"]}, $name), 
                   $self->xpath(q{//button}),
                   $self->xpath(q{//input[(@type="button" or @type="submit")]}), 
                  );
    if (! @buttons) {
        croak "No button matching '$name' found";
    };
    my $event = $self->synchronize(['load','error'], sub { # ,'abort'
        $buttons[0]->__click();
    });
    return $self->response
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
    $self->document->__xpath($query, $options{ node });
};

=head2 C<< $mech->selector css_selector, %options >>

Returns all nodes matching the given CSS selector.

In the long run, this should go into a general plugin for
L<WWW::Mechanize>.

=cut

sub selector {
    my ($self,$query,%options) = @_;
    my $q = selector_to_xpath($query);
    return $self->xpath($q);
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

1;

__END__

=head1 INCOMPATIBILITIES WITH WWW::Mechanize

As this module is in a very early stage of development,
there are many incompatibilities. The main thing is
that only the most needed WWW::Mechanize methods
have been implemented by me so far.

=head2 Unsupported Methods

=over 4

=item *

C<< ->put >>

=item *

C<< ->follow_link >>

This is inconvenient and has high priority, for API compatibility.
Normally, you will want to C<< ->__click() >> on elements you find
instead.

=item *

C<< ->find_all_links >>

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

C<< ->set_visible >>

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

Spin off HTML::Display::MozRepl as soon as I find out how I can
load an arbitrary document via MozRepl into a C<document>.

This is mostly done, but not yet spun off.

=item *

Rip out parts of Test::HTML::Content and graft them
onto the C<links()> and C<find_link()> methods here.
FireFox is a conveniently unified XPath engine.

Preferrably, there should be a common API between the two.

=item *

Spin off XPath queries and CSS selectors into
their own Mechanize plugin.

=back

=head1 SEE ALSO

=over 4

=item *

The MozRepl FireFox plugin at L<http://wiki.github.com/bard/mozrepl>

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
