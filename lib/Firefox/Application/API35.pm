package Firefox::Application::API35;
use strict;
use parent 'Firefox::Application';
use vars qw($VERSION);
$VERSION = '0.78';

=head1 NAME

Firefox::Application::API35 - API wrapper for Firefox 3.5+

=head1 SYNOPSIS

    use Firefox::Application;
    my $ff = Firefox::Application->new(
        # Force the Firefox 3.5 API
        api => 'Firefox::Application::API35',
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

sub addons {
    my $self = shift;
    $self->updateitems(type => 'ADDON', @_);
};

sub themes {
    my $self = shift;
    $self->updateitems(type => 'THEME', @_);
};

sub locales {
    my $self = shift;
    $self->updateitems(type => 'LOCALE', @_);
};

sub selectedTab {
    my ($self,%options) = @_;
    my $repl = delete $options{ repl } || $self->repl;
    return $self->browser( $repl )->{tabContainer}->{selectedItem};
}

sub addTab {
    my ($self, %options) = @_;
    my $repl = $options{ repl } || $self->repl;

    my $tab = $self->browser( $repl )->addTab();

    if (not exists $options{ autoclose } or $options{ autoclose }) {
        $self->autoclose_tab($tab)
    };
    
    $tab
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
                        sprintf qq{local-name(.)="%s"}, uc $_
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

Copyright 2009-2014 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
