#!perl -w
use strict;
use Test::More;
use File::Basename;

use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #autoclose => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};
# Mark this tab
my $magic = sprintf "%s - %s", basename($0), $$;
$mech->update_html(<<HTML);
<html><head><title>$magic</title></head><body>Test</body></html>
HTML

my $repl = $mech->repl;
my $app = $mech->application;
my @tabs =  map { $_->{tab} }
           grep { $magic eq $_->{title} }
           $app->openTabs($repl);

is 0+@tabs, 1, 'We find our tab';

my $synth_mech = WWW::Mechanize::Firefox->new(
    tab => $tabs[0],
    app => $app,
);
is $synth_mech->content, $mech->content, 'Both instances use the same tab';

$synth_mech->update_html(<<HTML);
<html><head><title>$magic</title></head><body>$magic</body></html>
HTML

is $synth_mech->content, $mech->content, 'Both instances use the same tab';

@tabs = ();
undef $mech;
undef $synth_mech;