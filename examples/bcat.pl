#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Getopt::Long;
use Pod::Usage;
use Cwd qw(getcwd);

GetOptions(
    'mozrepl|m:s' => \my $mozrepl,
    'tab:s' => \my $tab,
    'current|c' => \my $use_current_tab,
    'close|q' => \my $close,
    'title|t:s' => \my $title,
    'type:s' => \my $encode_type,
    #'focus|f' => \my $focus,
) or pod2usage();

$tab = $use_current_tab ? 'current'
       : $tab ? qr/$tab/
       : undef
       ;

$title ||= getcwd;

my $mech = WWW::Mechanize::Firefox->new(
    tab     => $tab,
    repl    => $mozrepl,
    create  => 1,
    autoclose => $close,
);

local $/;
binmode STDIN;
my $html = <>;

# Find out whether we have HTML:
if (! $encode_type) {
    if ($html =~ /^\s*</sm) {
        $encode_type = 'html'
    } else {
        $encode_type = 'text',
    };
};

if ('text' eq $encode_type) {
    my %map = (
    '<' => '&lt;',
    '>' => '&gt;',
    '&' => '&amp;',
    );
    $html =~ s/([<>&])/$map{$1} || $1/ge;
    $html =~ s/\r?\n/<br>/g;
    $html = "<html><head><title>$title</title><body><pre>$html</pre></body></html>";
};

$mech->update_html($html);

=head1 NAME

bcat.pl - cat HTML to browser

=head1 SYNOPSIS

  bcat.pl <index.html

Options:
   --tab            title of tab to reuse (regex)
   --current        reuse current tab
   --title          title of the page
   --mozrepl        connection string to Firefox
   --close          automatically close the tab at the end of input
   --type TYPE      Fix the type to 'html' or 'text'

=head1 OPTIONS

=over 4

=item B<--tab>

Name of the tab to (re)use. A substring is enough.

=item B<--current>

Use the currently focused tab.

=item B<--title>

Give the title of the page that is shown.

=item B<--close>

Automatically close the tab when the input closes. This is good
for displaying intermediate information.

=item B<--type TYPE>

Force the type to be either C<html> or C<text>. If the type is
C<text>, line wrapping will be added.

=item B<--mozrepl>

Connection information for the mozrepl instance to use.

=back

=head1 DESCRIPTION

B<This program> will display HTML read from STDIN
in a browser tab.

=head1 SEE ALSO

The original C<bcat> utility which inspired this program
at L<http://rtomayko.github.com/bcat/>.

=cut