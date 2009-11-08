#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
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
    plan tests => 2;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';
can_ok $mech, 'errors';

sub load_file_ok {
    my ($htmlfile) = @_;
    my $fn = File::Spec->rel2abs(
                 File::Spec->catfile(dirname $0,$htmlfile),
                 getcwd,
             );
    $fn =~ s!\\!/!; # fakey "make file:// URL"
    $mech->get_ok("file://$fn");
    is $mech->title, $htmlfile, "We loaded the right file";
};

load_file_ok('53-mech-capture-js-noerror.html');

is_deeply [$mech->errors], [], "No errors on page";

load_file_ok('53-mech-capture-js-error.html');
is_deeply [$mech->errors], [
    '',
], "No errors on page";
