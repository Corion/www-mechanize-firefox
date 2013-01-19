#!perl -w
use strict;
use Test::More;
use File::Basename;

use Firefox::Application;
use WWW::Mechanize::Firefox;

use t::helper;

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 4;
};

my $mech=
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        #log => [qw[debug]],
    );

my $repl = $mech->repl;

my $magic = sprintf "%s - %s", basename($0), $$;

# Now check that we can close an arbitrary tab:
$mech->update_html(<<HTML);
<html><head><title>$magic</title></head><body>Test</body></html>
HTML

my $ff = Firefox::Application->new(
    repl => $repl,
);
my @tabs = $ff->openTabs($repl);

$mech->tab->{title} = $magic; # mark our main tab

my $tab2 = $ff->addTab();
my $magic2 = "Another tab ($magic)";
$tab2->{title} = $magic2;

$ff->set_tab_content($tab2, <<HTML, $repl);
<html><head><title>$magic2</title></head><body>Secondary tab</body></html>
HTML

my $tab = $mech->tab;

my $old_tab = $ff->selectedTab( repl => $repl );

$ff->activateTab( $tab2 );
my $current = $ff->selectedTab( repl => $repl );
ok $current, "We got a currently selected tab";

is $current->{title}, $magic2, "We selected tab 2";

$ff->activateTab( $tab );
$current = $ff->selectedTab;
ok $current, "We got a currently selected tab";
is $current->{title}, $magic, "We selected tab 1";

# Restore what the user saw:
$ff->activateTab( $old_tab );

undef $mech; # and close that tab
