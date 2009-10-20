#!perl -w
use strict;
use Test::More tests => 2;

use MozRepl::RemoteObject;

my $repl = MozRepl->new;
$repl->setup({
    client => {
        extra_client_args => {
            binmode => 1,
        }
    },
    log => [qw/ error/],
    #log => [qw/ debug error/],
    plugins => { plugins => [qw[ Repl::Load ]] }, # I'm loading my own JSON serializer
});
MozRepl::RemoteObject->install_bridge($repl);

my $four = MozRepl::RemoteObject->expr(<<JS);
    2+2
JS

is $four, 4, "Addition in Javascript works";

my $wrapped_repl = MozRepl::RemoteObject->expr(<<JS);
    repl
JS

my $repl_id = $wrapped_repl->__id;
my $identity = MozRepl::RemoteObject->expr(<<JS);
    repl === repl.getLink($repl_id)
JS

is $identity, 'true', "Object identity in Javascript works";
