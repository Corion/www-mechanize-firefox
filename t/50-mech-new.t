#!perl -w
use strict;
use Test::More;

use WWW::Mechanize::FireFox;

my $mech = eval { WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 1;
};

my $repl = $mech->repl;

my @tabs = WWW::Mechanize::FireFox->openTabs($repl);

sleep 1;

undef $mech; # our own tab should now close automatically

my @new_tabs = WWW::Mechanize::FireFox->openTabs($repl);

if (! is scalar @new_tabs, @tabs-1, "Our tab was presumably closed") {
    for (@new_tabs) {
        diag $_->{title};
    };
};
