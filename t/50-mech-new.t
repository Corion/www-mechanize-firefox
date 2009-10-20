#!perl -w
use strict;
use Test::More tests => 2;

use_ok 'WWW::Mechanize::FireFox';

my $mech = WWW::Mechanize::FireFox->new();
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
