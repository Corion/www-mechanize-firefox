#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

use t::helper;

# What instances of Firefox will we try?
my $instance_port = 4243;
my @instances = t::helper::firefox_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 5*@instances;
};

sub new_mech {
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        log => [qw[debug]],
        @_,
    );
};

sub save {
    my ($data,$filename) = @_;
    open my $fh, '>', $filename
        or die "Couldn't create '$filename': $!";
    binmode $fh;
    print {$fh} $data;
};

my $i = 1;
t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($firefox_instance, $mech) = @_;

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
    #save($pngData,"Topleft-".$i++.".png");
});