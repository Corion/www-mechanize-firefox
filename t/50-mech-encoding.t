#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

use t::helper;

# What instances of Firefox will we try?
my $instance_port = 4243;
my @instances = t::helper::firefox_instances(qr/5\.0/);

my @tests = (
    [ 'mixi_jp_index.html', 'EUC-JP', qr/\x{30DF}\x{30AF}\x{30B7}\x{30A3}/ ],
    [ 'sophos_co_jp_index.html', 'Shift_JIS', qr/\x{30B0}\x{30ED}\x{30FC}\x{30D0}\x{30EB}/ ],
);


if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 2*@tests*@instances;
};

sub new_mech {
    WWW::Mechanize::Firefox->new(
        autodie => 0,
        #log => [qw[debug]],
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($firefox_instance, $mech) = @_;

    for (@tests) {
        my ($file,$encoding,$content_re) = @$_;
        $mech->get_local($file);
        is $mech->content_encoding, $encoding, "$file has encoding $encoding";
        diag length $mech->content;
        like $mech->content, $content_re, "Partial expression gets found in UTF-8 content";
    };
});