#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Getopt::Long;
use Pod::Usage;

GetOptions(
    'mozrepl|m:s' => \my $mozrepl,
    'follow|f'    => \my $install_listener,
    'clear|c'     => \my $clear,
    'number|n:i'  => \my $lines,
) or pod2usage(2);
$lines ||= 5;

my $mech = WWW::Mechanize::Firefox->new(
    #log => ['debug'],
    mozrepl => $mozrepl,
);

sub install_listener {
    warn "Creating logListener";
    my $logListener = $mech->repl->declare(<<'JS');
    function(callback) {
        return {
            observe: callback,
            QueryInterface: function (iid) {
                if (!iid.equals(Components.interfaces.nsIConsoleListener) &&
                    !iid.equals(Components.interfaces.nsISupports)) {
                        throw Components.results.NS_ERROR_NO_INTERFACE;
                }
                return this;
            },
        };
    }
JS

    warn "Creating registerListener";

    my $registerListener = $mech->repl->declare(<<'JS');
        function (listener) {
            var aConsoleService = Components.classes["@mozilla.org/consoleservice;1"]
                .getService(Components.interfaces.nsIConsoleService);
            aConsoleService.registerListener(listener);
        };
JS

    my $listener = $logListener->(sub {output_message($_[0])});
    $registerListener->($listener);
};

sub output_message {
    print "$_[0]->{message}\n";
};

my $console = $mech->js_console;

$mech->clear_js_errors
    if ($clear);

output_message $_ for reverse (grep {defined} ($mech->js_errors)[-$lines..0]);

if ($install_listener) {
    my $l = install_listener;
    while (1) {
        $mech->repl->poll;
        sleep 0.25;
    };
};

=head1 NAME

js-console.pl - send STDIN to the Javascript Console

=head1 SYNOPSIS

    tail-console.pl -f

Options:
   --clear          Clear console before receiving new messages
   --follow         Read more messages as they are being added
   --mozrepl        connection string to Firefox

=head1 OPTIONS

=over 4

=item B<--clear>

Clear the console before sending the text.

=item B<--follow>

Keep watching the console and output text as it gets added.

=item B<--mozrepl>

Connection information for the mozrepl instance to use.

=back

=head1 DESCRIPTION

This program reads messages from the Error Console and sends them
to STDOUT.

=head1 SEE ALSO

L<https://developer.mozilla.org/en/Error_Console>

L<https://developer.mozilla.org/en/nsIConsoleService> - the underlying
Console Service that also shows how to listen to events getting
added.

=cut