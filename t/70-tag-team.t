#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::FireFox;
use URI::file;
use Cwd;
use File::Basename;

my $mech = eval {WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 9;
};
undef $mech;

my @pages = qw(
    70-rt71216.html
    51-mech-sandbox.html
    52-mech-api-find_link.html
);

my @mech = $mech, map {;
    WWW::Mechanize::FireFox->new( 
        autodie => 0,
        #log => [qw[debug]]
    )
} @pages;

for my $mech (@mech) {
    isa_ok $mech, 'WWW::Mechanize::FireFox';
};

for my $page (0..$#pages) {
    $mech[ $page ]->get_local($pages[ $page ]);
};
for my $idx (0..$#mech) {
    my $mech = $mech[$idx];
    ok $mech->success;
    like $mech->url, qr!/\Q$pages[ $idx ]\E$!i, "We navigated to the right file";
};
