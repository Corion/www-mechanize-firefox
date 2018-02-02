package Firefox::Application;
use strict;
use Moo 2;

use File::Temp 'tempdir';

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

use URI ();
use Carp qw(carp croak);
use IO::Socket::INET;
use Data::Dumper;
use Scalar::Util 'weaken';

use Firefox::Marionette::Driver;

use Future;

our $VERSION = '1.00';
our @CARP_NOT;

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

has driver => (
    is => 'lazy',
    default => sub {
        Firefox::Marionette::Driver->new();
    },
);

has pid => (
    is => 'ro',
);

has kill_pid => (
    is => 'rw',
);

has '_log' => (
    is => 'lazy',
    default => \&_build_log,
);

has '_have_info' => (
    is => 'lazy',
    default => sub { Future->new() },
);

sub _build_log( $self ) {
    require Log::Log4perl;
    Log::Log4perl->get_logger(__PACKAGE__);
}

sub log( $self, $level, $message, @args ) {
    my $logger = $self->_log;
    if( !@args ) {
        $logger->$level( $message )
    } else {
        my $enabled = "is_$level";
        $logger->$level( join " ", $message, Dumper @args )
            if( $logger->$enabled );
    };
}

sub DESTROY {
    if( $_[0]->{driver}) {
        $_[0]->quit->get
    }
}

sub build_command_line {
    my( $class, $options )= @_;

    # Firefox.exe on Windows
    # firefox-bin on Linux (etc?)
    my $default_exe = $^O =~ /mswin/i ? 'firefox'
                                      : 'firefox-bin';

    $options->{ launch_exe } ||= $ENV{FIREFOX_BIN} || $default_exe;
    $options->{ launch_arg } ||= ['--no-remote','-profile', tempdir(CLEANUP => 1)];

    # We want a disconnected separate FF here
    unshift @{ $options->{ launch_arg }}, '--no-remote','--new-instance';

    # See also https://github.com/mozilla/geckodriver/issues/1058
    unshift @{ $options->{ launch_arg }}, '-marionette';
    $options->{port} ||= 2828
        if ! exists $options->{port};
    unshift @{ $options->{ launch_arg }}, '-marionette-port', $options->{port};

    # See also https://support.mozilla.org/questions/1092082
    if ($options->{incognito}) {
        push @{ $options->{ launch_arg }}, "-private";
    };

    if ($options->{data_directory}) {
        croak "Data directory option is not yet supported";
        push @{ $options->{ launch_arg }}, "--user-data-dir=$options->{ data_directory }";
    };

    if ($options->{profile}) {
        # Let's assume a profile directory, not a Firefox::Marionette::Profile
        push @{ $options->{ launch_arg }}, "-profile", $options->{profile};
    };

    #if( ! exists $options->{enable_first_run}) {
    #    push @{ $options->{ launch_arg }}, "--no-first-run";
    #};

    push @{ $options->{ launch_arg }}, "-headless"
        if $options->{ headless };

    push @{ $options->{ launch_arg }}, "-private"
        if $options->{ private };

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

sub spawn_child( $self, %options ) {
    my ($pid);
    if( $^O =~ /mswin/i ) {
        $pid = $self->spawn_child_win32(@{ $options{ cmd }})
    } else {
        $pid = $self->spawn_child_posix(@{ $options{ cmd }})
    };

    my $host = $options{ host };
    # Just to give Firefox time to start up, make sure it accepts connections
    $self->_wait_for_socket_connection( $host, $options{ port }, $options{ startup_timeout } || 20);
    return $pid
}

around BUILDARGS => sub ( $orig, $class, %options) {

    if (! exists $options{ autodie }) {
        $options{ autodie } = 1
    };

    if( ! exists $options{ frames }) {
        $options{ frames }= 1;
    };

    if( ! exists $options{ download_directory }) {
        $options{ download_directory }= '';
    };

    #$options{ js_events } ||= [];
    if( ! exists $options{ transport }) {
        $options{ transport } ||= $ENV{ WWW_MECHANIZE_FIREFOX_TRANSPORT };
    };

    my $host = $options{ host } || '127.0.0.1';

    $options{start_url} = 'about:blank'
        unless exists $options{start_url};

    unless ( defined $options{ port } ) {
        # Find free port
        $options{ port } = $class->_find_free_port( 2828 );
    }

    $options{ extra_headers } ||= {};

    unless ($options{pid} or $options{reuse}) {
        my @cmd= $class->build_command_line( \%options );
        #$self->log('debug', "Spawning", \@cmd);
        $options{pid} = $class->spawn_child( host => $host, port => $options{ port }, cmd => \@cmd );
        $options{ kill_pid } = 1;

        # Just to give Firefox time to start up, make sure it accepts connections
        #$self->_wait_for_socket_connection( $host, $self->{port}, $self->{startup_timeout} || 20);
    }

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
    return \%options;
};

=head2 C<< $app->connect >>

  $app->connect->get()

=cut

sub connect( $self, $driver=$self->driver ) {
    weaken (my $weakself = $self);
    # Set up a timeout here
    my $connect = $driver->connect(
        #new_tab => !$options{ reuse },
        #tab     => $options{ tab },
    )->then(sub {
        # Launch a new session
        $driver->send_command( 'WebDriver:NewSession', {} )
    })->then( sub ($info) {
        $weakself->log( "debug", "Connected to Firefox " . $info->{capabilities}->{browserVersion} );
        $weakself->_have_info->done( $info->{capabilities} );

        my $ff_pid = $info->{capabilities}->{"moz:processID"};
        if( $weakself->{pid} and $ff_pid != $weakself->{pid}) {
            $weakself->log("warn", "Firefox PID is not launched pid ($ff_pid != $weakself->{pid})");
        };

        Future->done( $weakself )

    })->catch( sub($_err) {
        # if Firefox started, but so slow or unresponsive that we cannot connect
        # to it, kill it manually to avoid waiting for it indefinitely
        if ( $_err ) {
            if( $self->{ kill_pid } and my $pid = delete $self->{ pid }) {
                local $SIG{CHLD} = 'IGNORE';
                kill 'SIGKILL' => $pid;
            };
            die $_err;
        };
    });

    $connect
};

=head2 C<< $ff->quit >>

  $ff->quit->get;

Quits Firefox

=cut

sub quit( $self ) {
    my $res = $self->driver->send_command('Marionette:Quit');
    if( $self->{kill_pid}) {
        $res = $res->on_done(sub {
            waitpid $self->pid, 0;
            my $ff_pid = $self->appinfo->get->{'moz:processID'};

            if( $ff_pid != $self->pid ) {
                waitpid $ff_pid, 0;
            };
        });
    };
    $res
}

=head1 APPLICATION INFORMATION

=cut

=head2 C<< $ff->appinfo >>

    my $info = $ff->appinfo->get;
    print 'ID      : ', $info->{};
    print 'name    : ', $info->{browserName};
    print 'version : ', $info->{browserVersion};

Returns information about Firefox as a Future.

=cut

sub appinfo( $self ) {
    $self->_have_info->transform(done => sub( $info ) {
        $info
    });
};

=head2 C<< $ff->current_profile >>

    print $ff->current_profile, "\n";

Returns the directory of the currently selected profile.

=cut

sub current_profile( $self ) {
    $self->appinfo->get->{"moz:profile"}
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

    croak "->profiles() is not implemented";
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

=head2 C<< $ff->set_tab_content( $tab, $html, %options ) >>

    $ff->set_tab_content('<html><h1>Hello</h1></html>')->get;

This is a more general method that allows you to replace
the HTML of an arbitrary tab, and not only the tab that
WWW::Mechanize::Firefox is associated with.

It has the flaw of not waiting until the tab has
loaded.

=cut

sub set_tab_content( $self, $content, %options) {
    my $url = URI->new('data:');
    $url->media_type("text/html");
    $url->data($content);

    $self->driver->send_command('WebDriver:Navigate', { url => "".$url,  });

    #$tab ||= $self->tab;
    #$repl ||= $self->repl;
    #
    #$tab->{linkedBrowser}->loadURI("".$url);
};

=head2 C<< $ff->quit( %options ) >>

  $ff->quit()->get; # quit

Quits the application

=cut

sub quit( $self, %options ) {
    $self->driver->send_command('WebDriver:quit');
};

=head1 SEE ALSO

L<Firefox::Marionette> - another module for automating Firefox

=head1 TODO

=over 4

=item *

Consider how to roll L<http://kb.mozillazine.org/Command_line_arguments>
into this module for convenient / versatile launching of Firefox

=back

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2009-2018 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;