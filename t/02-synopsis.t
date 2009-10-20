#!perl -w
use strict;
use Test::More tests => 2;

use MozRepl::RemoteObject;
my $repl = MozRepl->new;
$repl->setup({
    log => [qw/ error/],
    plugins => { plugins => [qw[ JSON2 ]] },
});
MozRepl::RemoteObject->install_bridge($repl);
  
# get our root object:
my $rn = $repl->repl;
my $tab = MozRepl::RemoteObject->expr(<<JS);
    window.getBrowser().addTab()
JS

isa_ok $tab, 'MozRepl::RemoteObject', 'Our tab';

$tab->__release_action('window.getBrowser().removeTab(self)');

# Now use the object:
my $body = $tab->{linkedBrowser}
            ->{contentWindow}
            ->{document}
            ->{body}
            ;
$body->{innerHTML} = "<h1>Hello from MozRepl::RemoteObject</h1>";

like $body->{innerHTML}, '/Hello from/', "We stored the HTML";

$tab->{linkedBrowser}->loadURI('"http://corion.net/"');
