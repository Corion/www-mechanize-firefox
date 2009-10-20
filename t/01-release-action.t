#!perl -w
use strict;
use Test::More tests => 3;

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

diag "--- Loading object functionality into repl\n";
MozRepl::RemoteObject->install_bridge($repl);

# create two remote objects
sub genObj {
    my ($repl,$val) = @_;
    my $rn = $repl->repl;
    my $obj = MozRepl::RemoteObject->expr(<<JS)
(function(repl, val) {
    return { value: val };
})($rn, "$val")
JS
}

my $foo = genObj($repl, 'foo');
isa_ok $foo, 'MozRepl::RemoteObject';
my $bar = genObj($repl, 'bar');
isa_ok $bar, 'MozRepl::RemoteObject';

my $foo_id = $foo->__id;

$bar->__release_action(<<JS);
    repl.getLink($foo_id)['value'] = "bar has gone";
JS

undef $bar;

is $foo->{value}, 'bar has gone', "JS-Release action works";