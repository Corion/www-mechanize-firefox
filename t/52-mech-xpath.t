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
    plan tests => 11;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

my $content = <<HTML;
<html>
<head>
<title>Hello Firefox!</title>
</head>
<body>
<h1>Hello <b>World</b>!</h1>
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

my @n = $mech->document->__xpath('//b');
is scalar @n, 2, 'Querying stuff via XPath works';

@n = $mech->xpath('//b');
is scalar @n, 2, 'Querying stuff via XPath works via the immediate interface';

# Test that we can query for things other than nodes:
my @res= $mech->xpath('//p');
is 0+@res, 1, "We find one //p result";
isa_ok $res[0], 'MozRepl::RemoteObject::Instance', "... and it is a node";

   @res= $mech->xpath('//p/text()', type => $mech->xpathResult('STRING_TYPE'));
is 0+@res, 1, "We find one //p/text() result";
is $res[0], "Hello ", "... and it is text";

   @res= $mech->xpath('substring(//p,1,4)');
is 0+@res, 1, "We find one substring(//p,1,4) result";
is $res[0], "Hell", "... and it is text";

   @res= $mech->xpath('string-length(//p)');
is 0+@res, 1, "We find one string-length(//p) result";
is $res[0], 29, "... and it is a number";

