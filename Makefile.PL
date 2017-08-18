# -*- mode: perl; c-basic-offset: 4; indent-tabs-mode: nil; -*-

use strict;
use ExtUtils::MakeMaker qw(WriteMakefile);
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# I should maybe use something like Shipwright...
regen_README('lib/WWW/Mechanize/Firefox.pm');
regen_EXAMPLES();

my @tests = map { glob $_ } 't/*.t', 't/*/*.t';

WriteMakefile1(
    MIN_PERL_VERSION => '5.006',
    META_MERGE => {
        resources => {
            repository => 'http://github.com/Corion/www-mechanize-firefox',
        },
    },
    BUILD_REQUIRES => {
                        'Task::Weaken' => 0, #to be sure that weaken is present
    },
    TEST_REQUIRES => {
                        'Test::HTTP::LocalServer' => 0,
    },
    'NAME'          => 'WWW::Mechanize::Firefox',
    'LICENSE'       => 'perl',
    'VERSION_FROM'  => 'lib/WWW/Mechanize/Firefox.pm', # finds $VERSION
    'PREREQ_PM'     => { 'MozRepl::RemoteObject' => 0.39, # fixed ->click($node, $x,$y)
                        'URI' => 0,
                        'URI::data' => 0,
                        'Cwd' => 0, # only needed in ->get_local, mostly exercised by the tests
                        'File::Basename' => 0,
                        'HTTP::Response' => 0, # for interface compatibility with WWW::Mechanize
                        'HTTP::Cookies' => 0, # for HTTP::Cookies::MozRepl
                        'HTTP::Date' => 0, # get a date online?!
                        'HTML::Selector::XPath' => 0,
                        'WWW::Mechanize' => 0, # for link filtering and 1:1 API compatibility
                        'HTTP::Request::Common' => 0, # for convenient request manufacturing
                        'WWW::Mechanize::Link' => 0, # for API compatibility
                        'MIME::Base64' => 0,
                        'Shell::Command' => 0, # just for cleanup of a test
                        'parent' => 0,
                        'Scalar::Util' => 1.14,
                        'Object::Import'  => 0,
                      }, # e.g., Module::Name => 1.1

    ABSTRACT_FROM   => 'lib/WWW/Mechanize/Firefox.pm', # retrieve abstract from module
    AUTHOR          => 'Max Maischein <corion@cpan.org>',
    test            => { TESTS => join( ' ', @tests ) },
);

1;

sub WriteMakefile1 {  #Written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params=@_;
    my $eumm_version=$ExtUtils::MakeMaker::VERSION;
    $eumm_version=eval $eumm_version;
    die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
    die "License not specified" if not exists $params{LICENSE};
    if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
        #EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
        delete $params{BUILD_REQUIRES};
    }
    if ($params{TEST_REQUIRES} and $eumm_version < 6.64) {
        $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{TEST_REQUIRES}} };
        delete $params{TEST_REQUIRES};
    }
    delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
    delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
    delete $params{META_MERGE} if $eumm_version < 6.46;
    delete $params{META_ADD} if $eumm_version < 6.46;
    delete $params{LICENSE} if $eumm_version < 6.31;
    delete $params{AUTHOR} if $] < 5.005;
    delete $params{ABSTRACT_FROM} if $] < 5.005;
    delete $params{BINARY_LOCATION} if $] < 5.005;
    
    WriteMakefile(%params);
}

sub regen_README {
    # README is the short version that just tells people what this is
    # and how to install it
    eval {
        # Get description
        my $readme = join "\n",
            pod_section($_[0], 'NAME', 'no heading' ),
            pod_section($_[0], 'DESCRIPTION' ),
            <<INSTALL,

INSTALLATION

This is a Perl module distribution. It should be installed with whichever
tool you use to manage your installation of Perl, e.g. any of

  cpanm .
  cpan  .
  cpanp -i .

Consult http://www.cpan.org/modules/INSTALL.html for further instruction.
Should you wish to install this module manually, the procedure is

  perl Makefile.PL
  make
  make test
  make install

See lib/WWW/Mechanize/Firefox/Installation.pod for further hints on
the Firefox Add-on that needs to be installed.
  
INSTALL
            pod_section($_[0], 'REPOSITORY'),
            pod_section($_[0], 'SUPPORT'),
            pod_section($_[0], 'BUG TRACKER'),
            pod_section($_[0], 'AUTHOR'),
            pod_section($_[0], 'LICENSE' ),
            pod_section($_[0], 'COPYRIGHT' ),
    ;
        update_file( 'README', $readme );
    };
    # README.mkdn is the documentation that will be shown as the main
    # page of the repository on Github. Hence we recreate the POD here
    # as Markdown
    eval {
        require Pod::Markdown;

        my $parser = Pod::Markdown->new();

        # Read POD from Module.pm and write to README
        $parser->parse_from_file($_[0]);
        my $readme_mkdn = <<STATUS . $parser->as_markdown;

[![Build Status](https://travis-ci.org/Corion/www-mechanize-firefox.svg?branch=master)](https://github.com/Corion/www-mechanize-firefox)

STATUS
        update_file( 'README.mkdn', $readme_mkdn );
    };
}

sub pod_section {
    my( $filename, $section, $remove_heading ) = @_;
    open my $fh, '<', $filename
        or die "Couldn't read '$filename': $!";

    my @section =
        grep { /^=head1\s+$section/.../^=/ } <$fh>;
    pop @section if $section[-1] =~ /^=/;
    unshift @section if $remove_heading;

    # Trim the section
    if( @section ) {
        pop @section
            while $section[-1] =~ /^\s*$/;
        shift @section
            while $section[0] =~ /^\s*$/;
    };

    @section = map { $_ =~ s!^=\w+\s+!!; $_ } @section;
    return join "", @section;
}

sub update_file {
    my( $filename, $new_content ) = @_;
    my $content;
    if( -f $filename ) {
        open my $fh, '<', $filename
            or die "Couldn't read '$filename': $!";
        binmode $fh;
        local $/;
        $content = <$fh>;
    };

    if( $content ne $new_content ) {
        if( open my $fh, '>', $filename ) {
            binmode $fh;
            print $fh $new_content;
        } else {
            warn "Couldn't (re)write '$filename': $!";
        };
    };
}

sub regen_EXAMPLES {
    my $perl = $^X;
    warn "(Re)Creating lib/WWW/Mechanize/Firefox/Examples.pm\n";
    if ($perl =~/\s/) {
        $perl = qq{"$perl"};
    };
    my $examples = `$perl -w examples/gen_examples_pod.pl`;
    if ($examples) {
        $examples =~ s/\r\n/\n/g;
        if (open my $out, '>', 'lib/WWW/Mechanize/Firefox/Examples.pm') {
            binmode $out;
            print $out $examples;
        };
    };
};