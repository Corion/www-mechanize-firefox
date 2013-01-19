#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;
use Data::Dumper;

use t::helper;

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 12;
};

my $mech=
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        #log => [qw[debug]],
    );

sub save {
    my ($data,$filename) = @_;
    open my $fh, '>', $filename
        or die "Couldn't create '$filename': $!";
    binmode $fh;
    print {$fh} $data;
};

# This is a bit inefficient, but for a test I value simplicity
sub image_dimensions_are {
    if( eval { require Image::Info; 1 }) {
        my $got = Image::Info::image_info( \$_[0] );
        delete $got->{$_} for grep { $_ !~ /^(width|height)$/ } keys %$got;
        is_deeply $got, $_[1], $_[2]
            or diag Dumper $got;
    } else {
        SKIP: { skip "Image::Info not available", 1; }
    };
};

my $i = 1;

    isa_ok $mech, 'WWW::Mechanize::Firefox';

    $mech->update_html(<<'HTML');
    <html>
    <head><title>Hello PNG!</title></head>
    <body>
    Hello <b id="my_name">PNG</b>!
    </body>
    </html>
HTML
    ok $mech->success, 'We got the page';

    my $pngData = $mech->content_as_png();

    like $pngData, '/^.PNG/', "The result looks like a PNG format file";
    #save($pngData,"Page-".$i++.".png");

    my $pngName = $mech->selector("#my_name", single => 1);
    $pngData = $mech->element_as_png($pngName);
    like $pngData, '/^.PNG/', "The result looks like a PNG format file";

    my $rect = { left  =>    0,
        top   =>    0,
        width  => 200,
        height => 200,
    };
    my $topleft = $mech->content_as_png(undef, $rect);
    like $topleft, '/^.PNG/', "The result looks like a PNG format file";
    image_dimensions_are( $topleft, { width => 200, height => 200 }, "Partial image" );

    $rect = { left  =>    0,
        top   =>    0,
        width  => 200,
        height => 200,
    };
    my $target = {
        scalex => 2,
    };
    $topleft = $mech->content_as_png(undef, $rect, $target);
    like $topleft, '/^.PNG/', "The result looks like a PNG format file";
    image_dimensions_are( $topleft, { width => 400, height => 400 }, "Blown up (scalex)" );

    $rect = { left  =>    0,
        top   =>    0,
        width  => 200,
        height => 300,
    };
    $target = {
        width => 150,
    };
    $topleft = $mech->content_as_png(undef, $rect, $target);
    like $topleft, '/^.PNG/', "The result looks like a PNG format file";
    image_dimensions_are( $topleft, { width => 150, height => 225 }, "Scaled down via fixed with" );

    $rect = { left  =>    0,
        top   =>    0,
        width  => 300,
        height => 200,
    };
    $target = {
        height => 150,
    };
    $topleft = $mech->content_as_png(undef, $rect, $target);
    like $topleft, '/^.PNG/', "The result looks like a PNG format file";
    image_dimensions_are( $topleft, { width => 225, height => 150 }, "Scaled down via fixed height" );
    #save($pngData,"Topleft-".$i++.".png");
