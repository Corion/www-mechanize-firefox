#!perl -w

use warnings;
use strict;
use File::Find;
use Test::More;
BEGIN {
    eval { require Capture::Tiny; Capture::Tiny->import(":all"); };
    if ($@) {
        plan skip_all => "Capture::Tiny needed for testing";
        exit 0;
    };
};

plan 'no_plan';

my $last_version = undef;

sub check {
    return if (! m{(\.pm|\.pl) \z}xmsi);

    my ($stdout, $stderr, $exit) = capture(sub {
        system( $^X, '-Mblib', '-wc', $_ );
    });

    s!\s*\z!!
        for ($stdout, $stderr);

    if( $exit ) {
        diag $exit;
        diag $stdout;
        diag $stderr;
        fail($_);
    } elsif( $stderr !~ qr/^\Q$_\E syntax OK$/m) {
        diag $stderr;
        fail($_);
    } else {
        pass($_);
    };
}

find({wanted => \&check, no_chdir => 1},
     grep { -d $_ }
         'blib', 'scripts', 'examples', 'bin', 'lib'
     );
