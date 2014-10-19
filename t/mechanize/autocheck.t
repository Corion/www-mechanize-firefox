#!perl -Tw

use warnings;
use strict;
use Test::More;


BEGIN { delete @ENV{ qw( http_proxy HTTP_PROXY ) }; }
BEGIN {
    eval 'use Test::Exception';
    if( $@ ) {
        plan skip_all => 'Test::Exception required to test autodie';
        exit;
    };
}

my $NONEXISTENT = 'blahblablah.xx-nonexistent.foo';
my @results = gethostbyname( $NONEXISTENT );
if ( @results ) {
    my ($name,$aliases,$addrtype,$length,@addrs) = @results;
    my $ip = join( '.', unpack('C4',$addrs[0]) );
    plan skip_all => "Your ISP is overly helpful and returns $ip for non-existent domain $NONEXISTENT. This test cannot be run.";
}
my $bad_url = "http://$NONEXISTENT/";

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
    plan tests => 6;
};

AUTOCHECK_OFF: {
    my $mech = WWW::Mechanize::Firefox->new( autodie => 0 );
    isa_ok( $mech, 'WWW::Mechanize::Firefox' );

    $mech->get( $bad_url );
    ok( !$mech->success, qq{Didn't fetch $bad_url, but didn't die, either} );
}

AUTOCHECK_ON: {
    my $mech = WWW::Mechanize::Firefox->new( autodie => 1 );
    isa_ok( $mech, 'WWW::Mechanize::Firefox' );

    dies_ok {
        $mech->get( $bad_url );
    } qq{Couldn't fetch $bad_url, and died as a result};
}

AUTOCHECK_DEFAULT: {
    my $mech = WWW::Mechanize::Firefox->new( );
    isa_ok( $mech, 'WWW::Mechanize::Firefox' );

    dies_ok {
        $mech->get( $bad_url );
    } qq{Couldn't fetch $bad_url, and died as a result, by default};
}
