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
    plan tests => 9;
};

$mech->get_local('50-click.html');

# Build an environment for functions to become injected
my $env = {};
my $bar = $mech->repl->declare(<<JS);
    function() { return "bar called" }
JS

my $foo_replacement = $mech->repl->declare(<<JS);
    function() { return "foo_replacement called" }
JS

$env->{ bar } = $bar;
$env->{ foo } = $foo_replacement;
$env->{ other_var } = "some other value";

my ($obj,$type);

($obj,$type) = $mech->eval_in_page("foo()");
is $obj, "foo called", "Default behaviour without environment replacement (1)";

($obj,$type) = $mech->eval_in_page("clicked", $env);
is $obj, "<nothing>", "Environment allows variable access";

($obj,$type) = $mech->eval_in_page("other_var", $env);
is $obj, "some other value", "Environment allows variable access";

($obj,$type) = $mech->eval_in_page("foo()");
is $obj, "foo called", "Default behaviour without environment replacement (2)";

($obj,$type) = $mech->eval_in_page("bar()", $env);
is $obj, "bar called", "Environment allows for calling other functions";

($obj,$type) = $mech->eval_in_page("call_bar()", $env);
is $obj, "bar called", "Environment allows for calling other functions";

($obj,$type) = $mech->eval_in_page("call_foo()", $env);
is $obj, "foo_replacement called", "Modified behaviour with environment replacement";

($obj,$type) = $mech->eval_in_page("foo()");
is $obj, "foo called", "Default behaviour without environment replacement restores)";

($obj,$type) = $mech->eval_in_page("call_foo()");
is $obj, "foo called", "Default behaviour without environment replacement restores (indirect)";

undef $mech; # and close that tab
