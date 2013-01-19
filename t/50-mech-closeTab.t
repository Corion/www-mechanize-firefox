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
sleep 1;

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
sleep 1;

my @new_tabs = $ff->openTabs($repl);
is 1+@tabs, 0+@new_tabs, "We added a tab";
if (! is 0+(grep { $_->{title} eq $magic2 } @new_tabs), 1, "We added our tab" ) {
    for (@new_tabs) {
        diag "<$_->{title}>";
    };
};

$ff->closeTab($tab2);
@new_tabs = $ff->openTabs($repl);
if (! is 0+@tabs, 0+@new_tabs, "We closed a tab") {
    for (@new_tabs) {
        diag $_->{title};
    };
};
if (!is 0+(grep { $_->{title} eq $magic2 } @new_tabs), 0, "We removed our tab"){
    for (@new_tabs) {
        diag $_->{title};
    };
};

undef $ff;
diag "App released";
undef $mech; # and close that tab
diag "Mech released";
