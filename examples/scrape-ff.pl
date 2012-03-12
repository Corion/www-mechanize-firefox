#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use HTML::Selector::XPath qw(selector_to_xpath);
use Getopt::Long;
use Pod::Usage;

GetOptions(
    'mozrepl|m:s' => \my $mozrepl,
    'tab' => \my $tab,
    'current|c' => \my $use_current_tab,
    'close|q' => \my $close,
    'uri:s' => \my @make_uri,
    'no-uri' => \my $no_known_uri,
    'sep:s' => \my $sep,
    'help'  => \my $help,
) or pod2usage(2);
pod2usage(1) if $help;

$tab = $use_current_tab ? 'current'
       : $tab ? qr/$tab/
       : undef
       ;

my $mech = WWW::Mechanize::Firefox->new(
    tab     => $tab,
    repl    => $mozrepl,
    create  => 1,
);

# make_uri can be a comma-separated list of columns to map
# The index starts at one
my %make_uri = map{ $_-1 => 1 } map{ split /,/ } @make_uri;
$sep ||= "\t";

# Now determine where we get the HTML to scrape from:
my $url;
if (! ($use_current_tab or $tab)) {
    $url = shift @ARGV;
    $mech->get( $url );
} else {
    $url = $mech->uri;
};

my $html = $mech->content;

# now fetch all "rows" from the page. We do this once to avoid
# fetching a page multiple times
my @rows;

my %known_uri = (
    'href' => 1, # a@href
    'src' => 1, # img@src , script@src
);

my $rowidx=0;
for my $selector (@ARGV) {
    my $fetch_attr;
    if ($selector =~ s!(?:/?|\s*)\@(\w+)$!!) {
        $fetch_attr = $1;
    };
    
    $selector =~ s/\s+$//;
    
    if ($selector !~ m!^/!) {
        $selector = selector_to_xpath( $selector );
    };
    my @nodes;
    if (! defined $fetch_attr) {
        @nodes = map { /^\s*(.*?)\s*\z/ms } map { $_->{innerHTML} } $mech->xpath($selector);
    } else {
        $make_uri{ $rowidx } ||= (($known_uri{ lc $fetch_attr }) and ! $no_known_uri);
        @nodes = map { $_->{nodeValue} } $mech->xpath($selector);
    };
    
    if ($make_uri{ $rowidx }) {
        @nodes = map { URI->new_abs( $_, $url )->as_string } @nodes;
    };
    
    $rows[ $rowidx++ ] = \@nodes;
};

for my $idx (0.. $#{ $rows[0] }) {
    print join $sep, map {
            $rows[$_]->[$idx]
        } 0..$#rows;
    
    print "\n";
};

=head1 NAME

ff-scrape.pl - simple Firefox HTML scraping from the command line

=head1 SYNOPSIS

  ff-scrape.pl URL selector selector ...

  # Print page title
  ff-scrape.pl http://perl.org title
  # The Perl Programming Language - www.perl.org

  # Print links with titles on tab CPAN, make links absolute
  ff-scrape.pl --tab CPAN a //a/@href --uri=2
  
  # Print all links to JPG images on current page, make links absolute
  ff-scrape.pl --current //a[@href=$"jpg"]/@href

Options:
   --tab            title of tab to scrape (instead of URL)
   --current        use currently active tab (instead of URL)
   --sep            separator for the output columns, default is tab-separated
   --uri            force absolute URIs for colum number x
   --no-uri         force verbatim output for colum number x
   --mozrepl        connection string to Firefox

=head1 OPTIONS

=over 4

=item B<--tab>

Name of the tab to scrape. A substring is enough.

=item B<--sep>

Separator character to use for columns. Default is tab.

=item B<--uri> COLUMNS

Numbers of columns to convert into absolute URIs, if the
known attributes do not everything you want.

=item B<--no-uri>

Switches off the automatic translation to absolute
URIs for known attributes like C<href> and C<src>.

=item B<--mozrepl>

Connection information for the mozrepl instance to use.

=back

=head1 DESCRIPTION

This program fetches an HTML page and extracts nodes
matched by XPath or CSS selectors from it.

=head1 SEE ALSO

L<https://github.com/Corion/App-scrape> - App::scrape

A similar program without the need for Javascript.

L<Mojolicious> - also includes a CSS / Xpath scraper

=head1 REPOSITORY

The public repository of this module is
L<http://github.com/Corion/www-mechanize-firefox>.

=head1 SUPPORT

The public support forum of this program is
L<http://perlmonks.org/>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2011-2011 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
