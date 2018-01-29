package Firefox::Application;
use strict;
use Moo 2;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

use URI ();
use Carp qw(carp croak);
use IO::Socket::INET;

use Future;

our $VERSION = '1.00';

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

Note that Firefox must be version 57 or higher to support the
Marionette protocol.

The following options are recognized:

=over 4

=item * 

C<launch_exe> - name of the program to launch if we can't connect to it on
the first try.

=item *

C<api> - class for the API wrapper

You almost never want to use this parameter, as Firefox::Application
asks Firefox about its version.

=back

=cut

has host => (
    is => 'ro',
    default => 'localhost',
);

has port => (
    is => 'ro',
    default => '2828',
);

has transport => (
    is => 'lazy',
    default => sub {
        Firefox::Marionette::Transport->new();
    },
);

sub connect( $self ) {
    $self->transport->connect(
        host => $self->host,
        port => $self->port,
    );
}

sub DESTROY {
    my ($self) = @_;
    local $@;
    #warn "App cleaning up";
    if (my $transport = delete $self->{transport} ) {
        $transport->close
    };
}

sub build_command_line {
    my( $class, $options )= @_;

    # Firefox.exe on Windows
    # firefox-bin on Linux (etc?)
    my $default_exe = $^O =~ /mswin/i ? 'firefox'
                                      : 'firefox-bin';

    $options->{ launch_exe } ||= $ENV{FIREFOX_BIN} || $default_exe;
    $options->{ launch_arg } ||= [];

    # See also https://github.com/mozilla/geckodriver/issues/1058
    unshift @{ $options{ launch_arg }, '-marionette';
    $options->{port} ||= 2828
        if ! exists $options->{port};
    unshift @{ $options{ launch_arg }, '-marionette-port', $options->{port};
        
    # See also https://support.mozilla.org/questions/1092082
    if ($options->{incognito}) {
        push @{ $options->{ launch_arg }}, "-private";
    };

    if ($options->{data_directory}) {
        croak "Data directory option is not yet supported";
        push @{ $options->{ launch_arg }}, "--user-data-dir=$options->{ data_directory }";
    };

    if ($options->{profile}) {
        croak "Profile directory option is not yet supported";
        push @{ $options->{ launch_arg }}, "--profile-directory=$options->{ profile }";
    };

    #if( ! exists $options->{enable_first_run}) {
    #    push @{ $options->{ launch_arg }}, "--no-first-run";
    #};

    push @{ $options->{ launch_arg }}, "-headless"
        if $options->{ headless };

    push @{ $options->{ launch_arg }}, "$options->{start_url}"
        if exists $options->{start_url};

    my $program = ($^O =~ /mswin/i and $options->{ launch_exe } =~ /\s/)
                  ? qq("$options->{ launch_exe }")
                  : $options->{ launch_exe };

    my @cmd=( $program, @{ $options->{launch_arg}} );

    @cmd
};

sub _find_free_port( $self, $start ) {
    my $port = $start;
    while (1) {
        $port++, next unless IO::Socket::INET->new(
            Listen    => 5,
            Proto     => 'tcp',
            Reuse     => 1,
            LocalPort => $port
        );
        last;
    }
    $port;
}

sub _wait_for_socket_connection( $self, $host, $port, $timeout ) {
    my $wait = time + ($timeout || 20);
    while ( time < $wait ) {
        my $t = time;
        my $socket = IO::Socket::INET->new(
            PeerHost => $host,
            PeerPort => $port,
            Proto    => 'tcp',
        );
        if( $socket ) {
            close $socket;
            sleep 1;
            last;
        };
        sleep 1 if time - $t < 1;
    }
};

sub spawn_child_win32( $self, @cmd ) {
    system(1, @cmd)
}

sub spawn_child_posix( $self, @cmd ) {
    require POSIX;
    POSIX->import("setsid");

    # daemonize
    defined(my $pid = fork())   || die "can't fork: $!";
    if( $pid ) {    # non-zero now means I am the parent
        $self->log('debug', "Spawned child as $pid");
        return $pid;
    };
    chdir("/")                  || die "can't chdir to /: $!";

    # We are the child, close about everything, then exec
    (setsid() != -1)            || die "Can't start a new session: $!";
    open(STDERR, ">&STDOUT")    || die "can't dup stdout: $!";
    open(STDIN,  "< /dev/null") || die "can't read /dev/null: $!";
    open(STDOUT, "> /dev/null") || die "can't write to /dev/null: $!";
    exec @cmd;
}

sub spawn_child( $self, $localhost, @cmd ) {
    my ($pid);
    if( $^O =~ /mswin/i ) {
        $pid = $self->spawn_child_win32(@cmd)
    } else {
        $pid = $self->spawn_child_posix(@cmd)
    };

    # Just to give Firefox time to start up, make sure it accepts connections
    $self->_wait_for_socket_connection( $localhost, $self->port, $self->startup_timeout || 20);
    return $pid
}

sub new($class, %options) {

    if (! exists $options{ autodie }) {
        $options{ autodie } = 1
    };

    if( ! exists $options{ frames }) {
        $options{ frames }= 1;
    };

    if( ! exists $options{ download_directory }) {
        $options{ download_directory }= '';
    };

    $options{ js_events } ||= [];
    if( ! exists $options{ transport }) {
        $options{ transport } ||= $ENV{ WWW_MECHANIZE_FIREFOX_TRANSPORT };
    };

    my $self= bless \%options => $class;
    my $host = $options{ host } || '127.0.0.1';
    $self->{log} ||= $self->_build_log;

    $options{start_url} = 'about:blank'
        unless exists $options{start_url};

    unless ( defined $options{ port } ) {
        # Find free port
        $options{ port } = $self->_find_free_port( 2828 );
    }

    unless ($options{pid} or $options{reuse}) {
        my @cmd= $class->build_command_line( \%options );
        $self->log('debug', "Spawning", \@cmd);
        $self->{pid} = $self->spawn_child( $host, @cmd );
        $self->{ kill_pid } = 1;

        # Just to give Firefox time to start up, make sure it accepts connections
        $self->_wait_for_socket_connection( $host, $self->{port}, $self->{startup_timeout} || 20);
    }

    if( $options{ tab } and $options{ tab } eq 'current' ) {
        $options{ tab } = 0; # use tab at index 0
    };

    $options{ extra_headers } ||= {};

    # Connect to it
    $options{ driver } ||= Firefox::Marionette::Driver->new(
        'port' => $options{ port },
        host => $host,
        auto_close => 0,
        error_handler => sub {
            #warn ref$_[0];
            #warn "<<@CARP_NOT>>";
            #warn ((caller($_))[0,1,2])
            #    for 1..4;
            local @CARP_NOT = (@CARP_NOT, ref $_[0],'Try::Tiny');
            # Reraise the error
            croak $_[1]
        },
        transport => $options{ transport },
        log       => $options{ log },
    );
    # Synchronously connect here, just for easy API compatibility

    my $err;
    $self->driver->connect(
        new_tab => !$options{ reuse },
        tab     => $options{ tab },
    )->catch( sub($_err) {
        $err = $_err;
        Future->done( $err );
    })->get;

    # if Firefox started, but so slow or unresponsive that we cannot connect
    # to it, kill it manually to avoid waiting for it indefinitely
    if ( $err ) {
        if( $self->{ kill_pid } and my $pid = delete $self->{ pid }) {
            local $SIG{CHLD} = 'IGNORE';
            kill 'SIGKILL' => $pid;
        };
        die $err;
    };
    
    # Query / setup FF capabilities

    $self
};

=head2 C<< $ff->transport >>

Gets the L<Firefox::Marionette::Transport> instance that is used.

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
    #$_[0]->repl->appinfo
};

=head2 C<< $ff->current_profile >>

    print $ff->current_profile->{name}, "\n";

Returns currently selected profile as C<nsIToolkitProfile>.

See L<https://developer.mozilla.org/en/XPCOM_Interface_Reference/nsIToolkitProfile>.

=cut

sub current_profile {
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