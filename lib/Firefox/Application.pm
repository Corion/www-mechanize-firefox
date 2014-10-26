package Firefox::Application;
use strict;

use MozRepl::RemoteObject ();
use URI ();
use Carp qw(carp croak);

use vars qw'$VERSION';
$VERSION = '0.78';

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

=item *

C<api> - class for the API wrapper

You almost never want to use this parameter, as Firefox::Application
asks Firefox about its version.

=back

=cut

sub new {
    my ($class, %args) = @_;
    my $loglevel = delete $args{ log } || [qw[ error ]];
    my $use_queue = exists $args{ use_queue } ? delete $args{ use_queue } : 1;
    my $api = delete $args{ api };
    if (! ref $args{ repl }) {
        my @passthrough = qw(repl js_JSON launch);
        my %options = map { exists $args{ $_ } ? ($_ => delete $args{ $_ }) : () } 
                      @passthrough;
        $args{ repl } = MozRepl::RemoteObject->install_bridge(
            log => $loglevel,
            use_queue => $use_queue,
            bufsize => delete $args{ bufsize },
            %options,
        );
    };
    
    # Now install the proper API
    if (! $api) {
        my $info = $args{ repl }->appinfo;
        my $v = $info->{version};
        $v =~ s!^(\d+.\d+).*!$1!
            or $v = '3.0'; # Wild guess
         
        if ($v >= 4) {
            $api = 'Firefox::Application::API40';
        } elsif ($v >= 3.6) {
            $api = 'Firefox::Application::API36';
        } else {
            $api = 'Firefox::Application::API35';
        };
    };
    MozRepl::RemoteObject::require_module( $api );
    
    bless \%args, $api;
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

Returns the list of installed addons as C<nsIUpdateItem>s (FF 3.5+)
or C<Addon>s (FF4+).
See L<https://developer.mozilla.org/en/XPCOM_Interface_Reference/nsIUpdateItem>
or L<https://developer.mozilla.org/en/Addons/Add-on_Manager/Addon>,
depending on your Firefox version.

=head2 C<< $ff->locales( %args ) >>

  for my $locale ($ff->locales) {
      print sprintf "Name: %s\n", $locale->{name};
      print sprintf "Version: %s\n", $locale->{version};
      print sprintf "GUID: %s\n", $locale->{id};
  };

Returns the list of installed locales as C<nsIUpdateItem>s.

=head2 C<< $ff->themes( %args ) >>

  for my $theme ($ff->themes) {
      print sprintf "Name: %s\n", $theme->{name};
      print sprintf "Version: %s\n", $theme->{version};
      print sprintf "GUID: %s\n", $theme->{id};
  };

Returns the list of installed locales as C<nsIUpdateItem>s.

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

sub profileService {
    my ($self) = @_;
    
    my $profileService = $self->repl->declare(<<'JS')->();
        function () {
            return Components.classes["@mozilla.org/toolkit/profile-service;1"]
                   .createInstance(Components.interfaces.nsIToolkitProfileService);
        }
JS
}

=head2 C<< $ff->current_profile >>

    print $ff->current_profile->{name}, "\n";

Returns currently selected profile as C<nsIToolkitProfile>.

See L<https://developer.mozilla.org/en/XPCOM_Interface_Reference/nsIToolkitProfile>.

=cut

sub current_profile {
    my ($self) = @_;
    $self->profileService->{selectedProfile}
}

=head2 C<< $ff->find_profile( $name ) >>

    print $ff->find_profile("")->{localDir}, "\n";

Returns the profile given its name. Dies
if the profile cannot be found.

=cut

sub find_profile {
    my ($self,$name) = @_;
    $self->profileService->getProfileByName($name);
}

=head2 C<< $ff->profiles >>

    for ($ff->profiles) {
        print "Profile: ", $_->{name}, "\n";
    }

Lists the installed profiles as C<nsIToolkitProfile>s.

See L<https://developer.mozilla.org/en/XPCOM_Interface_Reference/nsIToolkitProfile>.

=cut

sub profiles {
    my ($self) = @_;
    
    my $getProfiles = $self->repl->declare(<<'JS', 'list');
        function () {
            var toolkitProfileService = Components.classes["@mozilla.org/toolkit/profile-service;1"]
                            .createInstance(Components.interfaces.nsIToolkitProfileService);
            var res = new Array;
            var i = toolkitProfileService.profiles;
            while( i.hasMoreElements() ) {
                res.push( i.getNext() );
            };
            return res
        }
JS
    $getProfiles->()
}

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

=head2 C<< $ff->selectedTab( %options ) >>

    my $curr = $ff->selectedTab();

Sets the currently active tab.

=cut


=head2 C<< $ff->closeTab( $tab [,$repl] ) >>

    $ff->closeTab( $tab );

Close the given tab.

=cut

=head2 C<< $ff->openTabs( [$repl] ) >>

    my @tab_info = $ff->openTabs();
    print "$_->{title}, $_->{location}, \n"
        for @tab_info;

Returns a list of information about the currently open tabs.

=cut


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
        return win.gBrowser
        // return win.getBrowser()
    }
JS
};

=head2 C<< $ff->getMostRecentWindow >>

Returns the most recently used Firefox window.

=cut

sub getMostRecentWindow {
    my ($self) = @_;
    my $get = $self->repl->declare(<<'JS');
    function() {
        var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                           .getService(Components.interfaces.nsIWindowMediator);
        return wm.getMostRecentWindow('navigator:browser');
    }
JS
    return $get->()
};

=head2 C<< $ff->set_tab_content( $tab, $html [,$repl] ) >>

    $ff->set_tab_content('<html><h1>Hello</h1></html>');

This is a more general method that allows you to replace
the HTML of an arbitrary tab, and not only the tab that
WWW::Mechanize::Firefox is associated with.

It has the flaw of not waiting until the tab has
loaded.

=cut

sub set_tab_content {
    my ($self, $tab, $content, $repl) = @_;
    my $url = URI->new('data:');
    $url->media_type("text/html");
    $url->data($content);
    
    $tab ||= $self->tab;
    $repl ||= $self->repl;
    
    $tab->{linkedBrowser}->loadURI("".$url);
};

=head2 C<< $ff->quit( %options ) >>

  $ff->quit( restart => 1 ); # restart
  $ff->quit(); # quit

Quits or restarts the application

=cut

sub quit {
    my ($self, %options) = @_;
    my $repl = $options{ repl } || $self->repl;
    my $flags = $options{ restart }
              ? 0x13 # force-quit
              : 0x03 # force-quit + restart
              ;
    
    my $get_startup = $repl->declare(<<'JS');
    function() {
        return Components.classes["@mozilla.org/toolkit/app-startup;1"]
                     .getService(Components.interfaces.nsIAppStartup);
    }
JS
    my $s = $get_startup->();
    $s->quit($flags);
};

=head2 C<< $ff->bool_ff_to_perl $val >>

Normalizes the (checkbox) truth value C<$val> to 1 or 0.

Different Firefox versions return C<true> or C<false>
as the checkbox values. This function converts
a Firefox checkbox value to 1 or 0.

=cut

# FF 31 has 1,0
sub bool_ff_to_perl {
    my( $self, $value )= @_;
    $value
}

=head2 C<< $ff->bool_perl_to_ff $val >>

Normalizes the truth value C<$val> to 1 or 0.

Different Firefox versions want C<true> or C<false>
as the checkbox values. This function converts
a Perl truth value to 1 or 0 respectively C<true> or C<false>,
depending on what Firefox wants.

=cut

# FF 31 has 1,0
sub bool_perl_to_ff {
    my( $self, $value )= @_;
    $value ? 1 : 0
}

=head1 TODO

=over 4

=item *

Consider how to roll L<http://kb.mozillazine.org/Command_line_arguments>
into this module for convenient / versatile launching of Firefox

=back

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2009-2013 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;