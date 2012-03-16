#!perl -w
use strict;
use Test::More;
use File::Basename;

use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 5;
};

my $repl = $mech->repl;
my $app = $mech->application;

my @tabs = $app->openTabs($repl);

sleep 1;

undef $mech; # our own tab should now close automatically

my @new_tabs = $app->openTabs($repl);

if (! is scalar @new_tabs, @tabs-1, "Our tab was presumably closed") {
    for (@new_tabs) {
        diag $_->{title};
    };
};

my $magic = sprintf "%s - %s", basename($0), $$;
#diag "Tab title is $magic";
# Now check that we don't open a new tab if we try to find an existing tab:
$mech = WWW::Mechanize::Firefox->new(
    autodie => 0,
    autoclose => 0,
);
$mech->update_html(<<HTML);
<html><head><title>$magic</title></head><body>Test</body></html>
HTML

undef $mech;

# Now check that we don't open a new tab if we try to find an existing tab:
$mech = WWW::Mechanize::Firefox->new(
    autodie => 0,
    autoclose => 0,
    tab => qr/^\Q$magic/,
);
my $c = $mech->content;
like $mech->content, qr/\Q$magic/, "We selected the existing tab"
    or do { diag $_->{title} for $mech->application->openTabs() };

# Now activate the tab and connect to the "current" tab
# This is ugly for a user currently using Firefox, but hey, they
# should be watching in amazement instead of surfing while we test
$app->activateTab($mech->tab);
$mech = WWW::Mechanize::Firefox->new(
    autodie => 0,
    autoclose => 0,
    tab => 'current',
);
$c = $mech->content;
like $mech->content, qr/\Q$magic/, "We connected to the current tab"
    or do { diag $_->{title} for $mech->application->openTabs() };
$mech->autoclose_tab($mech->tab);

undef $mech; # and close that tab

# Now try to connect to "our" now closed tab
my $lived = eval {
    $mech = WWW::Mechanize::Firefox->new(
        autodie => 1,
        tab => qr/\Q$magic/,
    );
    1;
};
my $err = $@;
is $lived, undef, 'We died trying to connect to a non-existing tab';
# Something within the eval {} block above kills $@. Likely, some destructor
# somewhere, maybe in MozRepl::RemoteObject.
like $err, q{/Couldn't find a tab matching/}, 'We got the correct error message';
