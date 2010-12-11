#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 21;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

my $browser = $mech->tab->{linkedBrowser};
my $name = 'click';
my $listener = $mech->_addEventListener($browser,$name);

my $rn = $mech->repl->name;
my $browser_id = $browser->__id;

# Now fire the event
my $event = $mech->repl->expr(<<JS);
    var b = $rn.getLink($browser_id);
    var ev = b.contentWindow.content.document.createEvent('MouseEvents');
    ev.initMouseEvent("$name", true, true, window,
    0, 0, 0, 0, 0, false, false, false, false, 0, null);
    b.dispatchEvent(ev);
JS
is $listener->{busy}, 1, 'Event was fired';
is $listener->{event}, $name, '... and it was our event';

sub is_object($$$) {
    my ($l,$r,$name) = @_;
    my $is_id = $mech->repl->declare(<<'JS');
        function (l,r) {
            return l === r
        };
JS
    ok $is_id->($l,$r), $name
        or diag "Got $l->{tagName}, expected $r->{tagName}";
};

# Now check that we can create a lock/listener
# that listens on several objects for more than one event
# and check that it triggers for every object/event combination
my @events = (qw(load DOMContentLoaded error));
my $tab = $mech->tab;
my $tab_id = $tab->__id;

for my $name (@events) {    
    $listener = $mech->_addEventListener([$browser,\@events], [$tab, \@events]);

    # Now fire the event
    my $event = $mech->repl->expr(<<JS);
        var b = $rn.getLink($browser_id);
        var ev = b.contentWindow.content.document.createEvent('Events');
        ev.initEvent("$name", true, true, window,
        0, 0, 0, 0, 0, false, false, false, false, 0, null);
        b.dispatchEvent(ev);
JS
    is $listener->{busy}, 1, 'Event was fired';
    is $listener->{event}, $name, "... and it was $name";
    is_object $listener->{js_event}->{target}, $browser, "... on the browser";

    $listener = $mech->_addEventListener([$browser,\@events], [$tab, \@events]);
    $event = $mech->repl->expr(<<JS);
        var b = $rn.getLink($tab_id);
        var br = $rn.getLink($browser_id);
        var ev = br.contentWindow.content.document.createEvent('Events');
        ev.initEvent("$name", true, true);
        b.dispatchEvent(ev);
JS
    is $listener->{busy}, 1, 'Event was fired';
    is $listener->{event}, $name, "... and it was $name";
    is_object $listener->{js_event}->{target}, $tab, "... on the tab";
};

$MozRepl::RemoteObject::WARN_ON_LEAKS++;
undef $mech;