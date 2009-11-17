#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::FireFox;
use URI::file;
use Cwd;
use File::Basename;

my %options = (
    autodie => 0,
    #log => [qw[debug]]
);

my $mech = eval {WWW::Mechanize::FireFox->new( %options )};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 9;
};
undef $mech;

my @pages = qw(
    49-mech-get-file.html
    51-mech-sandbox.html
    53-mech-capture-js-noerror.html
);

my @mech = map {;
    WWW::Mechanize::FireFox->new( %options )
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
    like $mech->uri, qr!/\Q$pages[ $idx ]\E$!i, "We navigated to the right file";
};
