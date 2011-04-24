package Firefox::Application::API40;
use strict;
use vars qw($VERSION %addon_types);
use MozRepl::RemoteObject qw(as_list);
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
        #@res = as_list( $addons );
        @res = @$addons; # XXX slooow
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

=head2 C<< $ff->selectedTab( %options ) >>

    my $curr = $ff->selectedTab();

Sets the currently active tab.

=cut

sub selectedTab {
    my ($self,$repl) = @_;
    $repl ||= $self->repl;
    return $self->browser( $repl )->{selectedTab};
}


1;