#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
use Firefox::Marionette::Driver;

use Log::Log4perl ':easy';
Log::Log4perl->easy_init($TRACE);

plan tests => 3;

my $dr = Firefox::Marionette::Driver->new(
);

$dr->connect()->get;
ok 1, "We survive connecting";

$dr->transport->sleep(1)->get;

my $info = $dr->remote_info;
ok $info, "We have an answer from the remote";
is $info->{marionetteProtocol}, 3, "We have version 3 of the protocol";

done_testing;