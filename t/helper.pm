package # hide from CPAN indexer
    t::helper;
use strict;
use Test::More;

sub firefox_instances {
    my ($filter) = @_;
    $filter ||= qr/^/;
    my @instances;
    push @instances, undef; # default Firefox instance
    if (-d 'firefox-versions') { # author test with local instances
        push @instances, sort glob 'firefox-versions/*/FirefoxPortable.exe'; # sorry, Windows-only
    };
    
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
        
        my $mech = $new_mech->(@launch);

        # Run the user-supplied tests
        $code->($firefox_instance, $mech);
        
        if ($firefox_instance) {
            if ($mech->can('application')) {
                $mech = $mech->application;
            };
            $mech->quit;
            sleep 1; # justin case
        };
    };
};

1;