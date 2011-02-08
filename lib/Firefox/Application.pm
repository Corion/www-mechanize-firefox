package Firefox::Application;
use strict;

use MozRepl::RemoteObject;
use MIME::Base64;
use Carp qw(carp croak);

use vars qw'$VERSION';
$VERSION = '0.45';

=head1 NAME

Firefox::Application - inspect and automate the Firefox UI

=head1 SYNOPSIS

  use Firefox::Application;
  my $ff = Firefox::Application->new();

This module will let you automate Firefox through the
Mozrepl plugin. You need to have installed
that plugin in your Firefox.

For more examples see L<WWW::Mechanize::Firefox::Examples>.

=head1 METHODS

=head2 C<< Firefox::Application->new( %args ) >>

  use Firefox::Application;
  my $ff = Firefox::Application->new();

Creates a new instance and connects it to Firefox.

Note that Firefox must have the C<mozrepl>
extension installed and enabled.

The following options are recognized:

=over 4

=item * 

C<launch> - name of the program to launch if we can't connect to it on
the first try.

=item * 

C<log> - array reference to log levels, passed through to L<MozRepl::RemoteObject>

=item *

C<bufsize> - L<Net::Telnet> buffer size, if the default of 1MB is not enough

=item * 

C<repl> - a premade L<MozRepl::RemoteObject> instance or a connection string
suitable for initializing one.

=item * 

C<use_queue> - whether to enable L<MozRepl::RemoteObject> command queueing

=back

=cut

sub new {
    my ($class, %args) = @_;
    my $loglevel = delete $args{ log } || [qw[ error ]];
    my $use_queue = exists $args{ use_queue } ? delete $args{ use_queue } : 1;
    if (! ref $args{ repl }) {
        my $exe = delete $args{ launch };
        $args{ repl } = MozRepl::RemoteObject->install_bridge(
            repl   => $args{ repl } || undef,
            launch => $exe,
            log => $loglevel,
            use_queue => $use_queue,
        );
    };
    
    if (my $bufsize = delete $args{ bufsize }) {
        $args{ repl }->repl->client->telnet->max_buffer_length($bufsize);
    };
        
    bless \%args, $class;
};

sub DESTROY {
    my ($self) = @_;
    local $@;
    #warn "App cleaning up";
    if (my $repl = delete $self->{ repl }) {
        %$self = (); # wipe out all references we keep
        # but keep $repl alive until we can dispose of it
        # as the last thing, now:
        $repl = undef;
    };
    #warn "App cleaned up";
}

=head2 C<< $ff->repl >>

  my ($value,$type) = $ff->repl->expr('2+2');

Gets the L<MozRepl::RemoteObject> instance that is used.

=cut

sub repl { $_[0]->{repl} };

=head1 APPLICATION INFORMATION

=cut

=head2 C<< $ff->appinfo >>

    my $info = $ff->appinfo;
    print 'ID      : ', $info->{ID};
    print 'name    : ', $info->{name};
    print 'version : ', $info->{version};

Returns information about Firefox.

=cut

sub appinfo {
    $_[0]->repl->appinfo
};

=head2 C<< $ff->addons( %args ) >>

  for my $addon ($ff->addons) {
      print sprintf "Name: %s\n", $addon->{name};
      print sprintf "Version: %s\n", $addon->{version};
      print sprintf "GUID: %s\n", $addon->{id};
  };

Returns the list of installed addons as C<nsIUpdateItem>s.
See L<https://developer.mozilla.org/en/XPCOM_Interface_Reference/nsIUpdateItem>.

These functions will need fixing for Firefox 4.

=cut

sub addons {
    my $self = shift;
    $self->updateitems(type => 'ADDON', @_);
};

=head2 C<< $ff->locales( %args ) >>

  for my $locale ($ff->locales) {
      print sprintf "Name: %s\n", $locale->{name};
      print sprintf "Version: %s\n", $locale->{version};
      print sprintf "GUID: %s\n", $locale->{id};
  };

Returns the list of installed locales as C<nsIUpdateItem>s.

=cut

sub locales {
    my $self = shift;
    $self->updateitems(type => 'LOCALE', @_);
};

=head2 C<< $ff->themes( %args ) >>

  for my $theme ($ff->themes) {
      print sprintf "Name: %s\n", $theme->{name};
      print sprintf "Version: %s\n", $theme->{version};
      print sprintf "GUID: %s\n", $theme->{id};
  };

Returns the list of installed locales as C<nsIUpdateItem>s.

=cut

sub themes {
    my $self = shift;
    $self->updateitems(type => 'THEME', @_);
};

=head2 C<< $ff->updateitems( %args ) >>

  for my $item ($ff->updateitems) {
      print sprintf "Name: %s\n", $item->{name};
      print sprintf "Version: %s\n", $item->{version};
      print sprintf "GUID: %s\n", $item->{id};
  };

Returns the list of updateable items. The type of item
can be restricted by the C<type> option.

=over 4

=item * C<type> - type of items to fetch

C<ANY> - fetch any item

C<ADDON> - fetch add-ons

C<LOCALE> - fetch locales

C<THEME> - fetch themes

=back

=cut
sub updateitems {
    my ($self, %options) = @_;
    my $repl = delete $options{ repl } || $self->repl;
    my $type = $options{type} || 'ANY';
    my $addons_js = $repl->declare(sprintf( <<'JS', $type), 'list');
    function () {
        var em = Components.classes["@mozilla.org/extensions/manager;1"]
                    .getService(Components.interfaces.nsIExtensionManager);
        var type = Components.interfaces.nsIUpdateItem.TYPE_%s;
        var count = {};
        var list = em.getItemList(type, count);
        return list
   };
JS
    $addons_js->()
};

=head1 UI METHODS

=head2 C<< $ff->addTab( %options ) >>

    my $new = $ff->addTab();

Creates a new tab and returns it.
The tab will be automatically closed upon program exit.

If you want the tab to remain open, pass a false value to the the C< autoclose >
option.

The recognized options are:

=over 4

=item *

C<repl> - the repl to use. By default it will use C<< $ff->repl >>.

=item *

C<autoclose> - whether to automatically close the tab at program exit. Default is
to close the tab.

=back

=cut

sub addTab {
    my ($self, %options) = @_;
    my $repl = $options{ repl } || $self->repl;
    my $rn = $repl->name;

    my $tab = $self->browser( $repl )->addTab;

    if (not exists $options{ autoclose } or $options{ autoclose }) {
        $self->autoclose_tab($tab)
    };
    
    $tab
};

=head2 C<< $ff->addTab( %options ) >>

    my $curr = $ff->selectedTab();

Returns the currently active tab.

=cut

sub selectedTab {
    my ($self,$repl) = @_;
    $repl ||= $self->repl;
    return $self->browser( $repl )->{tabContainer}->{selectedItem};
}

=head2 C<< $ff->closeTab( $tab [,$repl] ) >>

    $ff->closeTab( $tab );

Close the given tab.

=cut

sub closeTab {
    my ($self,$tab,$repl) = @_;
    $repl ||= $self->repl;
    my $close_tab = $repl->declare(<<'JS');
function(tab) {
    // find containing browser
    var p = tab.parentNode;
    while (p.tagName != "tabbrowser") {
        p = p.parentNode;
    };
    if(p){p.removeTab(tab)};
}
JS
    return $close_tab->($tab);
}

=head2 C<< $ff->openTabs( [$repl] ) >>

    my @tab_info = $ff->openTabs();
    print "$_->{title}, $_->{location}, \n"
        for @tab_info;

Returns a list of information about the currently open tabs.

=cut

sub openTabs {
    my ($self,$repl) = @_;
    $repl ||= $self->repl;
    my $open_tabs = $repl->declare(<<'JS', 'list');
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
    $open_tabs->();
}

=head2 C<< $ff->activateTab( [ $tab [, $repl ]] ) >>

    $ff->activateTab( $mytab ); # bring to foreground
    
Activates the tab passed in.

=cut

sub activateTab {
    my ($self, $tab, $repl ) = @_;
    $repl ||= $self->repl;
    croak "No tab given"
        unless $tab;
    $self->browser( $repl )->{tabContainer}->{selectedItem} = $tab;
};

=head2 C<< $ff->browser( [$repl] ) >>

    my $b = $ff->browser();

Returns the current Firefox browser instance, or opens a new browser
window if none is available, and returns its browser instance.

If you need to call this as a class method, pass in the L<MozRepl::RemoteObject>
bridge to use.

=cut

sub browser {
    my ($self,$repl) = @_;
    $repl ||= $self->repl;
    return $repl->declare(<<'JS')->();
    function() {
        var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                           .getService(Components.interfaces.nsIWindowMediator);
        var win = wm.getMostRecentWindow('navigator:browser');
        if (! win) {
          // No browser windows are open, so open a new one.
          win = window.open('about:blank');
        };
        return win.getBrowser()
    }
JS
};

sub autoclose_tab {
    my ($self,$tab) = @_;
    my $release = join "",
        q<var p=self.parentNode;>,
        q<while(p && p.tagName != "tabbrowser") {>,
            q<p = p.parentNode>,
        q<};>,
        q<if(p){p.removeTab(self)};>,
    ;
    $tab->__release_action($release);
};

=head2 C<< $ff->set_tab_content( $tab, $html [,$repl] ) >>

    $ff->set_tab_content('<html><h1>Hello</h1></html>');

This is a more general method that allows you to replace
the HTML of an arbitrary tab, and not only the tab that
WWW::Mechanize::Firefox is associated with.

=cut

sub set_tab_content {
    my ($self, $tab, $content, $repl) = @_;
    $tab ||= $self->tab;
    $repl ||= $self->repl;
    my $data = encode_base64($content,'');
    my $url = qq{data:text/html;base64,$data};
    $tab->{linkedBrowser}->loadURI($url);
};

=head1 TODO

=over 4

=item *

Consider how to roll L<http://kb.mozillazine.org/Command_line_arguments>
into this module for convenient / versatile launching of Firefox

=back

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2009-2011 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;