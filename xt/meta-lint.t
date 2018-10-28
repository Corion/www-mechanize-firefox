#!perl -w

# Stolen from ChrisDolan on use.perl.org
# http://use.perl.org/comments.pl?sid=29264&cid=44309

use warnings;
use strict;
use File::Find;
use Test::More tests => 4;
use Parse::CPAN::Meta;
use CPAN::Meta::Validator;

use lib '.';
use vars '%module';
require 'Makefile.PL';
# Loaded from Makefile.PL
%module = get_module_info();
my $module = $module{NAME};

(my $file = $module) =~ s!::!/!g;
require "$file.pm";

my $version = sprintf '%0.2f', $module->VERSION;

for my $meta_file ('META.yml', 'META.json') {
    my $meta = Parse::CPAN::Meta->load_file($meta_file);

    my $cmv = CPAN::Meta::Validator->new( $meta );
    
    if(! ok $cmv->is_valid, "$meta_file is valid" ) {
        diag $_ for $cmv->errors;
    };
    
    # Also check that the declared version matches the version in META.*
    is $meta->{version}, $version, "$meta_file version matches module version ($version)";
};
