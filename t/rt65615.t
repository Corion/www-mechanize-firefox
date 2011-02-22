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

$mech->get_local('rt65615.html');
ok eval {
    my $img = $mech->content_as_png;
    1
} or diag $@;
