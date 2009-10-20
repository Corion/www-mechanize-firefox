#!perl -w
use strict;
use Test::More tests => 6;

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
    return { bar: { baz: { value: val } } };
})($rn, "$val")
JS
}

my $foo = genObj($repl, 'deep');
isa_ok $foo, 'MozRepl::RemoteObject';

my $baz = $foo->__dive(qw[bar baz]);
isa_ok $baz, 'MozRepl::RemoteObject', "Diving to an object works";
is $baz->{value}, 'deep', "Diving to an object returns the correct object";

my $val = $foo->__dive(qw[bar baz value]);
is $val, 'deep', "Diving to a value works";

$val = eval { $foo->__dive(qw[bar flirble]); 1 };
my $err = $@;
is $val, undef, "Diving into a nonexisting property fails";
like $err, '/bar\.flirble/', "Error message mentions last valid property and failed property";

