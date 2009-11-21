use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'WWW::Mechanize::FireFox',
    'LICENSE'       => 'perl',
    'VERSION_FROM'  => 'lib/WWW/Mechanize/FireFox.pm', # finds $VERSION
    'PREREQ_PM'     => { 'MozRepl::RemoteObject' => 0.09,
                        'URI' => 0,
                        'HTTP::Response' => 0, # for interface compatibility with WWW::Mechanize
                        'HTML::Selector::XPath' => 0,
                        'WWW::Mechanize' => 0, # for link filtering and 1:1 API compatibility
                        'WWW::Mechanize::Link' => 0, # for API compatibility
                        'MIME::Base64' => 0,
                        'parent' => 0,
                      }, # e.g., Module::Name => 1.1
    ABSTRACT_FROM   => 'lib/WWW/Mechanize/FireFox.pm', # retrieve abstract from module
    AUTHOR          => 'Max Maischein <corion@cpan.org>',
);

1;
