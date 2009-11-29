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

my $content = <<HTML;
<html>
<head>
<title>Hello Firefox!</title>
</head>
<body>
<h1>Hello World!</h1>
<p>Hello <b>WWW::Mechanize::Firefox</b></p>
<h1>Links</h1>
<a href="#">#</a>
<a name="foo">#</a>
<a href="http://corion.net/">http://corion.net</a>
<a href="relative">relative</a>
<a href="/absolute">/absolute</a>
<iframe src="myframe"></iframe>
<frame src="myframe"></frame>
</body>
</html>
HTML

$mech->update_html($content);

{ local $TODO = "data: URLs don't play well with FRAMEs";
    my @found_links = $mech->links;
    is scalar @found_links, 7, 'All 7 links were found';
};

$content = <<HTML;
<html>
<head>
<title>Hello Firefox!</title>
<base href="http://somewhere.example/" />
</head>
<body>
<h1>Hello World!</h1>
<p>Hello <b>WWW::Mechanize::Firefox</b></p>
<h1>Links</h1>
<a href="relative">relative</a>
<iframe src="myiframe" />
<frameset>
<frame src="http://google.de/" /><!-- my frame -->
</frameset>
</body>
</html>
HTML

$mech->update_html($content);

my @found_links = $mech->links;
is scalar @found_links, 2, 'The two links were found'
    or diag $_->url for @found_links;
is $found_links[0]->url, 'http://somewhere.example/relative',
    'BASE tags get respected';
is $found_links[1]->url, 'http://somewhere.example/myiframe',
    'BASE tags get respected for iframes';
    
{
    local $TODO = "FRAME tags don't play well with data: URLs";
    my @frames = $mech->selector('frame');
    is @frames, 1, "FRAME tag"
        or diag $mech->content;
}

my @frames = $mech->selector('iframe');
is @frames, 1, "IFRAME tag";