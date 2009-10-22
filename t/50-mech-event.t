#!perl -w
use strict;
use Test::More tests => 3;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new( autodie => 0 );
isa_ok $mech, 'WWW::Mechanize::FireFox';

my $browser = $mech->tab->{linkedBrowser};
my $name = 'click';
my $listener = $mech->_addEventListener($browser,$name);

my $rn = $mech->repl->repl;
my $browser_id = $browser->__id;

# Now fire the event
my $event = MozRepl::RemoteObject->expr(<<JS, $mech->repl);
    var b = $rn.getLink($browser_id);
    var ev = content.document.createEvent('MouseEvents');
    ev.initMouseEvent("$name", true, true, window,
    0, 0, 0, 0, 0, false, false, false, false, 0, null);
    b.dispatchEvent(ev);
JS
is $listener->{busy}, 1, 'Event was fired';
is $listener->{event}, $name, '... and it was our event';