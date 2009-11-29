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
    plan tests => 2;
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
</body>
</html>
HTML

$mech->update_html($content);

my $c = $mech->content;
for ($c,$content) {
    s/\s+/ /msg; # normalize whitespace
    s/> </></g;
    s/\s*$//;
};

is $c, $content, "Setting the content works";

