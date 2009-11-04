#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::FireFox;
use URI::file;
use File::Basename;
use File::Spec;
use Cwd;

my $mech = eval { WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 12;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

my $dir = File::Spec->rel2abs( dirname $0, getcwd() );
my $file = File::Spec->catfile( $dir, '51-mech-sandbox.html' );
$file =~ s!\\!/!g; # fakey file:// construction
$file = "file://$file";
my $uri = URI::file->new($file);
$mech->get("$uri");
$mech->allow('javascript' => 1);

my ($get,$type) = $mech->eval_in_page('get');
ok $get, "We found 'get'";
is $type, 'function', "Result type";

my $v;
eval {
    $v = $get->();
};
is $@, "", "No error when calling get()";
is $v, 'Hello', "We got the initial value";

(my ($set),$type) = $mech->eval_in_page('set');
ok $set, "We found 'set'";

eval {
    $v = $set->('123');
};
is $@, "", "No error when calling set()";
is $v, '123', "We got the set value";

eval {
    $v = $get->();
};
is $@, "", "No error when calling get()";
is $v, '123', "We got the new value";

(my ($val),$type) = $mech->eval_in_page('hello');
is $type, 'string', "Returning a string";
is $val, 'Hello MozRepl', "Getting the right value";