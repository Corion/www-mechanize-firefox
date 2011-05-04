#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

$ENV{ MOZREPL_CLASS } = 'MozRepl'; # we want the Net::Telnet-based implementation

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    bufsize => 1025, # a too small size, but still larger than the Net::Telnet default
    #log => ['debug'],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};
diag "Using ", ref $mech->repl->repl;

isa_ok $mech, 'WWW::Mechanize::Firefox';
my $response;
my $result = eval {
    $response = $mech->get_local('rt65615.html', no_cache => 1); # a large website
    $mech->content;
    1
};
ok !$result, "We died on the call";
like $@, qr/\b1025\b/, "... and we got the correct bufsize error";

# Now go in and clean up the tab the previous instance left orphaned
$mech = WWW::Mechanize::Firefox->new(
    attach => 1,
    tab => qr/^rt65615.html$/,
    autoclose => 1,
);
undef $mech;

