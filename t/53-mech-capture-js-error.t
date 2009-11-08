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
    plan tests => 19;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';
can_ok $mech, 'js_errors','clear_js_errors';

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

$mech->clear_js_errors;
is_deeply [$mech->js_errors], [], "No errors reported on page after clearing errors";

load_file_ok('53-mech-capture-js-noerror.html', javascript => 0);
is_deeply [$mech->js_errors], [], "No errors reported on page";

load_file_ok('53-mech-capture-js-noerror.html', javascript => 1 );
is_deeply [$mech->js_errors], [], "No errors reported on page";

load_file_ok('53-mech-capture-js-error.html', javascript => 0);
is_deeply [$mech->js_errors], [], "Errors on page";

load_file_ok('53-mech-capture-js-error.html', javascript => 1);
is scalar $mech->js_errors, 1, "One error message found";
(my $msg) = $mech->js_errors;
like $msg->{message}, qr/^\[JavaScript Error: "nonexisting_function is not defined"/, "Errors message";
like $msg->{message}, qr!\Q53-mech-capture-js-error.html\E"!, "File name";
like $msg->{message}, qr!\bline: 5\b!, "Line number";

$mech->clear_js_errors;
is_deeply [$mech->js_errors], [], "No errors reported on page after clearing errors";
