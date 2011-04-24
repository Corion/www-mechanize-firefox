package Firefox::Application::API35;
use strict;
use parent 'Firefox::Application';
use vars qw($VERSION);
$VERSION = '0.51';

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


1;