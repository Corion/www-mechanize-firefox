#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Getopt::Long;
use Pod::Usage;
use HTML::Display::MozRepl;

GetOptions(
    'mozrepl|m:s' => \my $mozrepl,
    'tab|t:s' => \my $tabname,
    'close|c' => \my $close,
    #'focus|f' => \my $focus,
) or pod2usage();

my $d = HTML::Display::MozRepl->new(
    tabname => $tabname,
    repl    => $mozrepl,
    create  => 1,
    autoclose => $close,
);
local $/;
binmode STDIN;
my $html = <>;
$d->display($html);

=head1 NAME

bcat.pl - cat HTML to browser

=head1 SYNOPSIS

bcat.pl <index.html

Options:
   --tabname        title of tab to reuse
   --mozrepl        connection string to Firefox
   --close          automatically close the tab at the end of input

=head1 OPTIONS

=over 4

=item B<--tabname>

Name of the tab to (re)use. A substring is enough.

=item B<--close>

Automatically close the tab when the input closes. This is good
for displaying intermediate information.

=item B<--mozrepl>

Connection information for the mozrepl instance to use.

=back

=head1 DESCRIPTION

B<This program> will display HTML read from STDIN
in a browser tab.

=cut