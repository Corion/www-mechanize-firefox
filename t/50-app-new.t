#!perl -w
use strict;
use Test::More;
use File::Basename;

use Firefox::Application;

my $ff = eval { Firefox::Application->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $ff) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 4;
};

my $lives;
my @addons;

eval { @addons = $ff->addons; $lives++ };
ok $lives, "We can query the addons"
    or diag $@;

diag "Found " . scalar @addons . " addons";
ok @addons >= 1, "You have at least one addon"; # The mozrepl addon, duh

my ($mozrepl) = grep { $_->{id} eq 'mozrepl@hyperstruct.net' } @addons;
isn't $mozrepl, undef, "We find the mozrepl addon";
is $mozrepl->{name}, 'MozRepl', 'The name is "MozRepl"';
