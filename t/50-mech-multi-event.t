#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::FireFox;

my $mech = eval { WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 5;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

my $browser = $mech->tab->{linkedBrowser};
my $name = 'myOwn';
my $listener = $mech->_addEventListener($browser,['click',$name]);

my $rn = $mech->repl->repl;
my $browser_id = $browser->__id;

# Now fire the event
MozRepl::RemoteObject->expr(<<JS, $mech->repl);
    var b = $rn.getLink($browser_id);
    var ev = content.document.createEvent('Events');
    ev.initEvent("$name", true, true);
    b.dispatchEvent(ev);
JS
is $listener->{busy}, 1, 'Event was fired';
is $listener->{event}, $name, '... and it was our event';

MozRepl::RemoteObject->expr(<<JS, $mech->repl);
    var b = $rn.getLink($browser_id);
    var ev = content.document.createEvent('MouseEvents');
    ev.initMouseEvent('click', true, true, window,
                             0, 0, 0, 0, 0, false, false, false,
                             false, 0, null);
    b.dispatchEvent(ev);
JS
is $listener->{busy}, 1, 'Only one event was received';
is $listener->{event}, $name, '... and the event name is the first event';
