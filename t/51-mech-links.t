#!perl -w
use strict;
use Test::More;
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
    plan tests => 4;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

my $content = <<HTML;
<html>
<head>
<title>Hello FireFox!</title>
</head>
<body>
<h1>Hello World!</h1>
<p>Hello <b>WWW::Mechanize::FireFox</b></p>
<h1>Links</h1>
<a href="#">#</a>
<a name="foo">#</a>
<a href="http://corion.net/">http://corion.net</a>
<a href="relative">relative</a>
<a href="/absolute">/absolute</a>
<iframe src="myframe">
</body>
</html>
HTML

$mech->update_html($content);

my @found_links = $mech->links;
is scalar @found_links, 6, 'All 6 links were found';

$content = <<HTML;
<html>
<head>
<title>Hello FireFox!</title>
<base href="http://somewhere.example/" />
</head>
<body>
<h1>Hello World!</h1>
<p>Hello <b>WWW::Mechanize::FireFox</b></p>
<h1>Links</h1>
<a href="relative">relative</a>
</body>
</html>
HTML

$mech->update_html($content);

@found_links = $mech->links;
is scalar @found_links, 1, 'The one links was found';
is $found_links[0]->url, 'http://somewhere.example/relative',
    'BASE tags get respected';