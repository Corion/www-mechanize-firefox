use strict;
use WWW::Mechanize::FireFox;
use Time::HiRes;
use Test::More;
use File::Spec;

my $mech = eval {WWW::Mechanize::FireFox->new(
    #log => ['debug'],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 1;
};

my $target = "$0.tmp";
END {
    # give FireFox a second to download+save the file
    sleep 1; 
    unlink $target  or warn "Couldn't remove tempfile '$target': $!";
}
ok $mech->save_url('http://google.de/' => $target), 'Downloading google.de';