use strict;
use WWW::Mechanize::Firefox;
use Test::More;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 1;
};

# Skip on FF 5.x , 6.x, 7.x - some GPU drivers are problematic
# with certain canvas sizes. No use in tracking down the
# exact conditions.
SKIP: {
if( $mech->application->appinfo->{version} =~ /^([567]\..*)/ ) {
    skip "Skipping on FF $1 (canvas has a known memory leak here)", 1;
};

$mech->get_local('rt65615.html');
ok eval {
    my $img = $mech->content_as_png;
    1
} or diag $@;
};