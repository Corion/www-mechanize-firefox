package Firefox::Application::API40;
use strict;
use parent 'Firefox::Application';
use vars qw($VERSION %addon_types);
use MozRepl::RemoteObject qw(as_list);
$VERSION = '0.78';

=head1 NAME

Firefox::Application::API40 - API wrapper for Firefox 4+

=head1 SYNOPSIS

    use Firefox::Application;
    my $ff = Firefox::Application->new(
        # Force the Firefox 4 API
        api => 'Firefox::Application::API40',
    );

=head1 METHODS

=head2 C<< $api->updateitems( %args ) >>

  for my $item ($api->updateitems) {
      print sprintf "Name: %s\n", $item->{name};
      print sprintf "Version: %s\n", $item->{version};
      print sprintf "GUID: %s\n", $item->{id};
  };

Returns the list of updateable items. Under Firefox 4,
can be restricted by the C<type> option.

=over 4

=item * C<type> - type of items to fetch

C<ANY> - fetch any item

C<ADDON> - fetch extensions

C<LOCALE> - fetch locales

C<THEME> - fetch themes

=back

This method is asynchronous in Firefox 4, but is run
synchronously by Firefox::Application, polling every 0.1s.
Currently, no special support for AnyEvent is implemented.

=cut

%addon_types = (
    ADDON => 'extension',
    THEME => 'theme',
);

sub updateitems {
    my ($self, %options) = @_;
    my $repl = delete $options{ repl } || $self->repl;
    my $type = $options{type} || $options{ ANY };
    
    my $done;
    my @res;
    my $cb = sub {
        my ($addons) = @_;
        $done++; # This should be $cv->send ...
        @res = @$addons;
    };
    
    my $addons_js = $repl->declare(sprintf( <<'JS', $type), 'list');
    function(types,cb) {
        Components.utils.import("resource://gre/modules/AddonManager.jsm");
        AddonManager.getAddonsByTypes(types, cb);
        return 1;
   };
JS
    $addons_js->([$type], $cb);
    while (! $done) {
        # AnyEvent!
        $self->repl->poll;
    };
    @res
};

=head2 C<< $ff->addons( %args ) >>

  for my $addon ($ff->addons) {
      print sprintf "Name: %s\n", $addon->{name};
      print sprintf "Version: %s\n", $addon->{version};
      print sprintf "GUID: %s\n", $addon->{id};
  };

Returns the list of installed addons as C<Addon>s.
See <https://developer.mozilla.org/en/Addons/Add-on_Manager/Addon>
depending.

=cut

sub addons {
    my $self = shift;
    $self->updateitems(type => 'extension', @_);
};

sub themes {
    my $self = shift;
    $self->updateitems(type => 'theme', @_);
};

sub locales {
    my $self = shift;
    $self->updateitems(type => 'locale', @_);
};

=head2 C<< $ff->addTab( %options ) >>

    my $new = $ff->addTab();

Creates a new tab and returns it.
The tab will be automatically closed upon program exit.

The Firefox 4 API is asynchronous. The method is forced
into a synchronous call here.

=cut

sub addTab {
    my ($self, %options) = @_;
    my $repl = $options{ repl } || $self->repl;

    my $tab = $self->browser( $repl )->addTab();

    if (not exists $options{ autoclose } or $options{ autoclose }) {
        $self->autoclose_tab($tab)
    };
    
    $tab
};

sub closeTab {
    my ($self,$tab,$repl) = @_;
    $repl ||= $self->repl;
    my $close_tab = $repl->declare(<<'JS');
function(tab) {
          if(tab.collapsed) { return };
          var be = Components.classes["@mozilla.org/appshell/window-mediator;1"]
	                     .getService(Components.interfaces.nsIWindowMediator)
	                     .getEnumerator("navigator:browser");
	  while (be.hasMoreElements()) {
	    var browserWin = be.getNext();
	    var tabbrowser = browserWin.gBrowser;
	    if( tabbrowser ) {
	      for( var i=0; i< tabbrowser.tabs.length; i++) {
	          if( tabbrowser.tabs.item( i ) === tab ) {
                      tabbrowser.removeTab(tab);
                      break;
                  };
              };
	    };
          };
}
JS
    return $close_tab->($tab);
}

sub autoclose_tab {
    my ($self,$tab,$close) = @_;
    $close = 1
        if( 2 == @_ );
    my $release = join "\n",
          # Find the window our tab lives in
          q<if(!self.collapsed){>,
              q<var be = Components.classes["@mozilla.org/appshell/window-mediator;1"]>,
                                 q<.getService(Components.interfaces.nsIWindowMediator)>,
                                 q<.getEnumerator("navigator:browser");>,
              q<while (be.hasMoreElements()) {>,
                q<var browserWin = be.getNext();>,
                q<var tabbrowser = browserWin.gBrowser;>,
                q<if( tabbrowser ) {>,
                  q!for( var i=0; i< tabbrowser.tabs.length; i++) {!,
                      q<if( tabbrowser.tabs.item( i ) === self ) {>,
                          q<tabbrowser.removeTab(self);>,
                          q<break;>,
                      q<};>,
                  q<};>,
                q<};>,
              q<};>,
        q<};>,
    ;
    if( $close ) {
        $tab->__release_action($release);
    } else {
        $tab->__release_action('');
    };
};
=head2 C<< $ff->selectedTab( %options ) >>

    my $curr = $ff->selectedTab();

Sets the currently active tab.

=cut

sub selectedTab {
    my ($self,%options) = @_;
    my $repl = delete $options{ repl } || $self->repl;
    return $self->browser( $repl )->{selectedTab};
}

sub openTabs {
    my ($self,$repl) = @_;
    $repl ||= $self->repl;
    my $open_tabs = $repl->declare(<<'JS', 'list');
function() {
    var idx = 0;
    var tabs = [];
    
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                       .getService(Components.interfaces.nsIWindowMediator);
    var en = wm.getEnumerator('navigator:browser');
    while( en.hasMoreElements() ) {
        var win= en.getNext();
        var tabbrowser = win.gBrowser;
        var numTabs = tabbrowser.browsers.length;
        for (var index = 0; index < numTabs; index++) {
            var tab = tabbrowser.tabContainer.childNodes[index];
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
        };
    };

    return tabs;
}
JS
    $open_tabs->();
}

=head2 C<< $api->element_query( \@elements, \%attributes ) >>

    my $query = $element_query(['input', 'select', 'textarea'],
                               { name => 'foo' });

Returns the XPath query that searches for all elements with C<tagName>s
in C<@elements> having the attributes C<%attributes>. The C<@elements>
will form an C<or> condition, while the attributes will form an C<and>
condition.

=cut

sub element_query {
    my ($self, $elements, $attributes) = @_;
        my $query = 
            './/*[(' . 
                join( ' or ',
                    map {
                        sprintf qq{local-name(.)="%s"}, lc $_
                    } @$elements
                )
            . ') and '
            . join( " and ",
                map { sprintf q{@%s="%s"}, $_, $attributes->{$_} }
                  sort keys(%$attributes)
            )
            . ']';
};

1;

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2009-2013 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
