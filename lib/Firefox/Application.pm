package Firefox::Application;
use 5.006; #weaken
use strict;

use MozRepl::RemoteObject;
use URI;
use Cwd;
use File::Basename;
use WWW::Mechanize::Link;
use Scalar::Util qw'blessed weaken';
use Carp qw(carp croak);

use vars qw'$VERSION';
$VERSION = '0.39';

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

=back

=cut

sub new {
    my ($class, %args) = @_;
    my $loglevel = delete $args{ log } || [qw[ error ]];
    if (! ref $args{ repl }) {
        my $exe = delete $args{ launch };
        $args{ repl } = MozRepl::RemoteObject->install_bridge(
            repl   => $args{ repl } || undef,
            launch => $exe,
            log => $loglevel,
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
    if (my $repl = delete $self->{ repl }) {
        undef $self->{tab};
        %$self = (); # wipe out all references we keep
        # but keep $repl alive until we can dispose of it
        # as the last thing, now:
        $repl = undef;
    };
}

=head2 C<< $ff->repl >>

  my ($value,$type) = $ff->repl->expr('2+2');

Gets the L<MozRepl::RemoteObject> instance that is used.

=cut

sub repl { $_[0]->{repl} };

=head2 C<< $ff->addons( %args ) >>

  for my $addon ($ff->addons) {
      print sprintf "Name: %s\n", $addon->{name};
      print sprintf "Version: %s\n", $addon->{version};
      print sprintf "GUID: %s\n", $addon->{id};
  };

Returns the list of installed addons as C<nsIUpdateItem>s.
See L<http://www.oxymoronical.com/experiments/apidocs/interface/nsIUpdateItem>

=cut

sub addons {
    my ($self, %options) = @_;
    my $repl = delete $options{ repl } || $self->repl;
    # XXX make type a parameter
    my $addons_js = $repl->declare(<<'JS');
    function () {
        var em = Components.classes["@mozilla.org/extensions/manager;1"]
                    .getService(Components.interfaces.nsIExtensionManager);
        var type = Components.interfaces.nsIUpdateItem.TYPE_EXTENSION;
        var count = {};
        var list = em.getItemList(type, count);
        return list
   };
JS
    @{ $addons_js->() };
};

=head1 UI METHODS

=head2 C<< $mech->addTab( %options ) >>

    my $new = $mech->addTab();

Creates a new tab and returns it.
The tab will be automatically closed upon program exit.

If you want the tab to remain open, pass a false value to the the C< autoclose >
option.

The recognized options are:

=over 4

=item *

C<repl> - the repl to use. By default it will use C<< $mech->repl >>.

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

=head2 C<< $mech->addTab( %options ) >>

    my $curr = $mech->selectedTab();

Returns the currently active tab.

=cut

sub selectedTab {
    my ($self,$repl) = @_;
    $repl ||= $self->repl;
    return $self->browser( $repl )->{tabContainer}->{selectedItem};
}

=head2 C<< $mech->closeTab( $tab [,$repl] ) >>

    $mech->closeTab( $tab );

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

=head2 C<< $mech->openTabs( [$repl] ) >>

    my @tab_info = $mech->openTabs();
    print "$_->{title}, $_->{location}, \n"
        for @tab_info;

Returns a list of information about the currently open tabs.

=cut

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

=head2 C<< $mech->activateTab( [ $tab [, $repl ]] ) >>

    $mech->activateTab( $mytab ); # bring to foreground
    
Activates the tab passed in. The tab defaults to the tab associated
with the C<$mech> object.

=cut

sub activateTab {
    my ($self, $tab, $repl ) = @_;
    $tab ||= $self->tab;
    $repl ||= $self->repl;
    #$self->browser( $repl )->{selectedItem} = $tab;
    $self->browser( $repl )->{tabContainer}->{selectedItem} = $tab;
};


1;