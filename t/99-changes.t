#!perl -w
use warnings;
use strict;
use File::Find;
use Test::More tests => 2;

=head1 PURPOSE

This test ensures that the Changes file
mentions the current version and that a
release date is mentioned as well

=cut

my $module = 'WWW::Mechanize::Firefox';

(my $file = $module) =~ s!::!/!g;
require "$file.pm";

my $version = sprintf '%0.2f', $module->VERSION;
diag "Checking for version " . $version;

my $changes = do { local $/; open my $fh, 'Changes' or die $!; <$fh> };

ok $changes =~ /^(.*$version.*)$/m, "We find version $version";
my $changes_line = $1;
ok $changes_line =~ /$version\s+20\d{6}/, "We find a release date on the same line"
    or diag $changes_line;
