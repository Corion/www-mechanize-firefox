#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

use t::helper;

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 5;
};

my $mech=
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        #log => [qw[debug]],
    );

my $server = Test::HTTP::LocalServer->spawn(
    #debug => 1
);

my @values = qw<
        test_query
        test_query_2
>;

$mech->autodie(1);

$mech->get($server->url);
is $mech->title, 'WWW::Mechanize::Firefox test page', "We loaded the right test page ()";

$mech->form_name('f');

$mech->set_visible(@values);
$mech->submit();
# Check that we got the right values passed back
is $mech->value('query'), 'test_query', "First visible field does get filled";
is $mech->value('botcheck_query'), '(empty)', "A hidden field does not get filled";
is $mech->value('query2'), 'test_query_2', "Second visible field does get filled";

# Check that we fail on passing more than available visible fields
my $lived = eval {
    $mech->set_visible((@values) x 4);
    1
};
is $lived, undef, "Passing too many values for a form fails correctly";
