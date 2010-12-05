#!perl -w
use strict;
use Test::More;
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

$mech->get_local('51-mech-links-nobase.html');

my @found_links = $mech->links;
# There is a FRAME tag, but FRAMES are exclusive elements
# so Firefox ignores it while WWW::Mechanize picks it up
if (! is scalar @found_links, 6, 'All 6 links were found') {
    diag sprintf "%s => %s", $_->tag, $_->url
        for @found_links;
};

# If you use ->set_content, Firefox doesn't want to load (I)FRAME content
$mech->get_local('51-mech-links-base.html');

@found_links = $mech->links;
is scalar @found_links, 2, 'The two links were found'
    or diag $_->url for @found_links;
is $found_links[0]->url, 'http://somewhere.example/relative',
    'BASE tags get respected';
is $found_links[1]->url, 'http://somewhere.example/myiframe',
    'BASE tags get respected for iframes';
    
# There is a FRAME tag, but FRAMES are exclusive elements
# so Firefox ignores it while WWW::Mechanize picks it up
my @frames = $mech->selector('frame');
is @frames, 0, "FRAME tag"
    or diag $mech->content;

@frames = $mech->selector('iframe');
is @frames, 1, "IFRAME tag";