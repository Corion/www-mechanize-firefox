#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

=head1 NAME

rt84418 - testcase for Ticket RT84418

=head1 DESCRIPTION

The tab created by WWW::Mechanize::Firefox does not
get automatically closed when using more than one open
window, and creating that tab in the second window.

=cut

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 6;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

sub open_windows {
    my $windowEnum= $mech->repl->expr(<<'JS');
    Components.classes["@mozilla.org/appshell/window-mediator;1"]
      .getService(Components.interfaces.nsIWindowMediator)
      .getEnumerator("navigator:browser")
JS

    my $openWindows;
    $openWindows++
        while $windowEnum->hasMoreElements and $windowEnum->getNext();
    $openWindows
};

my $atStart= open_windows;
my $first= $mech->repl->expr('window');
{
    # First case, manually destroy the tab:

    # Create second window
    my $second= $first->open;
    
    my $count= open_windows;
    is $count, $atStart+1, "We opened a new window";
    
    # The second window gets the focus

    # Create tab (in second window)
    my $other_mech= WWW::Mechanize::Firefox->new(
        tab => 'current',
    );
    $other_mech->update_html('Tab in second window');
    my $magic= 'Second tab - ' . $$;
    $other_mech->tab->{title} = $magic;

    # Focus first window
    $mech->repl->expr('window.focus()');

    my $lives= eval {
        #$other_mech->application()->closeTab( $other_mech->tab() );
        1;
    };
    ok $lives, "We survived explicitly closing the second tab"
        or diag($@);

    my $tabs= grep { $magic eq $_->{title} } $other_mech->application->openTabs();
    is $tabs, 0, "The second tab was closed";
    # Try to clean up
    eval {
        $second->close();
    };
}

{
    # Now, let the second tab fall off the scope:

    # Create second window
    my $second= $mech->repl->expr('window.open()');
    # The second window gets the focus

    {
        # Create tab (in second window)
        my $other_mech= WWW::Mechanize::Firefox->new(
            #tab => 'current',
            #autoclose => 1,
        );
        $other_mech->update_html('Tab in second window');
        sleep 1;

        # Focus first window
        $first->focus;
        sleep 1;

        # Now, close the tab
        my $lives= eval {
            undef $other_mech;
            1;
        };
        ok $lives, "We survived implicitly closing the second tab";
    };
    $second->close();
    
    my $windowsNow= open_windows;
    is $windowsNow, $atStart, "We closed the newly opened window";
}
undef $mech;