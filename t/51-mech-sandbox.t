#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::FireFox;
use URI::file;
use File::Basename;
use File::Spec;
use Cwd;

my $mech = eval { WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 13;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

$mech->get_local('51-mech-sandbox.html');
$mech->allow('javascript' => 1);

my ($state,$type) = eval { $mech->eval_in_page('state') };

if (! $state) {
    SKIP: { skip "Couldn't get at 'state'. Do you have a Javascript blocker?", 12; };
    exit;
};

ok $state, "We found 'state'";

(my ($get),$type) = eval { $mech->eval_in_page('get') };
ok $get, "We found 'get'";
is $type, 'function', "Result type";

my $v;
eval {
    $v = $get->();
};
is $@, "", "No error when calling get()";
is $v, 'Hello', "We got the initial value";

(my ($set),$type) = eval { $mech->eval_in_page('set') };
ok $set, "We found 'set'";

eval {
    $v = $set->('123');
};
is $@, "", "No error when calling set()";
is $v, '123', "We got the set value";

eval {
    $v = $get->();
};
is $@, "", "No error when calling get()";
is $v, '123', "We got the new value";

(my ($val),$type) = $mech->eval_in_page('hello');
is $type, 'string', "Returning a string";
is $val, 'Hello MozRepl', "Getting the right value";