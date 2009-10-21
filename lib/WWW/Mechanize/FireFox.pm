package WWW::Mechanize::FireFox;
use strict;
use Time::HiRes;

use MozRepl::RemoteObject;
use URI;

use vars '$VERSION';
$VERSION = '0.01';

# This should maybe become MozRepl::FireFox::Util?
# or MozRepl::FireFox::UI ?
sub openTabs {
    my ($self,$repl) = @_;
    $repl ||= $self->repl;
    my $rn = $repl->repl;
    my $tabs = MozRepl::RemoteObject::js_call_to_perl_struct(<<JS);
(function(repl) {
    var idx = 0;
    var tabs = [];

    Array.prototype.forEach.call(
        window.getBrowser().tabContainer.childNodes, 
        function(tab) {
            var d = tab.linkedBrowser.contentWindow.document;
            tabs.push(repl.link({
                location: d.location.href,
                document: d,
                title:    d.title,
                "id":     d.id,
                index:    idx++,
                panel:    tab.linkedPanel,
                tab:      tab,
            }));
        });
    return tabs;
})($rn)
JS
    MozRepl::RemoteObject->link_ids(@$tabs);
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
        my $repl_args = delete $args{ repl_args } || {
            client => {
                extra_client_args => {
                    binmode => 1,
                }
            },
            log => $loglevel,
            plugins => { plugins => [qw[ JSON2 ]] }, # I'm loading my own JSON serializer
        };
        $args{ repl } = MozRepl->new();
        $args{ repl }->setup( $repl_args );
        MozRepl::RemoteObject->install_bridge($args{ repl });
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
        #$args{ tab }->__release_action('');
        my $body = $args{ tab }->__dive(qw[ linkedBrowser contentWindow document body ]);
        $body->{innerHTML} = __PACKAGE__;
    }
    
    die "No tab found"
        unless $args{tab};
        
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
    my $rn = $repl->repl;
    my $tab = MozRepl::RemoteObject->expr(<<JS);
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

Gets the L<MozRepl> instance that is used.

This method is special to WWW::Mechanize::FireFox.

=cut

sub repl { $_[0]->{repl} };

=head2 C<< $mech->get(URL) >>

Retrieves the URL C<URL> into the tab.

Should return the status code.

=cut

sub get {
    my ($self,$url) = @_;
    my $b = $self->tab->{linkedBrowser};

    my $lock = $self->_addEventListener($b,'load');
    $b->loadURI(qq{"$url"});
    
    $self->_wait_while_busy($lock);
    
    if ($self->uri =~ /^about:/) {
        # this is an error
    };
    
    return 200; # ???
};

sub _addEventListener {
    my ($self,$browser,$event) = @_;
    # Ah, how nice it would be to have this callback based...
    #print "$_\n" for $browser->__keys();
    # Should this go into MozRepl::RemoteObject?
    
    $event ||= "load";

    my $id = $browser->__id;
    
    my $rn = $self->repl->repl;
    my $res = $self->repl->execute(<<JS);
(function(repl,browserid,event){
    var lock = {};
    lock.busy = 0;
    var b = repl.getLink(browserid);
    var l = function() {
        lock.busy++;
        b.removeEventListener(event,l,true);
    };
    b.addEventListener(event,l,true);
    return repl.link(lock)
})($rn,$id,"$event")
JS
    die $res if $res =~ s/^!!!//;

    (MozRepl::RemoteObject->link_ids($res))[0]
};

sub _wait_while_busy {
    my ($self,$element) = @_;
    # Now do the busy-wait
    my $s;
    while ((my $s = $element->{busy} || 0) < 1) {
        sleep 0.1;
    };
    return $s;
}

=head2 C<< $mech->synchronize( $event, $callback ) >>

Wraps a synchronization semaphore around the callback
and waits until the event C<$event> fires on the browser.

Usually, you want to use it like this:

  my $l = $mech->document->__xpath('//a[@onclick]');
  $mech->synchronize('load', sub {
      $l->__click()
  });

It is necessary to synchronize with the browser whenever
a click performs an action that takes longer and
fires an event on the browser object.

=cut

sub synchronize {
    my ($self,$event,$callback) = @_;
    
    my $b = $self->tab->{linkedBrowser};
    my $lock = $self->_addEventListener($b,$event);
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
    my $id = $d->__id;
    my $html = MozRepl::RemoteObject->expr(<<JS);
(function(repl,docid){
    var d = repl.getLink(docid);
    var e = d.createElement("div");
    e.appendChild(d.documentElement.cloneNode(true));
    return e.innerHTML;
})($rn,$id)
JS
};

=head2 C<< $mech->set_content $html >>

Writes C<$html> into the current document. This is mostly
implemented as a convenience method for L<HTML::Display::MozRepl>.

=cut

sub set_content {
    my ($self,$content) = @_;
    use MIME::Base64;
    my $data = encode_base64($content,'');
    my $url = qq{data:text/html;base64,$data};
    $self->synchronize('load', sub {
        $self->tab->{linkedBrowser}->loadURI(qq{"$url"});
    });
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

Returns all links, that is, all C<< <A >> elements
with an <c>href</c> attribute.

=cut

sub links {
    my ($self) = @_;
    my @links = $self->document->__xpath('//a[@href]');
    return map {
        die
    } @links;
};

=head2 C<< $mech->clickables >>

Returns all clickable elements, that is, all elements
with an <c>onclick</c> attribute.

=cut

sub clickables {
    my ($self) = @_;
    my @links = $self->document->__xpath('//*[@onclick]');
    return map {
        die
    } @links;
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

=head1 TODO

=over 4

=item *

Implement C<autodie>

=item *

Implement "reuse tab if exists, otherwise create new"

=item *

Spin off HTML::Display::MozRepl as soon as I find out how I can
load an arbitrary document via MozRepl into a C<document>.

=item *

Rip out parts of Test::HTML::Content and graft them
onto the C<links()> and C<find_link()> methods here.
FireFox is a conveniently unified XPath engine.

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
