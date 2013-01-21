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

1;