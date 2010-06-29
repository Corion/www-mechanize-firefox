#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Getopt::Long;
use Pod::Usage;
use HTML::Display::MozRepl;

my $d = HTML::Display::MozRepl->new();
local $/;
binmode STDIN;
my $html = <>;
$d->display($html);

=head1 NAME

screenshot.pl - take a screenshot of a webpage

=head1 SYNOPSIS

screenshot.pl [options] [url]

Options:
   --outfile        name of output file
   --mozrepl        connection string to Firefox

=head1 OPTIONS

=over 4

=item B<--outfile>

Name of the output file. The image will always be written
in PNG format.

=item B<--mozrepl>

Connection information for the mozrepl instance to use.

=back

=head1 DESCRIPTION

B<This program> will take a screenshot
of the given URL (including plugins) and
write it to the given file or the file C<screenshot.png>.

=cut