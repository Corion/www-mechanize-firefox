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
    plan tests => 2;
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
diag "Tab title is $magic";
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
$mech->autoclose_tab($mech->tab);

undef $mech; # and close that tab
