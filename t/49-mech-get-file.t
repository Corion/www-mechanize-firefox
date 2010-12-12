#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 8;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

sub load_file_ok {
    my ($htmlfile,@options) = @_;
    my $fn = File::Spec->rel2abs(
                 File::Spec->catfile(dirname($0),$htmlfile),
                 getcwd,
             );
    $mech->allow(@options);
    $fn =~ s!\\!/!g; # fakey "make file:// URL"
    diag "Loading $fn";
    $mech->get("file://$fn");
    ok $mech->success, $htmlfile;
    is $mech->title, $htmlfile, "We loaded the right file (@options)";
};

load_file_ok('49-mech-get-file.html', javascript => 0);
$mech->get('about:blank');
load_file_ok('49-mech-get-file.html', javascript => 1);
$mech->get('about:blank');

$mech->get_local('49-mech-get-file.html');
ok $mech->success, '49-mech-get-file.html';
is $mech->title, '49-mech-get-file.html', "We loaded the right file";

ok $mech->is_html, "The local file gets identified as HTML";

undef $mech;