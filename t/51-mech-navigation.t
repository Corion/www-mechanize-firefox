#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
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
    plan tests => 12;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('49-mech-get-file.html');
ok $mech->success, '49-mech-get-file.html';
is $mech->title, '49-mech-get-file.html', "We loaded the right file";

$mech->back(0);
is $mech->title, '49-mech-get-file.html', "Going back in history makes us stay in place";

$mech->forward(0);
is $mech->title, '49-mech-get-file.html', "Going forward in history makes us stay in place";

$mech->get('about:blank');
ok $mech->success, 'about:blank';

$mech->back(0);
is $mech->title, '49-mech-get-file.html', "Go back in history";

$mech->forward(0);
is $mech->title, '', "Go forward in history";

$mech->reload();
is $mech->title, '', "Reloading makes us stay in place";

$mech->get_local('52-subframe.html');
is $mech->value('bar'),'foo', "We start with 'foo'";
$mech->field('bar' => 'barzzz');
$mech->reload();
is $mech->value('bar'),'barzzz', "Reloading the page keeps the form values";

$mech->reload(1);
is $mech->value('bar'),'foo', "Force-reloading the page removes the form values";

undef $mech;