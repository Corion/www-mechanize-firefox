#!perl -w

use strict;
use Test::More;

=head1 NAME

content.t

=head1 SYNOPSIS

Tests the transforming forms of $mech->content().

=cut

BEGIN { delete @ENV{ qw( http_proxy HTTP_PROXY ) }; };
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


my $html = <<'HTML';
<html>
<head>
<title>Howdy?</title>
</head>
<body>
Fine, thx!
</body>
</html>
HTML

# Well actually there is no base (and therefore it does not belong to us
# :-), so let's kludge a bit.
$mech->{base} = 'http://example.com/';
$mech->update_html($html);

=head2 $mech->content(format => "text")

=cut

SKIP: {
    #eval 'use HTML::TreeBuilder';
    #skip 'HTML::TreeBuilder not installed', 2 if $@;

    my $text = $mech->content(format => 'text');
    #diag $text;
    like( $text, qr/Fine/, 'Found Fine' );
    unlike( $text, qr/html/i, 'Could not find "html"' );
}

