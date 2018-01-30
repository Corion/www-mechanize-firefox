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

plan tests => 1;

my $dr = Firefox::Marionette::Driver->new(
);

$dr->connect()->get;

ok 1;

use AnyEvent::Future;

AnyEvent->condvar->recv;

done_testing;