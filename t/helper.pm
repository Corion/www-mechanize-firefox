package # hide from CPAN indexer
    t::helper;
use strict;
use Test::More;
use File::Glob qw(bsd_glob);

sub firefox_instances {
    my ($filter) = @_;
    $filter ||= qr/^/;
    my @instances;
    push @instances, undef; # default Firefox instance
    
    # add author tests with local versions
    my $spec = $ENV{TEST_WWW_MECHANIZE_FIREFOX_VERSIONS}
             || 'firefox-versions/*/FirefoxPortable*'; # sorry, likely a bad default
    push @instances, sort {$a cmp $b} grep { -x } bsd_glob $spec;
    
    grep { ($_ ||'') =~ /$filter/ } @instances;
};

sub default_unavailable {
    # Connect to default instance
    my $ff = eval { Firefox::Application->new( 
        autodie => 0,
        #log => [qw[debug]]
    )};

    my $reason = defined $ff ? undef : $@;
};

sub run_across_instances {
    my ($instances, $port, $new_mech, $code) = @_;
    
    for my $firefox_instance (@$instances) {
        if ($firefox_instance) {
            diag "Testing with $firefox_instance";
        };
        my @launch = $firefox_instance
                   ? ( launch => [$firefox_instance, '-repl', $port],
                       repl => "localhost:$port" )
                   : ();
        
        # Try three times to connect
        my $retry = 3;
        my $mech;
        my $last_error;
        while(!$mech and $retry-- > 0) {
            eval { $mech = $new_mech->(@launch); };
            $last_error = $@;
        };
        if( ! $retry) {
            die "Couldn't launch $firefox_instance: $@";
        };

        # Run the user-supplied tests
        $code->($firefox_instance, $mech);
        
        if ($firefox_instance) {
            if ($mech->can('application')) {
                $mech = $mech->application;
            };
            #// $mech->quit;
            # Quit in 500ms, so we have time to shut our socket down
            $mech->repl->expr(<<'JS');
        var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                           .getService(Components.interfaces.nsIWindowMediator);
        var win = wm.getMostRecentWindow('navigator:browser');
        win.setTimeout(function() {
            Components.classes["@mozilla.org/toolkit/app-startup;1"]
                     .getService(Components.interfaces.nsIAppStartup).quit(0x02);
        }, 500);
JS
            undef $mech;
            sleep 2; # So the browser can shut down before we try to connect
            # to the new instance
        };
    };
};

1;