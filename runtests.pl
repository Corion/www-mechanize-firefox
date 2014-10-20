#!perl -w
use strict;
use t::helper;
use WWW::Mechanize::Firefox;
use File::Glob qw( bsd_glob );
use Config;
use Getopt::Long;

GetOptions(
    't|test:s' => \my $tests,
    'c|continue' => \my $continue,
);
my @tests;
if( $tests ) {
    @tests= bsd_glob( $tests );
};

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
    my $vis_instance = $instance ? $instance : "local instance";
    warn $vis_instance;
    my @launch = $instance
               ? (launch => [$instance,'-repl', $port, 'about:blank'])
               : ()
               ;

    if( $instance ) {
        $ENV{TEST_WWW_MECHANIZE_FIREFOX_VERSIONS} = $instance;
        $ENV{MOZREPL}= "localhost:$port";
    } else {
        $ENV{TEST_WWW_MECHANIZE_FIREFOX_VERSIONS} = "don't test other instances";
        delete $ENV{MOZREPL}; # my local setup ...
    };
    my $retries = 3;
    
    my $ff;
    while( $retries-- and !$ff) {
        $ff= eval {
            Firefox::Application->new(
                @launch,
            );
        };
    };
    die "Couldn't launch Firefox instance from $instance"
        unless $ff;
    
    if( @tests ) {
        for my $test (@tests) {
            system(qq{perl -w "$test"}) == 0
                or ($continue and warn "Error while testing $vis_instance: $!/$?")
                or die "Error while testing $vis_instance: $!/$?";
        };
    } else { # run all tests
        system("$Config{ make } test") == 0
            or ($continue and warn "Error while testing $vis_instance: $!/$?")
            or die "Error while testing $vis_instance";
    };
    
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
    # Safe wait until shutdown
    sleep 5;
};