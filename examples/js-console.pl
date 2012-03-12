#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;
use Getopt::Long;
use Pod::Usage;

GetOptions(
    'clear|c' => \my $clear,
    'mozrepl|m:s' => \my $mozrepl,
    'text|t:s' => \my $text,
) or pod2usage();

my $mech = WWW::Mechanize::Firefox->new(
    #log => ['debug'],
    mozrepl => $mozrepl,
);

my $console = $mech->js_console;

$mech->clear_js_errors
    if ($clear);

if ($text) {
        $console->logStringMessage($text);
} else {
    while (<>) {
        $console->logStringMessage($_);
    };
};

=head1 NAME

js-console.pl - send STDIN to the Javascript Console

=head1 SYNOPSIS

    echo "Hello World" | js-console.pl

Options:
   --clear          Clear console before sending text
   --mozrepl        connection string to Firefox
   --close          automatically close the tab at the end of input
   --type TYPE      Fix the type to 'html' or 'text'

=head1 OPTIONS

=over 4

=item B<--clear>

Clear the console before sending the text.

=item B<--text TEXT>

Send the text TEXT instead of reading from STDIN.

=item B<--mozrepl>

Connection information for the mozrepl instance to use.

=back

=head1 DESCRIPTION

This program sends text read from standard input to the
Javascript Console in Firefox. This can be convenient
if you want to do testing and log the start or stop
of a test run to the console.

=head1 SEE ALSO

L<https://developer.mozilla.org/en/Error_Console>

L<https://developer.mozilla.org/en/nsIConsoleService> - the underlying
Console Service that also shows how to listen to events getting
added.

=cut