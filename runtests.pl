#!perl -w
use strict;
use t::helper;
use WWW::Mechanize::Firefox;
use File::Glob qw( bsd_glob );
use Config;

=head1 NAME

runtests.pl - runs the test suite across several instances of Firefox

=cut

my @instances = @ARGV
                ? map { bsd_glob $_ } @ARGV 
                : t::helper::firefox_instances;
my $port = 4243;

# Later, we could even parallelize the test suite
# if I find out how to make the mozrepl port dynamic
for my $instance (@instances) {
    # Launch firefox
    warn $instance || "live Firefox";
    my @launch = $instance
               ? (launch => [$instance,'-repl', $port, 'about:blank'])
               : ()
               ;

    my $vis_instance = $instance ? $instance : "local instance";
    if( $instance ) {
        $ENV{TEST_WWW_MECHANIZE_FIREFOX_VERSIONS} = $instance;
        $ENV{MOZREPL}= "localhost:$port";
    } else {
        $ENV{TEST_WWW_MECHANIZE_FIREFOX_VERSIONS} = "don't test other instances";
        delete $ENV{MOZREPL}; # my local setup ...
    };

    my $ff= Firefox::Application->new(
        @launch,
    );
    #$mech->update_html("<html><head><title>Running tests on $vis_instance</title></head><body><h2>$vis_instance</h2></body></html>");
    
    system("$Config{ make } test") == 0
        or die "Error while testing";
    
    if( $instance ) {
        # Close firefox again
        # Quit in 500ms, so we have time to shut our socket down
        $ff->repl->expr(<<'JS');
        var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                           .getService(Components.interfaces.nsIWindowMediator);
        var win = wm.getMostRecentWindow('navigator:browser');
        win.setTimeout(function() {
            Components.classes["@mozilla.org/toolkit/app-startup;1"]
                     .getService(Components.interfaces.nsIAppStartup).quit(0x02);
        }, 500);
JS
    };
    undef $ff;
    sleep 1; # So the browser can shut down before we try to connect
};